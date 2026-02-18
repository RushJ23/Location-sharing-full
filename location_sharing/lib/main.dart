import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'core/auth/auth_providers.dart';
import 'core/auth/auth_refresh.dart';
import 'core/config/app_env.dart';
import 'core/push/fcm_service.dart';
import 'core/router/app_router.dart' show createAppRouter, rootNavigatorKey;
import 'core/theme/app_theme.dart';
import 'features/map/providers/map_providers.dart';
import 'features/safety/presentation/safety_check_dialog.dart';
import 'data/repositories/curfew_repository.dart';
import 'features/safety/domain/curfew_scheduler.dart';
import 'features/safety/domain/safety_notification_service.dart';
import 'features/safety/providers/location_providers.dart' as safety_providers;

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
  tz_data.initializeTimeZones();
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
  final curfewRepo = CurfewRepository();
  final curfewScheduler = CurfewScheduler(
    notificationService: safetyNotifications,
    curfewRepository: curfewRepo,
  );
  final authRefresh = AuthRefreshNotifier();
  final router = createAppRouter(authRefresh);
  safetyNotifications.onNeedHelpPressed = (_, _) {
    router.go('/incidents/create?trigger=need_help');
  };
  safetyNotifications.onSafePressed = (id, payload) {
    safetyNotifications.cancelSafetyCheck();
    if (payload != null && payload.isNotEmpty) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        curfewScheduler.scheduleRecheckIn10Min(userId, payload);
      }
    }
  };
  safetyNotifications.onNotificationOpened = (id, payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        showSafetyCheckDialog(
          context,
          payload: payload,
          timeoutMinutes: 5,
        );
      }
    });
  };
  setupFcmHandlers((incidentId) {
    if (incidentId != null) router.go('/incidents/$incidentId');
  });
  if (AppEnv.supabaseUrl.isNotEmpty) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      registerFcmAndSaveToken(session.user.id);
      curfewScheduler.rescheduleAllForUser(session.user.id);
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        safety_providers.safetyNotificationServiceProvider.overrideWithValue(safetyNotifications),
        safety_providers.curfewSchedulerProvider.overrideWithValue(curfewScheduler),
      ],
      child: LocationSharingApp(
        router: router,
        authRefresh: authRefresh,
        curfewScheduler: curfewScheduler,
      ),
    ),
  );
}

class LocationSharingApp extends ConsumerStatefulWidget {
  const LocationSharingApp({
    super.key,
    required this.router,
    required this.authRefresh,
    required this.curfewScheduler,
  });

  final GoRouter router;
  final AuthRefreshNotifier authRefresh;
  final CurfewScheduler curfewScheduler;

  @override
  ConsumerState<LocationSharingApp> createState() => _LocationSharingAppState();
}

class _LocationSharingAppState extends ConsumerState<LocationSharingApp> {
  void _onAuthChange(dynamic state) {
    widget.authRefresh.refresh();
    final session = (state as dynamic).session;
    if (session != null) {
      final userId = (session.user as dynamic).id as String;
      registerFcmAndSaveToken(userId);
      widget.curfewScheduler.rescheduleAllForUser(userId);
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
    final user = ref.watch(currentUserProvider);
    final updater = ref.watch(alwaysShareLocationUpdaterProvider);
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null) {
        updater.start(next.id);
      } else {
        updater.stop();
      }
    });
    if (user != null && !updater.isRunning) {
      updater.start(user.id);
    } else if (user == null && updater.isRunning) {
      updater.stop();
    }
    return MaterialApp.router(
      title: 'Location Sharing',
      theme: appTheme,
      routerConfig: widget.router,
    );
  }
}
