-- Initial schema for Location Sharing Safety App
-- Run in Supabase SQL editor or via supabase db push

-- Profiles (1:1 with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  avatar_url text,
  phone text,
  school text,
  fcm_token text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
-- Allow authenticated users to read profiles for contact search (app only requests id, display_name, avatar_url)
CREATE POLICY "Authenticated can read profiles for search" ON public.profiles
  FOR SELECT USING (auth.role() = 'authenticated');

-- Contact requests
CREATE TABLE IF NOT EXISTS public.contact_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(from_user_id, to_user_id)
);

ALTER TABLE public.contact_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own contact requests" ON public.contact_requests
  FOR SELECT USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);
CREATE POLICY "Users can insert as sender" ON public.contact_requests
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);
CREATE POLICY "Receivers can update status" ON public.contact_requests
  FOR UPDATE USING (auth.uid() = to_user_id);

-- Contacts (mutual; each user has own row)
CREATE TABLE IF NOT EXISTS public.contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  layer int NOT NULL CHECK (layer IN (1, 2, 3)),
  is_always_share boolean NOT NULL DEFAULT false,
  manual_priority int,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(user_id, contact_user_id)
);

ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own contacts" ON public.contacts
  FOR ALL USING (auth.uid() = user_id);

-- Safe zones
CREATE TABLE IF NOT EXISTS public.safe_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  center_lat double precision NOT NULL,
  center_lng double precision NOT NULL,
  radius_meters double precision NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.safe_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own safe zones" ON public.safe_zones
  FOR ALL USING (auth.uid() = user_id);

-- Curfew schedules
CREATE TABLE IF NOT EXISTS public.curfew_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  safe_zone_ids uuid[] NOT NULL DEFAULT '{}',
  time_local time NOT NULL,
  timezone text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  response_timeout_minutes int NOT NULL DEFAULT 10,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.curfew_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own curfew schedules" ON public.curfew_schedules
  FOR ALL USING (auth.uid() = user_id);

-- Incidents
CREATE TABLE IF NOT EXISTS public.incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
  trigger text NOT NULL CHECK (trigger IN ('curfew_timeout', 'need_help', 'manual')),
  last_known_lat double precision,
  last_known_lng double precision,
  created_at timestamptz DEFAULT now() NOT NULL,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id)
);

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own incidents" ON public.incidents
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can read incidents where they are contact" ON public.incidents
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.incident_access ia
      WHERE ia.incident_id = incidents.id AND ia.contact_user_id = auth.uid()
    )
  );
CREATE POLICY "Users can insert own incident" ON public.incidents
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Subject or contacts can update incident" ON public.incidents
  FOR UPDATE USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.incident_access ia WHERE ia.incident_id = incidents.id AND ia.contact_user_id = auth.uid())
  );

-- Incident access
CREATE TABLE IF NOT EXISTS public.incident_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
  contact_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  layer int NOT NULL CHECK (layer IN (1, 2, 3)),
  notified_at timestamptz,
  confirmed_safe_at timestamptz,
  could_not_reach_at timestamptz,
  UNIQUE(incident_id, contact_user_id)
);

ALTER TABLE public.incident_access ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Subject or contact can read incident_access" ON public.incident_access
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.incidents i WHERE i.id = incident_id AND i.user_id = auth.uid())
    OR contact_user_id = auth.uid()
  );
-- Inserts/updates by Edge Function (service role) or allow subject to create when creating incident
CREATE POLICY "Service role or subject can manage incident_access" ON public.incident_access
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.incidents i WHERE i.id = incident_id AND i.user_id = auth.uid())
  );

-- Incident location history
CREATE TABLE IF NOT EXISTS public.incident_location_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  timestamp timestamptz NOT NULL
);

ALTER TABLE public.incident_location_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Subject or contact can read incident_location_history" ON public.incident_location_history
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.incidents i WHERE i.id = incident_id AND i.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.incident_access ia WHERE ia.incident_id = incident_id AND ia.contact_user_id = auth.uid())
  );
CREATE POLICY "Subject can insert own incident history" ON public.incident_location_history
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.incidents i WHERE i.id = incident_id AND i.user_id = auth.uid())
  );

-- Always share locations (one row per user who shares)
CREATE TABLE IF NOT EXISTS public.always_share_locations (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.always_share_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can update own always_share_locations" ON public.always_share_locations
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can read always_share for their always-share contacts" ON public.always_share_locations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.contacts c WHERE c.user_id = auth.uid() AND c.contact_user_id = always_share_locations.user_id AND c.is_always_share = true)
  );

-- Layer policies (optional)
CREATE TABLE IF NOT EXISTS public.layer_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  layer int NOT NULL CHECK (layer IN (1, 2, 3)),
  precision text NOT NULL DEFAULT 'precise' CHECK (precision IN ('precise', 'coarse')),
  history_hours int NOT NULL DEFAULT 12
);

ALTER TABLE public.layer_policies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own layer_policies" ON public.layer_policies
  FOR ALL USING (auth.uid() = user_id);

-- Trigger to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
