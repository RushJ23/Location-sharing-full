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

  RealtimeChannel? _channel;
  String? _userId;
  bool _channelCreated = false;

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

    final client = Supabase.instance.client;
    _channel = client
        .channel('incident_access_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'incident_access',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'contact_user_id',
            value: userId,
          ),
          callback: _onInsert,
        )
        .subscribe();
  }

  Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
    _userId = null;
  }

  Future<void> _onInsert(PostgresChangePayload payload) async {
    final newRecord = payload.newRecord;
    if (newRecord == null) return;

    final rawId = newRecord['incident_id'];
    final incidentId = rawId is String ? rawId : rawId?.toString();
    if (incidentId == null || incidentId.isEmpty) return;

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
    await notificationPlugin.show(
      incidentEmergencyNotificationId,
      title,
      body,
      details,
      payload: incidentId,
    );
  }

  /// Create and show the notification (for external use, e.g. FCM payload).
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
