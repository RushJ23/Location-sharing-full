import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_refresh.dart';
import 'core/config/app_env.dart';
import 'core/push/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/safety/domain/safety_notification_service.dart';
import 'features/safety/providers/location_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppEnv.supabaseUrl.isNotEmpty && AppEnv.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
  }
  final safetyNotifications = SafetyNotificationService();
  await safetyNotifications.initialize();
  final authRefresh = AuthRefreshNotifier();
  final router = createAppRouter(authRefresh);
  safetyNotifications.onNeedHelpPressed = (_) {
    router.go('/incidents/create?trigger=need_help');
  };
  safetyNotifications.onSafePressed = (_) {
    safetyNotifications.cancelSafetyCheck();
  };
  setupFcmHandlers((incidentId) {
    if (incidentId != null) router.go('/incidents/$incidentId');
  });
  if (AppEnv.supabaseUrl.isNotEmpty) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) registerFcmAndSaveToken(session.user.id);
  }
  runApp(
    ProviderScope(
      overrides: [
        safetyNotificationServiceProvider.overrideWithValue(safetyNotifications),
      ],
      child: LocationSharingApp(
        router: router,
        authRefresh: authRefresh,
      ),
    ),
  );
}

class LocationSharingApp extends StatefulWidget {
  const LocationSharingApp({
    super.key,
    required this.router,
    required this.authRefresh,
  });

  final GoRouter router;
  final AuthRefreshNotifier authRefresh;

  @override
  State<LocationSharingApp> createState() => _LocationSharingAppState();
}

class _LocationSharingAppState extends State<LocationSharingApp> {
  void _onAuthChange(dynamic state) {
    widget.authRefresh.refresh();
    final session = (state as dynamic).session;
    if (session != null) {
      registerFcmAndSaveToken((session.user as dynamic).id as String);
    }
  }

  @override
  void initState() {
    super.initState();
    if (AppEnv.supabaseUrl.isNotEmpty) {
      Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Location Sharing',
      theme: appTheme,
      routerConfig: widget.router,
    );
  }
}
