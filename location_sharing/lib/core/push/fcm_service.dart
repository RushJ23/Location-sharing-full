import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import '../../data/repositories/profile_repository.dart';

/// Registers for FCM and saves token to Supabase profiles. Call after login.
/// Skip if Firebase is not initialized (run `flutterfire configure` for FCM).
Future<void> registerFcmAndSaveToken(String userId) async {
  if (AppEnv.supabaseUrl.isEmpty || Firebase.apps.isEmpty) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ProfileRepository().updateProfile(userId: userId, fcmToken: token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await ProfileRepository().updateProfile(userId: userId, fcmToken: newToken);
    });
  } catch (e) {
    debugPrint('FCM registration failed: $e');
  }
}

/// Call from main: handle tap on notification (e.g. navigate to incident).
void setupFcmHandlers(void Function(String?) onNotificationTap) {
  if (Firebase.apps.isEmpty) return;
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = message.data;
    final incidentId = data['incident_id'];
    if (incidentId != null) onNotificationTap(incidentId);
  });
}
