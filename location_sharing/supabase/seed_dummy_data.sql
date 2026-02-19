-- Dummy data seed for Location Sharing app
-- Run in Supabase SQL Editor (as project owner). Uses your existing account as "me".
-- Dummy accounts password: dummy123 (for testing only)

-- 1. Get your user id (replace with actual if running manually)
-- SELECT id FROM auth.users WHERE email = 'rushabhj23@gmail.com';
-- Here we use the known id for the seed.

-- 2. Dummy users (trigger creates profiles with display_name from raw_user_meta_data)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, is_sso_user, is_anonymous, raw_user_meta_data)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'dummy.alex@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), false, false, '{"display_name": "Alex"}'::jsonb),
  ('a0000002-0000-4000-8000-000000000002'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'dummy.sam@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), false, false, '{"display_name": "Sam"}'::jsonb),
  ('a0000003-0000-4000-8000-000000000003'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'dummy.jordan@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), false, false, '{"display_name": "Jordan"}'::jsonb),
  ('a0000004-0000-4000-8000-000000000004'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'dummy.casey@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), false, false, '{"display_name": "Casey"}'::jsonb),
  ('a0000005-0000-4000-8000-000000000005'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'dummy.morgan@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), false, false, '{"display_name": "Morgan"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- 3. Contacts: your account (Rush) has each dummy at different levels; reverse rows for mutual relationship
-- Alex: always share + layer 1; Sam: layer 1 only; Jordan: layer 2; Casey: layer 3; Morgan: always share + layer 2
INSERT INTO public.contacts (user_id, contact_user_id, layer, is_always_share)
VALUES
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 'a0000001-0000-4000-8000-000000000001'::uuid, 1, true),
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 'a0000002-0000-4000-8000-000000000002'::uuid, 1, false),
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 'a0000003-0000-4000-8000-000000000003'::uuid, 2, false),
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 'a0000004-0000-4000-8000-000000000004'::uuid, 3, false),
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 'a0000005-0000-4000-8000-000000000005'::uuid, 2, true)
ON CONFLICT (user_id, contact_user_id) DO NOTHING;

INSERT INTO public.contacts (user_id, contact_user_id, layer, is_always_share)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 'f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 1, true),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 'f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 1, false),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 'f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 2, false),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 'f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 3, false),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 'f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 2, true)
ON CONFLICT (user_id, contact_user_id) DO NOTHING;

-- 4. Safe zones for each dummy (Pittsburgh-area coordinates)
INSERT INTO public.safe_zones (user_id, name, center_lat, center_lng, radius_meters)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 'Home', 40.4432, -79.9428, 200),
  ('a0000001-0000-4000-8000-000000000001'::uuid, 'Campus', 40.4440, -79.9450, 500),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 'Apartment', 40.4410, -79.9480, 150),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 'Dorm', 40.4450, -79.9400, 300),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 'Library', 40.4425, -79.9435, 100),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 'House', 40.4460, -79.9380, 250),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 'Studio', 40.4400, -79.9500, 200),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 'Gym', 40.4470, -79.9350, 150);

-- 5. Curfew schedules: one per dummy, 22:00–06:00, all their safe zones
INSERT INTO public.curfew_schedules (user_id, safe_zone_ids, start_time, end_time, timezone, enabled, response_timeout_minutes)
SELECT user_id, ARRAY_AGG(id), '22:00'::time, '06:00'::time, 'America/New_York', true, 10
FROM public.safe_zones
WHERE user_id IN (
  'a0000001-0000-4000-8000-000000000001'::uuid,
  'a0000002-0000-4000-8000-000000000002'::uuid,
  'a0000003-0000-4000-8000-000000000003'::uuid,
  'a0000004-0000-4000-8000-000000000004'::uuid,
  'a0000005-0000-4000-8000-000000000005'::uuid
)
GROUP BY user_id;

-- 6. Current locations for always-share contacts (Alex, Morgan) and your account
INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 40.4435, -79.9430, now()),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 40.4415, -79.9490, now()),
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 40.4442, -79.9415, now())
ON CONFLICT (user_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = EXCLUDED.updated_at;

-- 7. User location samples (past 12 hours) for dummy accounts and your account
-- Used when creating incidents: last 12h path and current location.
-- Run as project owner (postgres) to bypass RLS. Pittsburgh-area coordinates.
-- Points every 10 minutes for last 12 hours. Per-user offsets: Alex 40.443,-79.942;
-- Sam 40.441,-79.945; Jordan 40.445,-79.940; Casey 40.446,-79.938; Morgan 40.440,-79.950.
INSERT INTO public.user_location_samples (user_id, lat, lng, timestamp)
SELECT u, lat, lng, ts
FROM (VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 40.443, -79.942),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 40.441, -79.945),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 40.445, -79.940),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 40.446, -79.938),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 40.440, -79.950),
  ('f56633bb-64ff-4ea3-95f3-00a128e25599'::uuid, 40.444, -79.941)
) AS users(u, lat, lng)
CROSS JOIN generate_series(
  now() - interval '12 hours',
  now(),
  interval '10 minutes'
) AS ts
ON CONFLICT (user_id, timestamp) DO NOTHING;
