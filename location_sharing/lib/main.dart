import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_refresh.dart';
import 'core/config/app_env.dart';
import 'core/push/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/safety/domain/safety_notification_service.dart';
import 'features/safety/providers/location_providers.dart';

/// Handles auth callback deep link (e.g. email confirmation). Uses Supabase
/// auth's getSessionFromUrl to parse the link and establish the session.
Future<void> _handleAuthDeepLink(Uri uri) async {
  if (AppEnv.supabaseUrl.isEmpty) return;
  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  } catch (_) {
    // Ignore invalid/expired link
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env.local');
  } catch (_) {
    // Use --dart-define or no Supabase if .env.local missing
  }
  if (AppEnv.supabaseUrl.isNotEmpty && AppEnv.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
    // Handle auth callback when app is opened from email link (cold start).
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null &&
        initialUri.scheme == 'location-sharing' &&
        initialUri.pathSegments.isNotEmpty &&
        initialUri.pathSegments.first == 'auth') {
      unawaited(_handleAuthDeepLink(initialUri));
    }
    // Handle auth callback when app is in background and user taps link.
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null &&
          uri.scheme == 'location-sharing' &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == 'auth') {
        _handleAuthDeepLink(uri);
      }
    });
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
