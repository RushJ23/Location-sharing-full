import 'package:timezone/timezone.dart' as tz;

import '../../../data/repositories/curfew_repository.dart';
import '../../../data/repositories/pending_safety_check_repository.dart';
import 'curfew_schedule.dart';
import 'safety_notification_service.dart';

/// Stable notification id for a schedule (2–100 to avoid clashing with id 1).
int notificationIdForSchedule(String scheduleId) {
  return 2 + (scheduleId.hashCode.abs() % 99);
}

/// Schedules curfew "Are you safe?" notifications at start time and handles
/// 10-minute rechecks when user taps "I'm safe" until end time.
class CurfewScheduler {
  CurfewScheduler({
    required SafetyNotificationService notificationService,
    required CurfewRepository curfewRepository,
    PendingSafetyCheckRepository? pendingCheckRepository,
  })  : _notificationService = notificationService,
        _curfewRepository = curfewRepository,
        _pendingCheckRepository = pendingCheckRepository;

  final SafetyNotificationService _notificationService;
  final CurfewRepository _curfewRepository;
  final PendingSafetyCheckRepository? _pendingCheckRepository;

  static const int recheckMinutes = 10;

  /// Schedules the next start-time notification for each enabled curfew of [userId].
  /// Also registers pending safety check with server for background timeout.
  Future<void> rescheduleAllForUser(String userId) async {
    final schedules = await _curfewRepository.getCurfewSchedules(userId);
    for (final schedule in schedules) {
      await cancelForSchedule(schedule.id);
      if (!schedule.enabled || schedule.safeZoneIds.isEmpty) continue;
      final scheduledDate = _nextStartInTimezone(schedule);
      if (scheduledDate == null) continue;
      await _notificationService.scheduleCurfewNotification(
        id: notificationIdForSchedule(schedule.id),
        scheduledDate: scheduledDate,
        payload: schedule.id,
      );
      final timeoutMin = schedule.responseTimeoutMinutes;
      final expiresAt = scheduledDate.add(Duration(minutes: timeoutMin));
      await _pendingCheckRepository?.register(
        scheduleId: schedule.id,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt.millisecondsSinceEpoch),
      );
    }
  }

  /// Cancels the scheduled notification for this schedule.
  Future<void> cancelForSchedule(String scheduleId) async {
    await _notificationService.cancelCurfewNotification(
      notificationIdForSchedule(scheduleId),
    );
  }

  /// When user taps "I'm safe" from a curfew notification, schedule the next
  /// check in 10 minutes unless we're past end time.
  /// Also registers pending safety check for background timeout.
  Future<void> scheduleRecheckIn10Min(String userId, String scheduleId) async {
    final schedules = await _curfewRepository.getCurfewSchedules(userId);
    CurfewSchedule? schedule;
    for (final s in schedules) {
      if (s.id == scheduleId) {
        schedule = s;
        break;
      }
    }
    if (schedule == null) return;
    final location = _locationForTimezone(schedule.timezone);
    final now = tz.TZDateTime.now(location);
    if (!_isWithinCurfewWindow(now, schedule)) return;
    final in10 = now.add(const Duration(minutes: recheckMinutes));
    if (!_isWithinCurfewWindow(in10, schedule)) return;
    await _notificationService.scheduleCurfewNotification(
      id: notificationIdForSchedule(schedule.id),
      scheduledDate: in10,
      payload: schedule.id,
    );
    final timeoutMin = schedule.responseTimeoutMinutes;
    final expiresAt = in10.add(Duration(minutes: timeoutMin));
    await _pendingCheckRepository?.register(
      scheduleId: schedule.id,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt.millisecondsSinceEpoch),
    );
  }

  /// Returns the next occurrence of start_time in the schedule's timezone.
  tz.TZDateTime? _nextStartInTimezone(CurfewSchedule schedule) {
    final location = _locationForTimezone(schedule.timezone);
    final now = tz.TZDateTime.now(location);
    final start = _parseTimeOfDay(schedule.startTime);
    if (start == null) return null;
    var next = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      start.$1,
      start.$2,
    );
    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  bool _isWithinCurfewWindow(tz.TZDateTime instant, CurfewSchedule schedule) {
    final start = _parseTimeOfDay(schedule.startTime);
    final end = _parseTimeOfDay(schedule.endTime);
    if (start == null || end == null) return false;
    final location = _locationForTimezone(schedule.timezone);
    final day = tz.TZDateTime(location, instant.year, instant.month, instant.day, 0, 0);
    final startToday = day.add(Duration(hours: start.$1, minutes: start.$2));
    final endToday = day.add(Duration(hours: end.$1, minutes: end.$2));
    final isOvernight = end.$1 < start.$1 || (end.$1 == start.$1 && end.$2 <= start.$2);
    if (!isOvernight) {
      return !instant.isBefore(startToday) && instant.isBefore(endToday);
    }
    final startYesterday = startToday.subtract(const Duration(days: 1));
    final endTomorrow = day.add(const Duration(days: 1)).add(Duration(hours: end.$1, minutes: end.$2));
    final inLatePart = !instant.isBefore(startToday) && instant.isBefore(endTomorrow);
    final inEarlyPart = !instant.isBefore(startYesterday) && instant.isBefore(endToday);
    return inLatePart || inEarlyPart;
  }

  /// (hour, minute) or null
  (int, int)? _parseTimeOfDay(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1].length >= 2 ? parts[1].substring(0, 2) : parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  tz.Location _locationForTimezone(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.local;
    }
  }
}
