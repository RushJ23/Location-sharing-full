# Supabase setup

## 1. Run the database migrations

Apply all migrations so the app can use Supabase. The app requires **all** migrations, including Realtime for `incident_access` (used for emergency contact notifications).

- **Option A – Supabase Dashboard**  
  In [Supabase Dashboard](https://supabase.com/dashboard) → your project → **SQL Editor**, run each migration file in order from `supabase/migrations/` (alphabetically by timestamp). In particular:
  - `20250219030000_enable_realtime_incident_access.sql` — adds `incident_access` to `supabase_realtime` publication (required for contact notifications).
  - `20250219040000_incident_access_replica_identity.sql` — sets `REPLICA IDENTITY FULL` on `incident_access`.

- **Option B – Supabase CLI**  
  From the project root (`location_sharing/`):

  ```bash
  supabase link --project-ref <your-project-ref>
  supabase db push
  ```

- **Option C – Supabase MCP**  
  If you use Supabase MCP, apply all migrations from `supabase/migrations/` in order.

The `incident_access` table must be in the `supabase_realtime` publication for emergency contacts to receive local notifications when incidents are created.

## 2. Fix verification email redirect (no localhost)

So confirmation emails open the app instead of localhost:

1. In **Supabase Dashboard** → your project → **Authentication** → **URL Configuration**:
   - **Site URL**: set to your app’s auth callback, e.g.  
     `location-sharing://auth/callback`
   - **Redirect URLs**: add (one per line):
     - `location-sharing://auth/callback`
     - `location-sharing://**`  
     (the wildcard allows any path under the scheme)

2. The app is already configured to use the deep link `location-sharing://auth/callback` for sign-up email confirmation. When the user taps the link in the email, the app opens and completes the session.

No need to run a localhost site for email verification.

## 3. Edge Functions: incidents and escalation

For **“I need help”** and **Layer 2/3 escalation** to work, deploy the Edge Functions and set secrets.

### Deploy functions

From `location_sharing/` (or the repo root containing `supabase/`):

```bash
supabase functions deploy escalate
supabase functions deploy expire-pending-safety-checks
```

### Secrets for the `escalate` function

The app calls `escalate` when you tap “I need help”; it adds Layer 1 to `incident_access` . Contacts see incidents when they open the app (no push). No extra secrets required for the escalate function.

### Time-based escalation (Layer 2 at +10 min, Layer 3 at +20 min)

The **expire-pending-safety-checks** function is invoked every 2 minutes by **pg_cron**. It:

1. Expires unresponded pending safety checks and creates incidents (notifying Layer 1).
2. For active incidents: if created ≥10 min ago, calls `escalate(incident_id, layer: 2)`; if created ≥20 min ago, calls `escalate(incident_id, layer: 3)`.

**Required:**

1. **Enable extensions**  
   Dashboard → **Database** → **Extensions** → enable **pg_cron** and **pg_net**.

2. **Vault secrets for the cron job**  
   In **SQL Editor**, run once (replace `YOUR_PROJECT_REF` and key):

   ```sql
   SELECT vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'project_url');
   SELECT vault.create_secret('YOUR_ANON_KEY', 'anon_key');
   ```

   Use your **Project URL** (e.g. `https://abcdefgh.supabase.co`) and **anon** key from **Settings → API**. If the cron runs but the function is never invoked (e.g. 403), store the **service_role** key instead as `anon_key` so the scheduled HTTP request is authorized.

3. **Apply the cron migration**  
   The migration `20250219070000_cron_expire_pending_safety_checks.sql` schedules the job. If you already ran it, the job is updated; otherwise run that migration so the schedule exists.

After this, “I need help” notifies Layer 1 immediately via `escalate`, and Layers 2 and 3 are notified automatically at 10 and 20 minutes if the incident is still active.
