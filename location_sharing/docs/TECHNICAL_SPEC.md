# Location-Sharing Safety App — Technical Spec

## 1. Overview

A consent-first mobile app that tracks location on-device and shares it only during emergency escalation or with an opt-in "always share" list. Primary flows: curfew safety check, incident creation, escalation to emergency contacts, and optional always-on sharing with selected contacts.

## 2. Privacy and Data Scope

- **Continuous upload**: Location is sampled every 5 min and stored locally (SQLite/Drift). The last 12h is also uploaded to `user_location_samples` in Supabase so incident creation (server-side timeout or app) can use it.
- **Emergency scope**: Historical path (last 12 hours) is available from `user_location_samples` and copied to `incident_location_history` when an incident is created. Access is restricted via RLS to the incident subject and contacts in the escalation chain.
- **Always share**: Separate opt-in list; when enabled, the app periodically uploads current position so selected contacts can see "live-ish" location. Frequency is configurable (default ~5 min) and battery-conscious.
- **UI copy**: "We don't continuously share your location. It stays on your device unless an emergency is triggered."

## 3. Location Pipeline

- **Permissions**: Request foreground first, then background with clear explanation. Android: foreground service when tracking is on; iOS: background location capability and proper Info.plist usage.
- **Sampling**: Configurable interval (e.g. 2–15 min; default 5 min) to balance battery and 12h path fidelity. Persist every sample to local DB. After each sample, the last 12h is uploaded to `user_location_samples` for all logged-in users (runs in foreground and background; only stops on logout).
- **Current position**: `AlwaysShareLocationUpdater` runs every 45s for every logged-in user and upserts the current position into `always_share_locations`. This ensures incident flows have a recent position and always-share contacts can see live-ish location on the map.
- **Storage**: Drift (SQLite). Rolling window of at least 12 hours; prune older rows. Expose "last 12h" for incident upload.

## 4. Curfew and Safety Check

- **Safe zones**: Geofenced circles (center + radius); stored in Supabase and optionally cached locally. Containment = point-in-circle (distance ≤ radius).
- **Schedule**: Each curfew has a **start time** and **end time** (local time + timezone), list of safe zone IDs, enabled flag, response timeout (e.g. 5–10 min). Stored in Supabase; execution is local via scheduled local notifications (`flutter_local_notifications` with timezone).
- **At start time**: The app schedules a local notification and registers a **pending safety check** with `expires_at = start_time + response_timeout_minutes`. The countdown runs server-side; if the user does not respond by `expires_at`, the `expire-pending-safety-checks` Edge Function creates an incident.
- **Outcomes**:
  - **I'm safe**: Notification is dismissed; app calls `respond_to_safety_check`; a **recheck is scheduled in 10 minutes** with a new pending check. If the user is still not in a safe zone at that time, the notification is shown again.
  - **I need help**: App calls `respond_to_safety_check`; create incident immediately and open create-incident flow; Layer 1 contacts see the incident when they open the app.
- **Manual trigger**: The Safety screen "Run curfew check now" shows the same in-app dialog with a 5-min countdown and registers a pending check for manual flow.

## 5. Incidents and Escalation

- **Creation**: Trigger = curfew_timeout | need_help | manual. Create row in `incidents`; copy last 12h from `user_location_samples` to `incident_location_history`; invoke `escalate` Edge Function (adds Layer 1 to `incident_access`). Contacts see the incident when they open the app.
- **Background timeout**: The `expire-pending-safety-checks` Edge Function must be invoked every 1–2 minutes (external cron or Supabase cron). It expires unresponded pending checks, creates incidents, and runs escalation.
- **Escalation order ("closest → furthest")**:
  1. Contacts with location available (always-share or opted-in for emergency): sort by distance from subject's last known location (ascending).
  2. Others: use manual_priority within layer; if null, deterministic fallback (e.g. safe zone center or creation order by contact id).
  3. Order: Layer 1 (all contacts sorted as above) → then Layer 2 → then Layer 3.
- **Edge Function `escalate`**: Accepts `incident_id` and `layer` (1, 2, or 3). Adds Layer N contacts to `incident_access`. No push; contacts see incidents when they open the app based on their access.
- **Time-based escalation**: `expire-pending-safety-checks` runs every 1–2 min; for active incidents, at +10 min invokes escalate(layer=2), at +20 min invokes escalate(layer=3).
- **Contact "I couldn't reach them"**: When a contact taps "I couldn't reach them", the app updates `incident_access.could_not_reach_at` and immediately invokes `escalate(incident_id, layer: myLayer + 1)` so the next layer (2 or 3) is notified. No further escalation if the contact is already layer 3.
- **Contact "I confirm they're safe"**: Resolves the incident and navigates to Home; Home and Map providers are invalidated so the active incident card and map update immediately.
- **Incident popup**: If the subject has an active incident, the app shows a blocking "I am safe" dialog on open/resume until they resolve it.
- **Incident detail**: App bar shows subject display name ("Incident — {name}"). The 12h location path is shown as a polyline plus one marker per path point; "Current location" marker when live tracking is active.

## 6. Maps and Visibility

- **Home screen**: When the user has active incidents (as subject or contact), an "Active incidents" card is shown; tapping it navigates to the Map. The card and map data refresh on app resume and when an incident is resolved.
- **Map screen**: (1) Always-share connections (live-ish markers), (2) Active incidents and subject marker, (3) For authorized viewers, polyline of last 12h. Map subscribes to Realtime on `incident_access` so new incidents appear without leaving the screen. Do not show emergency contacts by default unless there is an active incident or mutual always-share. The app updates `always_share_locations` for all users; only contacts who have you in their always-share list can see your marker.
- **Incident detail map**: Polyline for the 12h path plus one marker per path point (with timestamp in info window); optional "Current location" marker when the subject's live position is being updated.
- **Provider**: Google Maps (`google_maps_flutter`). Polylines and markers for incidents; safe zones drawn as circles in app.

## 6a. Split-up notification

- When the app is open (foreground or background), a periodic check (every 45s) compares the current user's location to everyone who is "always sharing" with them (`get_my_always_share_locations`). If a contact was within 50m on the previous check and is now beyond 50m, the user is notified: **"You are no longer with [display name]."**
- **Foreground**: SnackBar via the app navigator context.
- **Background**: Local notification (notification tray) via `SafetyNotificationService.showSplitUpNotification(displayName)` so it works when the app is only open in the background.
- No Supabase schema changes; uses existing RPC and device location. State (who was "near") is in-memory only; the service starts when the user logs in and stops on logout (same lifecycle as location updater and incident notifier).

## 7. Backend and Security

- **Supabase**: Auth (email/password; OAuth optional), Postgres with RLS, Edge Functions (escalation), Realtime (incident updates).
- **RLS**: Consent-first (contact rows only after accepted request); incident data only for subject or contacts in `incident_access`; always-share locations only for recipients who have that user in their always-share list.
- **Incident visibility**: Contacts see incidents when they open the app; access is determined by `incident_access` (Layer 1 at create, Layer 2 at +10 min, Layer 3 at +20 min). Realtime on `incident_access` can refresh the list when the app is open.

## 8. Ambiguous Defaults

- **Layer policy**: Layer 1 = precise location + 12h history; Layer 2/3 = configurable (e.g. coarse + 6h) via `layer_policies` table.
- **Location upload**: Current position to `always_share_locations` every 45s for all users; last 12h to `user_location_samples` every 5 min (configurable in `LocationTrackingService`).
- **Response timeout**: Default 5–10 minutes per layer; stored in `curfew_schedules.response_timeout_minutes`.

All defaults are documented in README and this spec and kept extensible.

## 9. Setup (Post-Migration)

### Migrations (apply all)
- Initial schema plus: `curfew_start_end_time`, `accept_contact_request_function`, `always_share_rpc_and_accept_trigger`, `get_locations_by_user_ids`, `fix_incidents_rls_recursion`, `fix_always_share_direction`, `user_location_samples_and_pending_safety_checks`, `incidents_subject_location`, `pending_safety_check_rpc`, `enable_realtime_incident_access`, `incident_access_replica_identity_full`.
- **Realtime for `incident_access`**: The `enable_realtime_incident_access` migration adds `incident_access` to `supabase_realtime` publication. The `incident_access_replica_identity_full` migration sets `REPLICA IDENTITY FULL` on `incident_access`. Both are required for emergency contacts to receive Realtime-based local notifications when incidents are created.

### You still need to do
1. **Schedule `expire-pending-safety-checks`**  
   The migration `20250219070000_cron_expire_pending_safety_checks.sql` sets up **pg_cron** to call the function every 2 minutes. You must:
   - Enable **pg_cron** and **pg_net** in Supabase Dashboard → Database → Extensions (if not already enabled).
   - Add two secrets to **Vault** (Dashboard → SQL Editor, run once with your values):
     ```sql
     SELECT vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'project_url');
     SELECT vault.create_secret('YOUR_ANON_KEY', 'anon_key');
     ```
   After that, the cron runs every 2 minutes and expires pending safety checks and escalates incidents (L2 at +10 min, L3 at +20 min).  
   Alternatively you can call the function from an external cron (e.g. cron-job.org) with `POST …/functions/v1/expire-pending-safety-checks` and `Authorization: Bearer <ANON_OR_SERVICE_ROLE_KEY>`.

2. **Incident visibility**  
   Contacts see incidents when they open the app. No push or Firebase required. Ensure the `escalate` and `expire-pending-safety-checks` Edge Functions are deployed and the cron job is scheduled (see above).
