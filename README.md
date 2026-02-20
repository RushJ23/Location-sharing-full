# Location-Sharing Safety App

A consent-first mobile app that tracks your location on-device and shares it only during an emergency escalation or with an opt-in "always share" list. Built with Flutter and Supabase.

## Design rationale

- **Privacy first**: Location is stored locally; nothing is uploaded until an incident is triggered or you opt into always-share. See [docs/TECHNICAL_SPEC.md](docs/TECHNICAL_SPEC.md).
- **Backend: Supabase**: Auth, Postgres with RLS, Edge Functions for escalation, and Realtime for incident updates. RLS keeps "who can see what" in one place and fits incident-scoped access. See schema in [docs/SCHEMA.md](docs/SCHEMA.md).
- **Map: Google Maps**: `google_maps_flutter` for map screen, markers, and incident polylines (including path-point markers on incident detail). Simple setup and good Flutter support.
- **Incident UX**: Home shows an "Active incidents" card when you have incidents; incident detail shows the subject's name and path markers. Resolving or confirming safe refreshes Home and Map. "I couldn't reach them" triggers escalation to the next layer.
- **Split-up notification**: When someone is sharing their location with you and you were within 50m, then move apart, the app notifies you ("You are no longer with [name]")—SnackBar when in foreground, local notification when the app is open in background.

### Escalation order: "Closest → furthest"

When an incident is created, contacts are notified in order so that those who can help fastest are reached first:

1. **Contacts with location available**: If a contact is on your "Always Share" list (or has opted in to share location for emergency response), we use their latest known location. We compute distance from your last known position and sort **ascending** (closest first) within each layer.
2. **Others**: We use your **manual priority** order within the layer (if you set one). If not set, we use a deterministic fallback: e.g. their last known "home" or safe zone center if available, otherwise creation order by contact id so the order is stable.
3. **Layers**: Escalation runs Layer 1 first (all Layer 1 contacts in the order above), then after a timeout with no "confirmed safe" response, Layer 2, then Layer 3.

This is implemented in the escalation Edge Function and documented in code comments there and in [docs/TECHNICAL_SPEC.md](docs/TECHNICAL_SPEC.md).

## Getting started

### Prerequisites

- Flutter SDK ^3.11.0
- Dart 3.11+
- Supabase project (Auth, Postgres, Edge Functions, Realtime)
- Google Maps API key (Android + iOS) for map features

### Setup

1. Clone and open the project:
   ```bash
   cd location_sharing
   flutter pub get
   ```

2. **Environment**: Add your Supabase keys so the app can connect.
   - Put a `.env.local` file in the `location_sharing/` directory (Flutter project root) with:
     ```
     SUPABASE_URL=https://your-project.supabase.co
     SUPABASE_ANON_KEY=your-anon-key
     ```
   - Get the values from [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Settings** → **API** (Project URL and anon public key).
   - See `.env.local.example` for the exact variable names. You can still use `--dart-define=SUPABASE_URL=...` instead if you prefer.

3. **Supabase tables**: Create tables and RLS once (they are not created automatically). Apply **all** migrations (not just the initial schema). See [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) for details.
   - **Option A** – SQL Editor: In Supabase Dashboard → **SQL Editor**, run each migration file from `supabase/migrations/` in order.
   - **Option B** – CLI: Install [Supabase CLI](https://supabase.com/docs/guides/cli), then from `location_sharing/` run `supabase link --project-ref <your-project-ref>` and `supabase db push` to apply all migrations.

4. **Google Maps**: Add `GOOGLE_MAPS_API_KEY` to your `.env.local` (see step 2). The Android and iOS builds read it from that file automatically; no need to edit the manifest or AppDelegate by hand.

5. **Permissions** (see below) must be declared for location and background execution.

### Run

```bash
flutter run
```

## Permissions

- **Location**: Foreground and background. The app requests background only after explaining why (safety check and curfew). On Android a foreground service is used when tracking is enabled.
- **Notifications**: Required for "Are you safe?" and split-up ("You are no longer with [name]") when the app is in background. Local notifications are used for safety checks and split-up. Incidents are visible in the app when contacts open it (no push).

See platform docs:

- [Android location](https://developer.android.com/training/location/permissions)
- [iOS location](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services)
- [Android foreground service](https://developer.android.com/develop/background-work/services/foreground-services)

## Project structure

```
lib/
  core/         # auth, config, router, theme
  data/         # local DB (Drift), remote (Supabase), repositories
  features/     # auth, onboarding, contacts, map, settings, incidents, safety
  shared/       # shared widgets and domain models
```

## Tests

- Unit: safe zone containment (point-in-circle), curfew check (isInsideAnySafeZone), app widget.
- Integration: `integration_test/app_test.dart` (app launch); run with `flutter test integration_test/` on a device or emulator.

Run: `flutter test`

## Docs

- [Technical spec](docs/TECHNICAL_SPEC.md) — privacy, location pipeline, curfew, escalation, maps, split-up notification.
- [Schema and RLS](docs/SCHEMA.md) — Postgres tables and security policies.

## License

Private / course project. See repo for details.
