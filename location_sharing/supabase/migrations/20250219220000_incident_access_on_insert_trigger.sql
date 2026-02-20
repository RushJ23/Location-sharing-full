-- Ensure every new incident gets Layer 1 contacts in incident_access automatically.
-- Works for both: (1) app "I need help" insert, (2) expire-pending-safety-checks curfew insert.
-- SECURITY DEFINER so the trigger can insert into incident_access regardless of RLS.

CREATE OR REPLACE FUNCTION public.add_layer1_to_incident_access()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.incident_access (incident_id, contact_user_id, layer, notified_at)
  SELECT NEW.id, c.contact_user_id, 1, now()
  FROM public.contacts c
  WHERE c.user_id = NEW.user_id AND c.layer = 1
  ON CONFLICT (incident_id, contact_user_id) DO UPDATE SET
    layer = EXCLUDED.layer,
    notified_at = EXCLUDED.notified_at;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_add_layer1_incident_access ON public.incidents;
CREATE TRIGGER trigger_add_layer1_incident_access
  AFTER INSERT ON public.incidents
  FOR EACH ROW
  EXECUTE PROCEDURE public.add_layer1_to_incident_access();
