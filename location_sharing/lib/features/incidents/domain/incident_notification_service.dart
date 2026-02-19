import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification ID for "Contact has emergency" - must not conflict with safety check (1).
const int incidentEmergencyNotificationId = 100;
const String incidentEmergencyChannelId = 'incident_emergency';

/// Listens to Supabase Realtime for new incident_access rows where current user
/// is the contact, and shows a local notification. Tap navigates to incident page.
class IncidentNotificationService {
  IncidentNotificationService({
    required this.notificationPlugin,
    required this.getSubjectDisplayName,
  });

  final FlutterLocalNotificationsPlugin notificationPlugin;
  final Future<String> Function(String userId) getSubjectDisplayName;
  /// Called when a new incident notification is shown (Realtime or missed check). Set from app to refresh UI.
  void Function()? onIncidentShown;

  RealtimeChannel? _channel;
  String? _userId;
  bool _channelCreated = false;
  final Set<String> _notifiedIncidentIds = {};

  Future<void> _ensureChannel() async {
    if (_channelCreated) return;
    const channel = AndroidNotificationChannel(
      incidentEmergencyChannelId,
      'Contact emergencies',
      description: 'When a contact has an emergency',
      importance: Importance.max,
    );
    await notificationPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _channelCreated = true;
  }

  Future<void> start(String userId) async {
    if (_userId == userId && _channel != null) return;
    await stop();
    _userId = userId;

    // Subscribe without filter: Realtime filters on UUID can fail silently.
    // RLS ensures we only receive rows where contact_user_id = auth.uid();
    // we also filter in _onInsert for contact_user_id == userId.
    final client = Supabase.instance.client;
    _channel = client
        .channel('incident_access_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'incident_access',
          callback: (payload) => _onInsert(payload, userId),
        )
        .subscribe();

    // Catch any incident_access rows we missed (e.g. app was closed).
    unawaited(checkForMissedNotifications());
  }

  Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
    _userId = null;
    _notifiedIncidentIds.clear();
  }

  /// Call on app resume to catch incident_access rows we may have missed
  /// (e.g. Realtime disconnected, app was backgrounded).
  Future<void> checkForMissedNotifications() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('incident_access')
          .select('incident_id')
          .eq('contact_user_id', userId)
          .gte('notified_at', DateTime.now()
              .subtract(const Duration(hours: 1))
              .toUtc()
              .toIso8601String());

      final rows = res as List<dynamic>? ?? [];
      for (final row in rows) {
        final incidentId = (row as Map<String, dynamic>)['incident_id']?.toString();
        if (incidentId != null &&
            incidentId.isNotEmpty &&
            !_notifiedIncidentIds.contains(incidentId)) {
          await _showNotificationForIncident(incidentId);
        }
      }
    } catch (_) {
      // Ignore; will retry on next resume
    }
  }

  Future<void> _onInsert(PostgresChangePayload payload, String userId) async {
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    // RLS should limit to our rows, but double-check contact_user_id
    final rawContactId = newRecord['contact_user_id'];
    final contactId = rawContactId is String ? rawContactId : rawContactId?.toString();
    if (contactId != userId) return;

    final rawId = newRecord['incident_id'];
    final incidentId = rawId is String ? rawId : rawId?.toString();
    if (incidentId == null || incidentId.isEmpty) return;

    await _showNotificationForIncident(incidentId);
  }

  Future<void> _showNotificationForIncident(String incidentId) async {
    if (_notifiedIncidentIds.contains(incidentId)) return;
    _notifiedIncidentIds.add(incidentId);
    onIncidentShown?.call();

    // Fetch subject's user_id from incident
    final incidentRes = await Supabase.instance.client
        .from('incidents')
        .select('user_id')
        .eq('id', incidentId)
        .maybeSingle();

    final subjectUserId = incidentRes?['user_id'] as String?;
    if (subjectUserId == null) return;

    final displayName = await getSubjectDisplayName(subjectUserId);
    final title = 'Emergency: $displayName needs help';
    const body = 'Tap to view their location and help.';

    await _ensureChannel();
    const androidDetails = AndroidNotificationDetails(
      incidentEmergencyChannelId,
      'Contact emergencies',
      channelDescription: 'When a contact has an emergency',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    // Use unique ID per incident so multiple notifications don't overwrite each other
    final notificationId = incidentEmergencyNotificationId +
        (incidentId.hashCode & 0x7FFF).clamp(0, 32767);
    await notificationPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: incidentId,
    );
  }

  /// Static helper for external use (e.g. FCM payload).
  static Future<void> showIncidentEmergencyNotification(
    FlutterLocalNotificationsPlugin plugin, {
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      incidentEmergencyChannelId,
      'Contact emergencies',
      channelDescription: 'When a contact has an emergency',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await plugin.show(
      incidentEmergencyNotificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
