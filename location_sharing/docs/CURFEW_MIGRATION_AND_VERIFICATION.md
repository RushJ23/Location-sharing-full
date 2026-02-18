# Curfew start/end migration and notification verification

## Apply the migration

**No Supabase MCP is available in this environment.** Apply the migration in one of these ways:

### Option A: Supabase Dashboard (recommended)

1. Open your [Supabase project](https://supabase.com/dashboard) → **SQL Editor**.
2. Paste and run the contents of:
   `supabase/migrations/20250218000000_curfew_start_end_time.sql`
3. Confirm the migration runs without errors.

### Option B: Supabase CLI

1. Link the project (if not already):
   ```bash
   cd location_sharing && npx supabase link --project-ref YOUR_PROJECT_REF
   ```
2. Push migrations:
   ```bash
   npx supabase db push
   ```

After applying, `curfew_schedules` will have `start_time` and `end_time` (and no longer `time_local`).

---

## Verify the notification system

### 1. Unit tests (already run)

- `flutter test test/curfew_check_test.dart test/geofence_test.dart` — **passed** (curfew safe-zone and geofence logic).

### 2. In-app verification checklist

| Step | What to do | Expected |
|------|-------------|----------|
| **Login** | Sign in and open the app. | On auth, `CurfewScheduler.rescheduleAllForUser(userId)` runs and schedules notifications for each enabled curfew at its next **start** time. |
| **Add/Edit curfew** | Safety → add or edit a curfew (start time, end time, zones). Save. | Scheduler reschedules; next start-time notification is set. |
| **Delete curfew** | Safety → delete a curfew. | That schedule’s pending notification is cancelled. |
| **At start time** | Wait until a curfew’s start time (or set one ~1 min ahead for testing). Don’t open the app. | OS shows “Are you safe?” with “I’m safe” / “I need help” (scheduled via `scheduleCurfewNotification`). |
| **Tap “I’m safe”** | When the notification appears, tap “I’m safe”. | Notification dismisses; if still before **end time**, another “Are you safe?” is scheduled in **10 minutes** (`scheduleRecheckIn10Min`). |
| **After end time** | Tap “I’m safe” when the recheck fires, or wait past end time. | No further notification for that curfew until the next day’s start time. |
| **Manual trigger** | Safety screen → tap “Run curfew check now”. | Immediate “Are you safe?” (same as before); if you’re not in a safe zone, notification shows. |
| **I need help** | Tap “I need help” on any “Are you safe?” notification. | App opens create-incident flow (`/incidents/create?trigger=need_help`). |

### 3. Code paths (for reference)

- **Start-time trigger**: `CurfewScheduler.rescheduleAllForUser` → `_nextStartInTimezone` → `SafetyNotificationService.scheduleCurfewNotification` (zonedSchedule).
- **Recheck in 10 min**: `main` `onSafePressed(id, payload)` → `curfewScheduler.scheduleRecheckIn10Min(userId, payload)` → same `scheduleCurfewNotification` with `now + 10 min` if still in window and before end time.
- **End time**: `_isWithinCurfewWindow` in the scheduler (including overnight windows) decides whether to schedule the next recheck.

If any step in the checklist fails, check device notification permissions, timezone init (`tz_data.initializeTimeZones()` in `main`), and that the app has been restarted after the migration so it uses `start_time`/`end_time`.
