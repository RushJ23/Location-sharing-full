-- user_location_samples: rolling 12h location history per user, uploaded continuously
CREATE TABLE IF NOT EXISTS public.user_location_samples (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  timestamp timestamptz NOT NULL,
  UNIQUE(user_id, timestamp)
);

CREATE INDEX IF NOT EXISTS idx_user_location_samples_user_timestamp
  ON public.user_location_samples (user_id, timestamp);

ALTER TABLE public.user_location_samples ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own location samples" ON public.user_location_samples
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own location samples" ON public.user_location_samples
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own location samples" ON public.user_location_samples
  FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Users can read own location samples" ON public.user_location_samples
  FOR SELECT USING (auth.uid() = user_id);

-- pending_safety_checks: server-side timeout; pg_cron expires and creates incident if no response
CREATE TABLE IF NOT EXISTS public.pending_safety_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  schedule_id uuid REFERENCES public.curfew_schedules(id) ON DELETE SET NULL,
  expires_at timestamptz NOT NULL,
  responded_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_pending_safety_checks_expires
  ON public.pending_safety_checks (expires_at) WHERE responded_at IS NULL;

ALTER TABLE public.pending_safety_checks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own pending safety checks" ON public.pending_safety_checks
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own pending safety checks" ON public.pending_safety_checks
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can read own pending safety checks" ON public.pending_safety_checks
  FOR SELECT USING (auth.uid() = user_id);
