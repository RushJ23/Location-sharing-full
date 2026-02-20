-- Backfill incident_location_history so each active incident has ~12 points (one per hour) for the map.
-- Uses last_known_lat/lng and created_at; inserts only when the incident has fewer than 12 rows.

INSERT INTO public.incident_location_history (incident_id, lat, lng, timestamp)
SELECT i.id, lat_lng.lat, lat_lng.lng, lat_lng.ts
FROM public.incidents i
CROSS JOIN LATERAL (
  SELECT
    COALESCE(i.last_known_lat, 40.44) AS lat,
    COALESCE(i.last_known_lng, -79.94) AS lng,
    (i.created_at - (n || ' hours')::interval) AS ts
  FROM generate_series(1, 12) AS n
) lat_lng
WHERE i.status = 'active'
  AND (SELECT count(*) FROM public.incident_location_history h WHERE h.incident_id = i.id) < 12;
