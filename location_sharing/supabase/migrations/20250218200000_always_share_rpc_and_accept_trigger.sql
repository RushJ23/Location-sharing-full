-- 1) RPC to fetch always-share locations for the current user (bypasses RLS so read always works).
-- Returns rows from always_share_locations for users who are in my contacts with is_always_share = true.
CREATE OR REPLACE FUNCTION public.get_my_always_share_locations()
RETURNS SETOF public.always_share_locations
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT a.*
  FROM public.always_share_locations a
  WHERE EXISTS (
    SELECT 1 FROM public.contacts c
    WHERE c.user_id = auth.uid()
      AND c.contact_user_id = a.user_id
      AND c.is_always_share = true
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_my_always_share_locations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_always_share_locations() TO service_role;

-- 2) Trigger to insert BOTH contact rows when a request is accepted (runs as definer so RLS allows both inserts).
-- This fixes the issue where the sender did not see the acceptor in their contacts.
CREATE OR REPLACE FUNCTION public.insert_contacts_on_accept()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
    INSERT INTO public.contacts (user_id, contact_user_id, layer)
    VALUES
      (NEW.to_user_id, NEW.from_user_id, 1),
      (NEW.from_user_id, NEW.to_user_id, 1)
    ON CONFLICT (user_id, contact_user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_contact_request_accepted ON public.contact_requests;
CREATE TRIGGER on_contact_request_accepted
  AFTER UPDATE OF status ON public.contact_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.insert_contacts_on_accept();

-- 3) Ensure always_share_locations has a row when someone is added as always-share contact
-- (so they show on the map until their app updates the location).
CREATE OR REPLACE FUNCTION public.ensure_always_share_location()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_always_share = true THEN
    INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
    VALUES (NEW.contact_user_id, 40.44, -79.94, now())
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_contact_always_share ON public.contacts;
CREATE TRIGGER on_contact_always_share
  AFTER INSERT OR UPDATE OF is_always_share ON public.contacts
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_always_share_location();

-- 4) Backfill: ensure every contact with is_always_share has a row so they show on the map
INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
SELECT c.contact_user_id, 40.44, -79.94, now()
FROM public.contacts c
WHERE c.is_always_share = true
ON CONFLICT (user_id) DO NOTHING;
