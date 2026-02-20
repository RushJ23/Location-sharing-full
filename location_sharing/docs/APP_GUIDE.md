# Location-Sharing Safety App — Comprehensive Guide

A detailed guide to how the app works, its design decisions, features, and how it can help people in different situations.

---

## 1. Overview and Purpose

The Location-Sharing Safety App is a **consent-first mobile application** that prioritizes user privacy while providing robust emergency response capabilities. It tracks location on-device and shares it **only** when:

1. An incident is triggered (curfew timeout, "I need help," or manual)
2. A user opts in to "always share" with specific contacts

The app is built with **Flutter** (iOS and Android) and **Supabase** (auth, Postgres, Edge Functions, Realtime). It aims to help people stay safe by connecting them with trusted emergency contacts who can be notified quickly and in the right order when something goes wrong.

### Tagline

**"Stay safe, stay connected"**

---

## 2. Design Philosophy and Rationale

### 2.1 Privacy First

The app's central design principle is **consent and minimal data sharing**:

- **Location stays on-device by default**: Sampled every 5 minutes and stored locally (SQLite/Drift). Nothing is uploaded to the cloud until an incident is triggered or you opt into always-share.
- **Clear UI copy**: *"We don't continuously share your location. It stays on your device unless an emergency is triggered."*
- **Emergency scope**: When an incident is created, the last 12 hours of location history is copied to the server and access is restricted via Row Level Security (RLS) to only the incident subject and contacts in the escalation chain.
- **No surveillance**: Contacts cannot see your location unless you have an active incident or you have explicitly enabled "always share" for them.

This philosophy was chosen to address common concerns with location-tracking apps: users want safety, but not at the cost of constant surveillance or involuntary sharing.

### 2.2 Consent-First Social Model

- **Contact relationships require mutual consent**: One user sends a request; the other must accept or decline. Contact rows are created only after both sides agree.
- **Always share is opt-in**: You explicitly toggle "Always share" for each contact. They see your live-ish location on the map only when this is on.
- **Curfew and safe zones are user-defined**: You choose when checks run and where your safe zones are. The app never assumes defaults without your input.

---

## 3. Architecture and Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Client** | Flutter (Dart) | Cross-platform mobile UI, navigation, state (Riverpod) |
| **Auth** | Supabase Auth | Email/password sign-up and login; optional OAuth |
| **Database** | Supabase (Postgres) | Profiles, contacts, incidents, location samples, RLS |
| **Backend logic** | Supabase Edge Functions (Deno) | Escalation, expire-pending-safety-checks |
| **Realtime** | Supabase Realtime | Incident access notifications to contacts |
| **Maps** | Google Maps (`google_maps_flutter`) | Map screen, markers, polylines, safe zone circles |
| **Local storage** | Drift (SQLite) | Rolling 12h location history on-device |
| **Notifications** | `flutter_local_notifications` | Safety checks, split-up, incident alerts |
| **Background** | Workmanager | Periodic incident check when app is backgrounded |

### Project Structure

```
lib/
  core/         # Auth, config, router, theme
  data/         # Local DB (Drift), remote (Supabase), repositories
  features/     # auth, onboarding, contacts, map, settings, incidents, safety, split_up
  shared/       # Shared widgets and domain models
```

---

## 4. Features in Detail

### 4.1 Location Pipeline

| Component | Behavior |
|-----------|----------|
| **Sampling** | Configurable interval (default 5 min). Every sample is persisted to local DB. |
| **Pruning** | Rolling window of 12 hours; older samples are removed. |
| **Upload** | Last 12h uploaded to `user_location_samples` in Supabase after each sample (for incident creation). |
| **Current position** | `AlwaysShareLocationUpdater` runs every 45s; upserts into `always_share_locations` for all logged-in users (so incident flows and always-share contacts have recent position). |
| **Permissions** | Foreground first; then background with explanation. Android uses foreground service when tracking. |
| **Accuracy** | Medium (balance of battery and fidelity). |

**Design decision**: 5-minute sampling balances battery life with path fidelity for the 12h history. 45s for current position ensures incident responders and always-share contacts see reasonably fresh location.

---

### 4.2 Safe Zones and Curfew

**Safe zones** are user-defined circular geofences (center + radius). Containment is computed as point-in-circle (distance ≤ radius).

**Curfew schedules** define when the app runs "Are you safe?" checks:

- **Start time** (e.g., 22:00): Be in a safe zone by this time.
- **End time** (e.g., 06:00): Stop checking after this time (can span next day).
- **Timezone**: IANA (e.g., `America/New_York`).
- **Response timeout**: Default 10 minutes. If the user doesn’t respond in time, an incident is created.
- **Safe zone list**: Which zones apply for this curfew.

**Flow**:

1. At start time, the app schedules a local notification and registers a **pending safety check** with `expires_at = start_time + response_timeout_minutes`.
2. The user taps the notification → in-app "Are you safe?" dialog appears.
3. **I'm safe**: App responds; a recheck is scheduled in 10 minutes. If still not in a safe zone, the notification repeats.
4. **I need help**: Incident is created immediately; Layer 1 contacts are notified.
5. If the user does not respond by `expires_at`, the server-side cron (`expire-pending-safety-checks`) creates an incident and notifies Layer 1.

**Manual trigger**: Safety screen has a bell icon ("Run curfew check now") — same dialog, 5-minute countdown, creates incident on timeout.

**Design decision**: Recheck every 10 minutes until in a safe zone or end time avoids both over-pestering and long gaps where someone might be in trouble.

---

### 4.3 Incidents and Escalation

#### Incident Triggers

| Trigger | Meaning |
|---------|---------|
| `curfew_timeout` | User did not respond to safety check in time. |
| `need_help` | User tapped "I need help" in the safety dialog. |
| `manual` | User manually created an incident (future/edge cases). |

#### Incident Lifecycle

1. **Creation**: Row in `incidents`; last 12h from `user_location_samples` copied to `incident_location_history`; `escalate` Edge Function adds Layer 1 to `incident_access`.
2. **Layer 1**: Contacted first (immediately on create or via cron).
3. **Layer 2**: Notified at +10 minutes if incident still active (cron).
4. **Layer 3**: Notified at +20 minutes if incident still active (cron).
5. **Resolution**: Subject taps "I am safe" or a contact taps "I confirm they're safe." Incident status → `resolved`.

#### Escalation Order: "Closest → Furthest"

When adding contacts to `incident_access`, the order favors people who can help fastest:

1. **Contacts with location available** (always-share or opted-in): Sorted by distance from subject’s last known location (ascending).
2. **Others**: Use manual priority within layer, or deterministic fallback (safe zone center, creation order).
3. **Layers**: Layer 1 first, then Layer 2, then Layer 3.

**Design decision**: Notifying the closest capable person first increases the chance of fast, practical help (e.g., a roommate or nearby friend).

#### Contact Actions

- **I confirm they're safe**: Resolves the incident; navigates to Home.
- **I couldn't reach them**: Marks `could_not_reach_at`; immediately invokes escalation to next layer (2 or 3). Layer 3 contacts do not escalate further.

#### Incident Popup Guard

If the subject has an active incident, a blocking "I am safe" dialog appears on app open/resume until they resolve it. Prevents the subject from ignoring their own incident.

---

### 4.4 Map and Visibility

- **Home screen**: "Active incidents" card when the user has incidents (as subject or contact). Tapping goes to Map.
- **Map screen**:
  - Always-share connections: Live-ish markers for contacts who share with you.
  - Active incidents: Subject marker and last-known location; tap → incident detail.
  - Safe zones: Circles on the map.
  - Realtime: Subscribes to `incident_access` INSERTs; new incidents appear without leaving the map.
- **Incident detail map**:
  - Polyline for 12h path with markers for "1h ago" … "12h ago" and "Current location."
  - Filter chips to jump to any time point.
  - Live position when subject’s app is updating `subject_current_lat/lng`.

**Design decision**: Do not show emergency contacts by default unless there is an active incident or mutual always-share. Keeps the map focused and private.

---

### 4.5 Split-Up Notification

When someone is **always sharing** with you and you were within **50m**, then move apart:

- **Foreground**: SnackBar — *"You are no longer with [name]."*
- **Background**: Local notification in the tray.

**Check interval**: 45 seconds. State (who was "near") is in-memory only; service starts on login and stops on logout.

**Design decision**: Useful for groups (e.g., parents with kids, friends at events) to notice if someone has wandered off.

---

### 4.6 Incident Notifications to Contacts

- **Realtime**: Subscribes to `incident_access` INSERTs where `contact_user_id = current user`. When a new row is inserted, a local notification is shown: *"Emergency: [name] needs help. Tap to view their location."*
- **Missed checks**: On app resume, the app fetches recent `incident_access` rows and shows notifications for any it hasn’t yet shown.
- **Background**: Workmanager runs every 5 minutes; on Android, a one-off task runs ~15 seconds after app pause to catch incidents quickly.
- **Deep link**: `location-sharing://incidents/<id>` opens the incident detail screen.

**Design decision**: Uses local notifications + Realtime instead of Firebase Cloud Messaging to avoid extra infra and keep incident flow self-contained.

---

### 4.7 Contacts and Layers

- **Search**: By display name; send contact request.
- **Incoming requests**: Accept or decline.
- **My contacts**: Each has a layer (1, 2, or 3) and an "Always share" toggle.
- **Layer**: Determines escalation order (Layer 1 first, etc.).
- **Always share**: When on, that contact sees your live-ish location on the map.

**Design decision**: Three layers allow a clear escalation path (e.g., close friends → family → broader network) without over-complicating.

---

### 4.8 Onboarding and "How It Works"

The onboarding screen explains:

1. Privacy first — location stays on device unless emergency.
2. Steps: allow location, add safe zones, set curfew (optional), add emergency contacts.

**Design decision**: Explicit explanation builds trust and reduces anxiety about location sharing.

---

## 5. Design Decisions Summary

| Decision | Rationale |
|----------|-----------|
| **Privacy-first** | Users want safety without continuous surveillance. |
| **Consent-based contacts** | Avoids unilateral tracking; both sides agree. |
| **12h history** | Enough for incident response; limits data scope. |
| **5 min sampling** | Balances battery and path fidelity. |
| **45s current position** | Fresh enough for responders; not excessive. |
| **Closest-first escalation** | Prioritizes people who can physically help fastest. |
| **3 layers** | Simple escalation hierarchy without complexity. |
| **Local notifications** | No FCM; works with Supabase Realtime + Workmanager. |
| **RLS in Postgres** | Central place for "who can see what"; incident-scoped access. |
| **Supabase** | Auth, DB, Realtime, Edge Functions in one stack. |
| **Google Maps** | Good Flutter support; familiar UX. |
| **50m split-up threshold** | Sensible for "same place" vs "separated." |
| **10 min recheck** | Gives time to get to safe zone; avoids spam. |

---

## 6. How It Helps People in Different Situations

### 6.1 Students and Young Adults (e.g., Late-Night Campus)

- **Curfew**: Set a schedule (e.g., 22:00–06:00). If they don’t confirm they’re safe, parents or roommates are notified.
- **Safe zones**: Dorm, library, friend’s apartment.
- **Layers**: Roommate (Layer 1), parents (Layer 2), RA or campus safety (Layer 3).
- **Split-up**: If a friend was with them and moves away, they get a notification.

---

### 6.2 Parents and Children

- **Curfew**: Children set a curfew; parents are Layer 1.
- **Always share**: Parent can see child’s location when enabled; useful for pickups or checking they’re at school/home.
- **Incident**: If child doesn’t respond to "Are you safe?", parents are notified with location history.
- **Split-up**: Useful at crowded places (mall, park) to notice if a child has wandered off.

---

### 6.3 Solo Travelers or Hikers

- **Manual incident**: Can create incident if lost or injured.
- **12h path**: Gives rescuers a trail to follow.
- **Layers**: Close friend (Layer 1), family (Layer 2), emergency contact (Layer 3).

---

### 6.4 People in Higher-Risk Situations

- **"I need help"**: One tap from the safety dialog creates an incident and notifies Layer 1.
- **Location history**: Helps responders understand recent movement.
- **No push required**: Works even if notification delivery is unreliable; contacts see incidents when they open the app.

---

### 6.5 Groups at Events (Concert, Festival)

- **Always share**: Friends can see each other on the map.
- **Split-up**: *"You are no longer with [name]"* helps the group notice if someone got separated.

---

### 6.6 Caregivers and Elderly Family Members

- **Curfew**: E.g., "Be home by 20:00." If no response, family is notified.
- **Safe zones**: Home, doctor’s office, senior center.
- **Layers**: Primary caregiver (Layer 1), other family (Layer 2), neighbor (Layer 3).

---

## 7. Data Flow and Security

### 7.1 Row Level Security (RLS) Summary

| Table | Who can access |
|-------|----------------|
| `profiles` | Own row only |
| `contact_requests` | Participant (sender/receiver) |
| `contacts` | Own rows only |
| `safe_zones`, `curfew_schedules` | Own rows only |
| `incidents` | Subject or contacts in `incident_access` |
| `incident_access`, `incident_location_history` | Subject or contact for that incident |
| `user_location_samples` | Own rows only |
| `always_share_locations` | Update own row; read only where sharer has you in always-share |

### 7.2 Data Minimization

- Location history: 12 hours rolling.
- Incident location: Copy of 12h at creation; no ongoing upload after resolution.
- Always-share: One row per user; overwritten every 45s.

---

## 8. Limitations and Considerations

- **No push for incidents**: Contacts are notified via local notifications when the app is running (foreground/background) or via missed-check on resume. No FCM; delivery depends on the app being opened or Workmanager running.
- **Battery**: Background location and periodic checks consume battery; the app requests background only after explaining why.
- **Cron dependency**: `expire-pending-safety-checks` must run every 1–2 minutes (pg_cron or external) for curfew timeout and time-based escalation.
- **Map key**: Requires Google Maps API key for map features.
- **Escalation order**: The current escalate function adds contacts by layer but does not yet implement closest-first sorting using `always_share_locations`; that logic is documented for future enhancement.

---

## 9. Getting Started (User Flow)

1. **Sign up / Log in** (email/password).
2. **Allow location** (foreground, then background with explanation).
3. **Add safe zones** (e.g., Home, Office) — center + radius.
4. **Add curfew** (optional) — start/end time, timezone, safe zones, timeout.
5. **Add contacts** — search, send request; accept incoming.
6. **Configure layers** — assign each contact to Layer 1, 2, or 3.
7. **Enable "Always share"** (optional) — for contacts who should see your live location.
8. **Run manual check** (optional) — bell icon on Safety screen.

When an incident occurs, contacts see it in the app and can view the map, confirm safety, or escalate.

---

## 10. Technical References

- [Technical Spec](TECHNICAL_SPEC.md) — privacy, location pipeline, curfew, escalation, maps, split-up.
- [Schema and RLS](SCHEMA.md) — Postgres tables and security policies.
- [Supabase Setup](SUPABASE_SETUP.md) — migrations, Edge Functions, cron, auth redirect.
