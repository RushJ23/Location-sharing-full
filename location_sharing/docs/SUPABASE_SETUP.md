# Supabase setup

## 1. Run the database migration

Apply the schema and RLS so the app can use Supabase.

- **Option A – Supabase Dashboard**  
  In [Supabase Dashboard](https://supabase.com/dashboard) → your project → **SQL Editor**, paste and run the contents of:

  `supabase/migrations/20250217000000_initial_schema.sql`

- **Option B – Supabase CLI**  
  From the project root:

  ```bash
  supabase link --project-ref <your-project-ref>
  supabase db push
  ```

- **Option C – Supabase MCP**  
  If you use Supabase MCP, execute the SQL from  
  `supabase/migrations/20250217000000_initial_schema.sql`  
  in your connected project.

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
