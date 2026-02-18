-- Curfew schedules: add end_time and rename time_local to start_time.
-- Each curfew has a window [start_time, end_time] when user should be in a safe zone.
-- Idempotent: safe to run if already applied.

ALTER TABLE public.curfew_schedules
  ADD COLUMN IF NOT EXISTS end_time time;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'curfew_schedules' AND column_name = 'time_local') THEN
    UPDATE public.curfew_schedules SET end_time = COALESCE(end_time, time_local);
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'curfew_schedules' AND column_name = 'start_time') THEN
    UPDATE public.curfew_schedules SET end_time = COALESCE(end_time, start_time);
  END IF;
END $$;

ALTER TABLE public.curfew_schedules
  ALTER COLUMN end_time SET NOT NULL,
  ALTER COLUMN end_time SET DEFAULT '23:59'::time;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'curfew_schedules' AND column_name = 'time_local') THEN
    ALTER TABLE public.curfew_schedules RENAME COLUMN time_local TO start_time;
  END IF;
END $$;
