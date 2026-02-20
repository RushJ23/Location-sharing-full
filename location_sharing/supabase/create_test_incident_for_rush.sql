-- Create an incident where Alex is the subject, so Rush (Layer 1) can see it.
-- Run in Supabase SQL Editor. Requires dummy data seeded (Alex exists, Rush is Alex's Layer 1 contact).
-- Rush = f56633bb-64ff-4ea3-95f3-00a128e25599; Alex = a0000001
-- Trigger adds Rush to incident_access automatically.

WITH new_incident AS (
  INSERT INTO public.incidents (user_id, status, trigger, last_known_lat, last_known_lng)
  VALUES (
    'a0000001-0000-4000-8000-000000000001'::uuid,
    'active',
    'manual',
    40.443,
    -79.942
  )
  RETURNING id
)
INSERT INTO public.incident_location_history (incident_id, lat, lng, timestamp)
SELECT ni.id, s.lat, s.lng, s.timestamp
FROM new_incident ni
CROSS JOIN public.user_location_samples s
WHERE s.user_id = 'a0000001-0000-4000-8000-000000000001'::uuid;
