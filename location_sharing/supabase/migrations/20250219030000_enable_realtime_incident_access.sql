-- Enable Supabase Realtime for incident_access so the app can listen
-- for new rows when contacts are escalated and show in-app notifications.
ALTER PUBLICATION supabase_realtime ADD TABLE public.incident_access;
