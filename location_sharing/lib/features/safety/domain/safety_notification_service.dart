import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Ids for "Are you safe?" notification and actions.
const int safetyCheckNotificationId = 1;
const String safetyCheckChannelId = 'safety_check';
const String actionSafe = 'safe';
const String actionNeedHelp = 'need_help';

/// Shows "Are you safe?" notification with YES and I NEED HELP actions.
/// Call [initialize] once from main before showing.
class SafetyNotificationService {
  SafetyNotificationService() {
    _plugin = FlutterLocalNotificationsPlugin();
  }

  late final FlutterLocalNotificationsPlugin _plugin;

  /// Callback when user taps "I'm safe". Argument: notification id.
  void Function(int)? onSafePressed;

  /// Callback when user taps "I need help". Argument: notification id.
  void Function(int)? onNeedHelpPressed;

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
    if (action == actionSafe) {
      onSafePressed?.call(id);
    } else if (action == actionNeedHelp) {
      onNeedHelpPressed?.call(id);
    }
  }

  Future<void> showSafetyCheckNotification() async {
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
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      safetyCheckNotificationId,
      'Are you safe?',
      'Please confirm you\'re safe or request help.',
      details,
    );
  }

  Future<void> cancelSafetyCheck() async {
    await _plugin.cancel(safetyCheckNotificationId);
  }
}
