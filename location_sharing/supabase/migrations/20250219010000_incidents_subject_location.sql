-- Add subject current location columns to incidents (for live tracking during active incident)
ALTER TABLE public.incidents
  ADD COLUMN IF NOT EXISTS subject_current_lat double precision,
  ADD COLUMN IF NOT EXISTS subject_current_lng double precision,
  ADD COLUMN IF NOT EXISTS subject_location_updated_at timestamptz;
