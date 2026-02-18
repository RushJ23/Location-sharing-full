-- Fix infinite recursion between incidents and incident_access RLS policies.
-- Use SECURITY DEFINER functions so the subject check doesn't trigger RLS on incidents.

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

-- Drop old policies and recreate incident_access SELECT to use the function
DROP POLICY IF EXISTS "Subject or contact can read incident_access" ON public.incident_access;

CREATE POLICY "Subject or contact can read incident_access" ON public.incident_access
  FOR SELECT USING (
    contact_user_id = auth.uid()
    OR public.is_incident_subject(incident_id)
  );
