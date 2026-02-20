import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/incidents/domain/incident_notification_service.dart';

/// Keys for persisted data used by the background task (main app writes, task reads).
const String _keySupabaseUrl = 'incident_background_supabase_url';
const String _keyAnonKey = 'incident_background_anon_key';
const String _keyUserId = 'incident_background_user_id';
const String _keyAccessToken = 'incident_background_access_token';
const String _keyNotifiedIds = 'incident_background_notified_ids';

/// Unique task name for Workmanager (used as uniqueName for register/cancel).
const String incidentCheckTaskName = 'incidentNotificationCheck';
/// Unique name for one-off task when app goes to background (same task logic).
const String incidentCheckOneOffTaskName = 'incidentNotificationCheckOneOff';

/// Persist session so the background task can call Supabase. Call from main app on login.
Future<void> persistIncidentBackgroundSession({
  required String supabaseUrl,
  required String anonKey,
  required String userId,
  required String accessToken,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keySupabaseUrl, supabaseUrl);
  await prefs.setString(_keyAnonKey, anonKey);
  await prefs.setString(_keyUserId, userId);
  await prefs.setString(_keyAccessToken, accessToken);
}

/// Clear persisted session and cancel the periodic task. Call from main app on logout.
Future<void> clearIncidentBackgroundSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keySupabaseUrl);
  await prefs.remove(_keyAnonKey);
  await prefs.remove(_keyUserId);
  await prefs.remove(_keyAccessToken);
  await prefs.remove(_keyNotifiedIds);
  try {
    await Workmanager().cancelByUniqueName(incidentCheckTaskName);
  } on PlatformException catch (_) {
    // Workmanager only supports Android/iOS.
  }
}

/// Callback entry point for Workmanager. Must be top-level and have @pragma.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != incidentCheckTaskName) return false;
    return _runIncidentCheck();
  });
}

/// Runs in the background isolate: read session, fetch incident_access, show local notifications.
Future<bool> _runIncidentCheck() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final supabaseUrl = prefs.getString(_keySupabaseUrl);
    final anonKey = prefs.getString(_keyAnonKey);
    final userId = prefs.getString(_keyUserId);
    final accessToken = prefs.getString(_keyAccessToken);

    if (supabaseUrl == null ||
        supabaseUrl.isEmpty ||
        anonKey == null ||
        userId == null ||
        accessToken == null) {
      return true;
    }

    final since = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
    final sinceIso = since.toIso8601String();
    final path =
        '/rest/v1/incident_access?contact_user_id=eq.$userId&notified_at=gte.$sinceIso&select=incident_id';
    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    final uri = Uri.parse('$base$path');

    final response = await http.get(
      uri,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
    );

    if (response.statusCode != 200) return true;

    List<dynamic> rows = [];
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) rows = decoded;
    } catch (_) {
      return true;
    }

    final notifiedList = prefs.getStringList(_keyNotifiedIds) ?? [];
    final notifiedSet = notifiedList.toSet();
    final toNotify = <String>[];
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        final id = row['incident_id']?.toString();
        if (id != null && id.isNotEmpty && !notifiedSet.contains(id)) {
          toNotify.add(id);
        }
      }
    }

    if (toNotify.isEmpty) return true;

    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
    );
    await plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    const channel = AndroidNotificationChannel(
      incidentEmergencyChannelId,
      'Contact emergencies',
      description: 'When a contact has an emergency',
      importance: Importance.max,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

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

    final title = 'Emergency: A contact needs help';
    const body = 'Tap to view their location and help.';

    for (final incidentId in toNotify) {
      final notificationId = incidentEmergencyNotificationId +
          (incidentId.hashCode & 0x7FFF).clamp(0, 32767);
      await plugin.show(
        notificationId,
        title,
        body,
        details,
        payload: incidentId,
      );
      notifiedSet.add(incidentId);
    }

    final list = notifiedSet.toList();
    if (list.length > 200) {
      await prefs.setStringList(_keyNotifiedIds, list.sublist(list.length - 200));
    } else {
      await prefs.setStringList(_keyNotifiedIds, list);
    }
    return true;
  } catch (_) {
    return true;
  }
}

