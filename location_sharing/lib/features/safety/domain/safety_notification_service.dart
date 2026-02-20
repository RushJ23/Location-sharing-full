import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../incidents/domain/incident_notification_service.dart';

/// Ids for "Are you safe?" notification and actions.
const int safetyCheckNotificationId = 1;
const String safetyCheckChannelId = 'safety_check';
const String actionSafe = 'safe';
const String actionNeedHelp = 'need_help';

/// Ids for split-up "You are no longer with [name]" notification.
const String splitUpChannelId = 'split_up';
const int splitUpNotificationId = 2;

/// Id for "Incident created" confirmation (creator's device).
const String incidentCreatedChannelId = 'incident_created';
const int incidentCreatedNotificationId = 3;

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
    await _requestNotificationPermission();
  }

  /// Request notification permission so incident and safety notifications can be shown.
  Future<void> _requestNotificationPermission() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    }
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

  bool _incidentCreatedChannelCreated = false;

  Future<void> _ensureIncidentCreatedChannel() async {
    if (_incidentCreatedChannelCreated) return;
    const channel = AndroidNotificationChannel(
      incidentCreatedChannelId,
      'Incident updates',
      description: 'When you create or are notified about an incident',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _incidentCreatedChannelCreated = true;
  }

  /// Shows a local notification on the creator's device after they create an incident
  /// (same process as curfew: flutter_local_notifications, no Firebase).
  Future<void> showIncidentCreatedConfirmation() async {
    await _ensureIncidentCreatedChannel();
    const androidDetails = AndroidNotificationDetails(
      incidentCreatedChannelId,
      'Incident updates',
      channelDescription: 'When you create or are notified about an incident',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      incidentCreatedNotificationId,
      'Incident created',
      'Your contacts have been notified.',
      details,
    );
  }

  bool _splitUpChannelCreated = false;

  Future<void> _ensureSplitUpChannel() async {
    if (_splitUpChannelCreated) return;
    const channel = AndroidNotificationChannel(
      splitUpChannelId,
      'Split-up alerts',
      description: 'When you are no longer near someone who shares location with you',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _splitUpChannelCreated = true;
  }

  /// Shows a local notification when the user has moved beyond 50m of a contact
  /// who was sharing location (e.g. app in background). No tap callback required.
  Future<void> showSplitUpNotification(String displayName) async {
    await _ensureSplitUpChannel();
    const androidDetails = AndroidNotificationDetails(
      splitUpChannelId,
      'Split-up alerts',
      channelDescription: 'When you are no longer near someone who shares location with you',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      splitUpNotificationId,
      'You are no longer with $displayName',
      '',
      details,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final action = response.actionId;
    final id = response.id;
    if (id == null) return;
    final payload = response.payload;
    // Incident emergency notifications use id 100–32867 (incidentEmergencyNotificationId + hash)
    if (id >= incidentEmergencyNotificationId && id < incidentEmergencyNotificationId + 32768) {
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
