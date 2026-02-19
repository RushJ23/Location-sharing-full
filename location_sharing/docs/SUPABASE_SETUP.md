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
