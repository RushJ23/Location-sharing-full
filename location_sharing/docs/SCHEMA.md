# Database Schema and RLS (Supabase / Postgres)

## Tables

### profiles
One-to-one with `auth.users`. Extended user info and FCM for push.

| Column        | Type      | Notes                          |
|---------------|-----------|--------------------------------|
| id            | uuid PK   | FK to auth.users(id)           |
| display_name  | text      |                                |
| avatar_url    | text      | optional                       |
| phone         | text      | optional                       |
| school        | text      | optional                       |
| fcm_token     | text      | for push notifications         |
| created_at    | timestamptz | default now()                |
| updated_at    | timestamptz | default now()                |

**RLS**: Users can SELECT/UPDATE only their own row (where id = auth.uid()). INSERT via trigger on auth.users or on first login.

---

### contact_requests
Request/accept/decline flow. Mutual consent required.

| Column        | Type      | Notes                          |
|---------------|-----------|--------------------------------|
| id            | uuid PK   | default gen_random_uuid()       |
| from_user_id  | uuid FK   | references auth.users          |
| to_user_id    | uuid FK   | references auth.users          |
| status        | text      | 'pending' \| 'accepted' \| 'declined' |
| created_at    | timestamptz | default now()                |
| updated_at    | timestamptz | default now()                |

Unique (from_user_id, to_user_id) to avoid duplicate requests.

**RLS**: Users can read rows where they are from_user_id or to_user_id. Only from_user_id can INSERT (for their own request). Only to_user_id can UPDATE status to accepted/declined.

---

### contacts
Mutual relationship; each user has their own row per contact. Layers and always-share.

| Column          | Type      | Notes                          |
|-----------------|-----------|--------------------------------|
| id              | uuid PK   | default gen_random_uuid()       |
| user_id         | uuid FK   | owner of this contact row      |
| contact_user_id | uuid FK   | the other user                 |
| layer           | int       | 1, 2, or 3                     |
| is_always_share | boolean   | default false                  |
| manual_priority | int       | nullable; order within layer   |
| created_at      | timestamptz | default now()                |

Unique (user_id, contact_user_id). Both sides create a row after accept.

**RLS**: Users can CRUD only rows where user_id = auth.uid().

---

### safe_zones
User-defined circular geofences.

| Column         | Type      | Notes                          |
|----------------|-----------|--------------------------------|
| id             | uuid PK   | default gen_random_uuid()       |
| user_id        | uuid FK   | owner                          |
| name           | text      |                                |
| center_lat     | double precision |                    |
| center_lng     | double precision |                    |
| radius_meters  | double precision |                    |
| created_at     | timestamptz | default now()                |

**RLS**: Users can CRUD only rows where user_id = auth.uid().

---

### curfew_schedules
When to run safety check and which safe zones apply. Each row defines a window [start_time, end_time] in the given timezone; the user is prompted at start time and every 10 min on "I'm safe" until in a safe zone or end time.

| Column                    | Type      | Notes                          |
|---------------------------|-----------|--------------------------------|
| id                        | uuid PK   | default gen_random_uuid()       |
| user_id                   | uuid FK   | owner                          |
| safe_zone_ids             | uuid[]    | list of safe_zone id           |
| start_time                | time      | e.g. 22:00 — be in safe zone by |
| end_time                  | time      | e.g. 06:00 — stop checking after (can be next day) |
| timezone                  | text      | IANA, e.g. America/New_York     |
| enabled                   | boolean   | default true                   |
| response_timeout_minutes  | int       | default 10                     |
| created_at                | timestamptz | default now()                |
| updated_at                | timestamptz | default now()                |

**RLS**: Users can CRUD only rows where user_id = auth.uid().

---

### incidents
One row per emergency incident (subject = user whose safety is in question).

| Column          | Type      | Notes                          |
|-----------------|-----------|--------------------------------|
| id              | uuid PK   | default gen_random_uuid()       |
| user_id         | uuid FK   | subject                        |
| status          | text      | 'active' \| 'resolved'         |
| trigger         | text      | 'curfew_timeout' \| 'need_help' \| 'manual' |
| last_known_lat  | double precision |                    |
| last_known_lng  | double precision |                    |
| subject_current_lat | double precision | live tracking during incident |
| subject_current_lng | double precision | live tracking during incident |
| subject_location_updated_at | timestamptz | nullable |
| created_at      | timestamptz | default now()                |
| resolved_at     | timestamptz | nullable                     |
| resolved_by     | uuid FK   | nullable; user who resolved    |

**RLS**: User can read/update if they are the subject (user_id = auth.uid()) or if they appear in incident_access for this incident. No direct INSERT from client for status/trigger—use Edge Function or service role for creation and access grants.

---

### user_location_samples
Rolling 12h location history per user, uploaded continuously by the app.

| Column     | Type      | Notes                          |
|------------|-----------|--------------------------------|
| id         | uuid PK   | default gen_random_uuid()       |
| user_id    | uuid FK   | owner                          |
| lat        | double precision |                    |
| lng        | double precision |                    |
| timestamp  | timestamptz | when point was recorded      |

Unique (user_id, timestamp). Index on (user_id, timestamp).

**RLS**: Users can INSERT/UPDATE/DELETE/SELECT only their own rows.

---

### pending_safety_checks
Server-side safety check timeout. When `expires_at` passes and `responded_at` is NULL, the `expire-pending-safety-checks` Edge Function creates an incident.

| Column       | Type      | Notes                          |
|--------------|-----------|--------------------------------|
| id           | uuid PK   | default gen_random_uuid()       |
| user_id      | uuid FK   | subject                        |
| schedule_id  | uuid FK   | nullable; curfew_schedules     |
| expires_at   | timestamptz | when check expires           |
| responded_at | timestamptz | nullable; set when user responds |

**RLS**: Users can INSERT/UPDATE/SELECT only their own rows.

**RPCs**:
- `register_pending_safety_check(p_schedule_id, p_expires_at)` — registers a pending check; called when curfew notification is scheduled or manual check is shown.
- `respond_to_safety_check(p_schedule_id)` — marks pending check(s) as responded; called when user taps "I'm safe" or "I need help".

---

### incident_access
Which contacts were notified and their response. Drives escalation and RLS.

**Realtime**: This table is in the `supabase_realtime` publication. The app subscribes to INSERT events to show local notifications to emergency contacts when they are added. `REPLICA IDENTITY FULL` is set so Realtime broadcasts full row data.

| Column            | Type      | Notes                          |
|-------------------|-----------|--------------------------------|
| id                | uuid PK   | default gen_random_uuid()       |
| incident_id        | uuid FK   | references incidents            |
| contact_user_id   | uuid FK   | the contact                    |
| layer             | int       | 1, 2, or 3                     |
| notified_at       | timestamptz | nullable                     |
| confirmed_safe_at | timestamptz | nullable                     |
| could_not_reach_at| timestamptz | nullable                     |

Unique (incident_id, contact_user_id).

**RLS**: User can read rows where they are the incident subject or contact_user_id. Inserts/updates only via Edge Function or service role when running escalation.

---

### incident_location_history
Last 12h path for the incident. Only populated after incident creation.

| Column     | Type      | Notes                          |
|------------|-----------|--------------------------------|
| id         | uuid PK   | default gen_random_uuid()       |
| incident_id | uuid FK   | references incidents            |
| lat        | double precision |                    |
| lng        | double precision |                    |
| timestamp  | timestamptz | when the point was recorded  |

**RLS**: Same as incidents—only subject or contacts in incident_access for this incident can read. Insert only by backend/Edge Function when incident is created (or by authenticated client with check that incident belongs to user and is being created).

---

### always_share_locations
Live-ish position for users who have "always share" on. Updated by app periodically.

| Column     | Type      | Notes                          |
|------------|-----------|--------------------------------|
| user_id    | uuid PK   | subject (one row per user)     |
| lat        | double precision |                    |
| lng        | double precision |                    |
| updated_at | timestamptz | default now()                |

**RLS**: User can UPDATE their own row (when they share). User can SELECT only rows where the location owner (user_id) has the current user in their contacts with is_always_share = true. So: "I can see B's location only if B has me as an always-share contact (B shares with me)."

---

### layer_policies (optional)
Per-layer visibility: precise vs coarse, history length. Can be user-scoped later.

| Column        | Type      | Notes                          |
|---------------|-----------|--------------------------------|
| id            | uuid PK   | default gen_random_uuid()       |
| user_id       | uuid FK   | owner                          |
| layer         | int       | 1, 2, or 3                     |
| precision     | text      | 'precise' \| 'coarse'           |
| history_hours | int       | default 12 for layer 1, 6 for 2/3 |

**RLS**: Users can CRUD only their own rows.

---

## Row Level Security (summary)

1. **profiles**: Own row only (id = auth.uid()).
2. **contact_requests**: Participant only; insert as sender, update status as receiver.
3. **contacts**: Own rows only (user_id = auth.uid()).
4. **safe_zones**, **curfew_schedules**, **layer_policies**: Own rows only (user_id = auth.uid()).
5. **incidents**: Read/update if subject or in incident_access; create via function or with policy that allows insert when user_id = auth.uid() and status = 'active'.
6. **incident_access**, **incident_location_history**: Read if subject or contact for that incident; write via Edge Function or constrained policy.
7. **always_share_locations**: Update own row; read only rows where the sharer (user_id) has me in their contacts with is_always_share = true.

Implement these as named policies in Supabase (e.g. `CREATE POLICY ... ON table_name FOR SELECT USING (...)`). Use service role in Edge Functions for escalation and incident creation.
