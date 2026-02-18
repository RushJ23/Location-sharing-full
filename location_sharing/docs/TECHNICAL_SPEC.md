# Location-Sharing Safety App — Technical Spec

## 1. Overview

A consent-first mobile app that tracks location on-device and shares it only during emergency escalation or with an opt-in "always share" list. Primary flows: curfew safety check, incident creation, escalation to emergency contacts, and optional always-on sharing with selected contacts.

## 2. Privacy and Data Scope

- **On-device only by default**: Location is sampled and stored locally (SQLite/Drift). No continuous upload to the backend.
- **Emergency scope**: Historical path (last 12 hours) is uploaded only when an incident is created (curfew timeout or "I need help"). Access is restricted via RLS to the incident subject and contacts in the escalation chain.
- **Always share**: Separate opt-in list; when enabled, the app periodically uploads current position so selected contacts can see "live-ish" location. Frequency is configurable (default ~5 min) and battery-conscious.
- **UI copy**: "We don't continuously share your location. It stays on your device unless an emergency is triggered."

## 3. Location Pipeline

- **Permissions**: Request foreground first, then background with clear explanation. Android: foreground service when tracking is on; iOS: background location capability and proper Info.plist usage.
- **Sampling**: Configurable interval (e.g. 2–15 min) to balance battery and 12h path fidelity. Persist every sample to local DB.
- **Storage**: Drift (SQLite). Rolling window of at least 12 hours; prune older rows. Expose "last 12h" for incident upload.

## 4. Curfew and Safety Check

- **Safe zones**: Geofenced circles (center + radius); stored in Supabase and optionally cached locally. Containment = point-in-circle (distance ≤ radius).
- **Schedule**: Each curfew has a **start time** and **end time** (local time + timezone), list of safe zone IDs, enabled flag, response timeout (e.g. 5–10 min). Stored in Supabase; execution is local via scheduled local notifications (`flutter_local_notifications` with timezone).
- **At start time**: The app schedules a local notification for each enabled curfew at its start time. When that time is reached, the OS shows "Are you safe?" with actions I'M SAFE / I NEED HELP (no app open or button tap required).
- **Outcomes**:
  - **I'm safe**: Notification is dismissed and a **recheck is scheduled in 10 minutes**. If the user is still not in a safe zone at that time, the notification is shown again. This repeats every 10 minutes until either the user is in a safe zone or the **end time** is reached, after which no further checks run for that curfew.
  - **I need help**: Create incident immediately and open create-incident flow.
- **Manual trigger**: The Safety screen "Run curfew check now" button still shows the same notification immediately (e.g. if the user wants to test or trigger an alert manually).

## 5. Incidents and Escalation

- **Creation**: Trigger = curfew_timeout | need_help | manual. Create row in `incidents`; upload last 12h to `incident_location_history`; create `incident_access` for Layer 1; invoke Edge Function to start escalation.
- **Escalation order ("closest → furthest")**:
  1. Contacts with location available (always-share or opted-in for emergency): sort by distance from subject's last known location (ascending).
  2. Others: use manual_priority within layer; if null, deterministic fallback (e.g. safe zone center or creation order by contact id).
  3. Order: Layer 1 (all contacts sorted as above) → then Layer 2 → then Layer 3.
- **Edge Function**: Notify Layer 1 contacts (push + Realtime). Wait for response window. If no "confirmed safe": escalate to Layer 2, then Layer 3. Record responses in `incident_access` (confirmed_safe_at, could_not_reach_at). Resolve incident when subject or a contact confirms safe, or user ends "need help".

## 6. Maps and Visibility

- **Map screen**: (1) Always-share connections (live-ish markers), (2) Active incidents and subject marker, (3) For authorized viewers, polyline of last 12h. Do not show emergency contacts by default unless there is an active incident or mutual always-share.
- **Provider**: Google Maps (`google_maps_flutter`). Polylines and markers for incidents; safe zones drawn as circles in app.

## 7. Backend and Security

- **Supabase**: Auth (email/password; OAuth optional), Postgres with RLS, Edge Functions (escalation, push), Realtime (incident updates).
- **RLS**: Consent-first (contact rows only after accepted request); incident data only for subject or contacts in `incident_access`; always-share locations only for recipients who have that user in their always-share list.
- **Push**: FCM; device token stored in `profiles`; Edge Function (or external service) sends notifications for incidents and escalation.

## 8. Ambiguous Defaults

- **Layer policy**: Layer 1 = precise location + 12h history; Layer 2/3 = configurable (e.g. coarse + 6h) via `layer_policies` table.
- **Always-share frequency**: Default 5 minutes when backgrounded; configurable in settings.
- **Response timeout**: Default 5–10 minutes per layer; stored in `curfew_schedules.response_timeout_minutes` and escalation config.

All defaults are documented in README and this spec and kept extensible.
