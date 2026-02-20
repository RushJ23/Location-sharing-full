-- Emergency override: allow reading subject's always_share_locations for an incident
-- when the viewer has access to the incident (subject or contact). Used only when
-- incident.subject_current_lat/lng are null so contacts can see latest location.

CREATE OR REPLACE FUNCTION public.get_subject_location_for_incident(p_incident_id uuid)
RETURNS TABLE(lat double precision, lng double precision, updated_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT a.lat, a.lng, a.updated_at
  FROM public.incidents i
  JOIN public.always_share_locations a ON a.user_id = i.user_id
  WHERE i.id = p_incident_id
    AND i.status = 'active'
    AND (
      i.user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.incident_access ia
        WHERE ia.incident_id = i.id AND ia.contact_user_id = auth.uid()
      )
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_subject_location_for_incident(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_subject_location_for_incident(uuid) TO service_role;
