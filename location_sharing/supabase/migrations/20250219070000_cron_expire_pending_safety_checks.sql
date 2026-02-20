-- Schedule expire-pending-safety-checks Edge Function every 2 minutes via pg_cron + pg_net.
-- This drives: (1) expiring pending safety checks → create incident + notify Layer 1,
-- (2) time-based escalation: Layer 2 at +10 min, Layer 3 at +20 min for active incidents.
--
-- Requires: pg_cron and pg_net (Dashboard → Database → Extensions). Then add Vault secrets
-- (Dashboard → SQL Editor, run once; replace with your project ref and key):
--
--   SELECT vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'project_url');
--   SELECT vault.create_secret('YOUR_ANON_KEY', 'anon_key');
--
-- Use the anon (publishable) key, or if the cron never triggers the function, use the
-- service_role key as 'anon_key' so the HTTP call is authorized. The function itself
-- uses SUPABASE_SERVICE_ROLE_KEY from env for DB access.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

DO $$
DECLARE
  j bigint;
BEGIN
  SELECT jobid INTO j FROM cron.job WHERE jobname = 'expire-pending-safety-checks' LIMIT 1;
  IF j IS NOT NULL THEN
    PERFORM cron.unschedule(j);
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Run every 2 minutes
SELECT cron.schedule(
  'expire-pending-safety-checks',
  '*/2 * * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/expire-pending-safety-checks',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key')
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
