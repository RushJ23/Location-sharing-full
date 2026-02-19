-- Ensure incident_access sends full row to Realtime (helps with broadcasts).
ALTER TABLE public.incident_access REPLICA IDENTITY FULL;
