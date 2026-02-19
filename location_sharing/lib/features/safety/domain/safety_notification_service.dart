import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Ids for "Are you safe?" notification and actions.
const int safetyCheckNotificationId = 1;
const String safetyCheckChannelId = 'safety_check';
const String actionSafe = 'safe';
const String actionNeedHelp = 'need_help';

/// Notification details used for both immediate and scheduled curfew notifications.
NotificationDetails get _safetyCheckNotificationDetails {
  const androidDetails = AndroidNotificationDetails(
    safetyCheckChannelId,
    'Safety check',
    channelDescription: 'Curfew and safety check alerts',
    importance: Importance.max,
    priority: Priority.high,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(actionSafe, 'I\'m safe', showsUserInterface: true),
      AndroidNotificationAction(actionNeedHelp, 'I need help', showsUserInterface: true),
    ],
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    categoryIdentifier: 'safety_check',
  );
  return const NotificationDetails(android: androidDetails, iOS: iosDetails);
}

/// Shows "Are you safe?" notification with YES and I NEED HELP actions.
/// Call [initialize] once from main before showing.
class SafetyNotificationService {
  SafetyNotificationService() {
    _plugin = FlutterLocalNotificationsPlugin();
  }

  late final FlutterLocalNotificationsPlugin _plugin;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Callback when user taps "I'm safe". Arguments: notification id, optional payload (e.g. schedule id).
  void Function(int, String?)? onSafePressed;

  /// Callback when user taps "I need help". Arguments: notification id, optional payload.
  void Function(int, String?)? onNeedHelpPressed;

  /// Callback when user taps the notification body (opens app without choosing an action).
  /// Use this to show the in-app safety dialog. Arguments: notification id, optional payload.
  void Function(int, String?)? onNotificationOpened;

  /// Callback when user taps an incident emergency notification (id 100).
  /// Payload is the incident ID for navigation.
  void Function(String incidentId)? onIncidentNotificationOpened;

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _createChannel();
  }

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      safetyCheckChannelId,
      'Safety check',
      description: 'Curfew and safety check alerts',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationResponse(NotificationResponse response) {
    final action = response.actionId;
    final id = response.id;
    if (id == null) return;
    final payload = response.payload;
    // Incident emergency notifications use id 100 (see incident_notification_service.dart)
    if (id == 100) {
      if (payload != null && payload.isNotEmpty) {
        onIncidentNotificationOpened?.call(payload);
      }
      return;
    }
    if (action == actionSafe) {
      onSafePressed?.call(id, payload);
    } else if (action == actionNeedHelp) {
      onNeedHelpPressed?.call(id, payload);
    } else {
      onNotificationOpened?.call(id, payload);
    }
  }

  Future<void> showSafetyCheckNotification() async {
    await _plugin.show(
      safetyCheckNotificationId,
      'Are you safe?',
      'Please confirm you\'re safe or request help.',
      _safetyCheckNotificationDetails,
    );
  }

  Future<void> cancelSafetyCheck() async {
    await _plugin.cancel(safetyCheckNotificationId);
  }

  /// Schedules a curfew "Are you safe?" notification at [scheduledDate].
  /// [id] must be unique per schedule (e.g. 2 + scheduleIndex or hash).
  /// [payload] is passed back when user taps (e.g. schedule id for recheck).
  Future<void> scheduleCurfewNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      'Are you safe?',
      'Please confirm you\'re safe or request help.',
      scheduledDate,
      _safetyCheckNotificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels a scheduled curfew notification (e.g. when schedule is deleted).
  Future<void> cancelCurfewNotification(int id) async {
    await _plugin.cancel(id);
  }
}
