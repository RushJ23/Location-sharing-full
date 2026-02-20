-- Clean all data for accounts other than Rush (rushabhj23@gmail.com), then seed dummy data.
-- Run in Supabase SQL Editor as project owner. Requires pgcrypto (Supabase has it).
-- Dummy accounts password: dummy123

-- ========== PART 1: CLEAN (keep only Rush) ==========
DO $$
DECLARE
  rush_id uuid;
BEGIN
  SELECT id INTO rush_id FROM auth.users WHERE email = 'rushabhj23@gmail.com' LIMIT 1;
  IF rush_id IS NULL THEN
    RAISE EXCEPTION 'Rush account (rushabhj23@gmail.com) not found in auth.users. Create or sign in first.';
  END IF;

  -- Incident-related (order matters for FKs)
  DELETE FROM public.incident_location_history
  WHERE incident_id IN (SELECT id FROM public.incidents WHERE user_id != rush_id);
  DELETE FROM public.incident_access
  WHERE incident_id IN (SELECT id FROM public.incidents WHERE user_id != rush_id);
  DELETE FROM public.incidents WHERE user_id != rush_id;

  -- Other user data
  DELETE FROM public.pending_safety_checks WHERE user_id != rush_id;
  DELETE FROM public.user_location_samples WHERE user_id != rush_id;
  DELETE FROM public.contact_requests WHERE from_user_id != rush_id OR to_user_id != rush_id;
  DELETE FROM public.contacts WHERE user_id != rush_id;
  DELETE FROM public.curfew_schedules WHERE user_id != rush_id;
  DELETE FROM public.safe_zones WHERE user_id != rush_id;
  DELETE FROM public.always_share_locations WHERE user_id != rush_id;
  DELETE FROM public.layer_policies WHERE user_id != rush_id;
  DELETE FROM public.profiles WHERE id != rush_id;

  -- Remove other users from auth (identities first, then users)
  DELETE FROM auth.identities WHERE user_id != rush_id;
  DELETE FROM auth.users WHERE id != rush_id;

  RAISE NOTICE 'Cleaned all data except Rush (id: %)', rush_id;
END $$;

-- ========== PART 2: SEED DUMMY USERS (auth.users + auth.identities + profiles) ==========
-- Ensure pgcrypto is available for crypt()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Dummy user UUIDs (fixed so we can reference in contacts, safe_zones, etc.)
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'dummy.alex@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Alex"}'::jsonb),
  ('a0000002-0000-4000-8000-000000000002'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'dummy.sam@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Sam"}'::jsonb),
  ('a0000003-0000-4000-8000-000000000003'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'dummy.jordan@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Jordan"}'::jsonb),
  ('a0000004-0000-4000-8000-000000000004'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'dummy.casey@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Casey"}'::jsonb),
  ('a0000005-0000-4000-8000-000000000005'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'dummy.morgan@example.com', crypt('dummy123', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Morgan"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- auth.identities so they can sign in (email provider; provider_id = user id for email)
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
SELECT gen_random_uuid(), id, jsonb_build_object('sub', id::text, 'email', email), 'email', id::text, now(), now()
FROM auth.users
WHERE email IN ('dummy.alex@example.com','dummy.sam@example.com','dummy.jordan@example.com','dummy.casey@example.com','dummy.morgan@example.com')
ON CONFLICT (provider, provider_id) DO NOTHING;

-- Profiles (trigger may have created with display_name from raw_user_meta_data; upsert to be safe)
INSERT INTO public.profiles (id, display_name, created_at, updated_at)
SELECT id, COALESCE(raw_user_meta_data->>'display_name', split_part(email, '@', 1)), now(), now()
FROM auth.users
WHERE email IN ('dummy.alex@example.com','dummy.sam@example.com','dummy.jordan@example.com','dummy.casey@example.com','dummy.morgan@example.com')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, updated_at = EXCLUDED.updated_at;

-- ========== PART 3: RUSH'S CONTACTS (Rush has each dummy at different layers; some always-share) ==========
-- Rush = rushabhj23@gmail.com. Alex: L1 + always share; Sam: L1; Jordan: L2; Casey: L3; Morgan: L2 + always share
INSERT INTO public.contacts (user_id, contact_user_id, layer, is_always_share)
SELECT (SELECT id FROM auth.users WHERE email = 'rushabhj23@gmail.com' LIMIT 1), l.uid, l.layer, l.is_always_share
FROM (VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 1, true),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 1, false),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 2, false),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 3, false),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 2, true)
) AS l(uid, layer, is_always_share)
ON CONFLICT (user_id, contact_user_id) DO UPDATE SET layer = EXCLUDED.layer, is_always_share = EXCLUDED.is_always_share;

-- Reverse: each dummy has Rush as contact (same layer / always_share as Rush sees them)
INSERT INTO public.contacts (user_id, contact_user_id, layer, is_always_share)
SELECT l.uid, (SELECT id FROM auth.users WHERE email = 'rushabhj23@gmail.com' LIMIT 1), l.layer, l.is_always_share
FROM (VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 1, true),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 1, false),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 2, false),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 3, false),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 2, true)
) AS l(uid, layer, is_always_share)
ON CONFLICT (user_id, contact_user_id) DO UPDATE SET layer = EXCLUDED.layer, is_always_share = EXCLUDED.is_always_share;

-- ========== PART 4: SAFE ZONES (for dummy accounts, Pittsburgh-area) ==========
INSERT INTO public.safe_zones (user_id, name, center_lat, center_lng, radius_meters)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 'Home', 40.4432, -79.9428, 200),
  ('a0000001-0000-4000-8000-000000000001'::uuid, 'Campus', 40.4440, -79.9450, 500),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 'Apartment', 40.4410, -79.9480, 150),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 'Dorm', 40.4450, -79.9400, 300),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 'Library', 40.4425, -79.9435, 100),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 'House', 40.4460, -79.9380, 250),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 'Studio', 40.4400, -79.9500, 200),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 'Gym', 40.4470, -79.9350, 150)
ON CONFLICT DO NOTHING;

-- ========== PART 5: CURFEW SCHEDULES (one per dummy, 22:00–06:00, all their safe zones) ==========
INSERT INTO public.curfew_schedules (user_id, safe_zone_ids, start_time, end_time, timezone, enabled, response_timeout_minutes)
SELECT sz.user_id, ARRAY_AGG(sz.id), '22:00'::time, '06:00'::time, 'America/New_York', true, 10
FROM public.safe_zones sz
WHERE sz.user_id IN (
  'a0000001-0000-4000-8000-000000000001'::uuid,
  'a0000002-0000-4000-8000-000000000002'::uuid,
  'a0000003-0000-4000-8000-000000000003'::uuid,
  'a0000004-0000-4000-8000-000000000004'::uuid,
  'a0000005-0000-4000-8000-000000000005'::uuid
)
GROUP BY sz.user_id
ON CONFLICT DO NOTHING;

-- ========== PART 6: CURRENT LOCATIONS (always_share_locations for dummies + Rush) ==========
INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
VALUES
  ('a0000001-0000-4000-8000-000000000001'::uuid, 40.4435, -79.9430, now()),
  ('a0000002-0000-4000-8000-000000000002'::uuid, 40.4412, -79.9455, now()),
  ('a0000003-0000-4000-8000-000000000003'::uuid, 40.4452, -79.9405, now()),
  ('a0000004-0000-4000-8000-000000000004'::uuid, 40.4462, -79.9385, now()),
  ('a0000005-0000-4000-8000-000000000005'::uuid, 40.4415, -79.9490, now())
ON CONFLICT (user_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = EXCLUDED.updated_at;

INSERT INTO public.always_share_locations (user_id, lat, lng, updated_at)
SELECT id, 40.4442, -79.9415, now() FROM auth.users WHERE email = 'rushabhj23@gmail.com' LIMIT 1
ON CONFLICT (user_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = EXCLUDED.updated_at;

-- ========== PART 7: LOCATION HISTORY (user_location_samples, last 12h, every 10 min) ==========
-- Per-user base coordinates so paths differ slightly. Rush + all dummies.
INSERT INTO public.user_location_samples (user_id, lat, lng, timestamp)
SELECT u.id, (u.base_lat + (random() * 0.002 - 0.001)), (u.base_lng + (random() * 0.002 - 0.001)), ts
FROM (
  SELECT id, 40.444 AS base_lat, -79.941 AS base_lng FROM auth.users WHERE email = 'rushabhj23@gmail.com'
  UNION ALL SELECT 'a0000001-0000-4000-8000-000000000001'::uuid, 40.443, -79.942
  UNION ALL SELECT 'a0000002-0000-4000-8000-000000000002'::uuid, 40.441, -79.945
  UNION ALL SELECT 'a0000003-0000-4000-8000-000000000003'::uuid, 40.445, -79.940
  UNION ALL SELECT 'a0000004-0000-4000-8000-000000000004'::uuid, 40.446, -79.938
  UNION ALL SELECT 'a0000005-0000-4000-8000-000000000005'::uuid, 40.440, -79.950
) u
CROSS JOIN generate_series(now() - interval '12 hours', now(), interval '10 minutes') AS ts
ON CONFLICT (user_id, timestamp) DO NOTHING;
