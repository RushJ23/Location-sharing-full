-- Fix always-share direction: I can see B's location only when B has me as always-share contact (B shares with me).
-- Previously inverted: I could see B when I had B as always-share contact (wrong).

-- 1) RLS policy: allow reading when the sharer (location owner) has the viewer as always-share contact
DROP POLICY IF EXISTS "Users can read always_share for their always-share contacts" ON public.always_share_locations;
CREATE POLICY "Users can read always_share when sharer has them as contact" ON public.always_share_locations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.user_id = always_share_locations.user_id
        AND c.contact_user_id = auth.uid()
        AND c.is_always_share = true
    )
  );

-- 2) get_my_always_share_locations: return locations of users who share with the current user
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
    WHERE c.user_id = a.user_id
      AND c.contact_user_id = auth.uid()
      AND c.is_always_share = true
  );
$$;

-- 3) get_always_share_locations_for_users: filter to only return locations of users who share with the caller
CREATE OR REPLACE FUNCTION public.get_always_share_locations_for_users(p_user_ids uuid[])
RETURNS SETOF public.always_share_locations
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT a.* FROM public.always_share_locations a
  WHERE a.user_id = ANY(p_user_ids)
    AND EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.user_id = a.user_id
        AND c.contact_user_id = auth.uid()
        AND c.is_always_share = true
    );
$$;

-- 4) ensure_always_share_location trigger: insert row for sharer (user_id), not recipient (contact_user_id)
CREATE OR REPLACE FUNCTION public.ensure_always_share_location()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_always_share = true THEN
    INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
    VALUES (NEW.user_id, 40.44, -79.94, now())
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- 5) Backfill: ensure rows exist for all sharers (users who have is_always_share = true on any contact)
INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
SELECT DISTINCT c.user_id, 40.44, -79.94, now()
FROM public.contacts c
WHERE c.is_always_share = true
ON CONFLICT (user_id) DO NOTHING;
