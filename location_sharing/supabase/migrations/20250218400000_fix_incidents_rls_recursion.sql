-- Fix infinite recursion between incidents and incident_access RLS policies.
-- incidents policy 2 reads incident_access; incident_access policy reads incidents -> cycle.
-- Use SECURITY DEFINER functions so neither policy triggers the other's RLS.

-- Function for incidents policy: "is current user a contact for this incident?"
-- Reads incident_access with definer privileges, no RLS recursion.
CREATE OR REPLACE FUNCTION public.is_user_contact_for_incident(p_incident_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.incident_access
    WHERE incident_id = p_incident_id AND contact_user_id = auth.uid()
  );
$$;

-- Function for incident_access policy: "is current user the incident subject?"
CREATE OR REPLACE FUNCTION public.is_incident_subject(p_incident_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.incidents
    WHERE id = p_incident_id AND user_id = auth.uid()
  );
$$;

-- Fix incidents: replace direct incident_access subquery with function call
DROP POLICY IF EXISTS "Users can read incidents where they are contact" ON public.incidents;

CREATE POLICY "Users can read incidents where they are contact" ON public.incidents
  FOR SELECT USING (public.is_user_contact_for_incident(id));

-- Fix incident_access: replace direct incidents subquery with function call
DROP POLICY IF EXISTS "Subject or contact can read incident_access" ON public.incident_access;

CREATE POLICY "Subject or contact can read incident_access" ON public.incident_access
  FOR SELECT USING (
    contact_user_id = auth.uid()
    OR public.is_incident_subject(incident_id)
  );
