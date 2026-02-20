import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:location_sharing/data/repositories/always_share_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'core/auth/auth_providers.dart';
import 'core/auth/auth_refresh.dart';
import 'core/config/app_env.dart';
import 'core/router/app_router.dart' show createAppRouter, rootNavigatorKey;
import 'core/theme/app_theme.dart';
import 'features/map/providers/map_providers.dart';
import 'features/incidents/domain/incident_notification_service.dart';
import 'features/incidents/providers/incident_providers.dart';
import 'features/incidents/presentation/incident_popup_guard.dart';
import 'features/safety/presentation/safety_check_dialog.dart';
import 'data/repositories/curfew_repository.dart';
import 'data/repositories/pending_safety_check_repository.dart';
import 'features/safety/domain/curfew_scheduler.dart';
import 'features/safety/domain/safety_notification_service.dart';
import 'features/safety/providers/location_providers.dart' as safety_providers;
import 'features/split_up/domain/split_up_notification_service.dart';
import 'core/background/incident_notification_background.dart' as incident_bg;

void _handleIncidentDeepLink(Uri uri, GoRouter router) {
  final incidentId = uri.pathSegments[1];
  if (incidentId.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      router.go('/incidents/$incidentId');
    }
  });
}

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
    try {
      await Workmanager().initialize(incident_bg.callbackDispatcher);
    } on PlatformException catch (_) {
      // Workmanager only supports Android/iOS; ignore on other platforms.
    }
  }
  final authRefresh = AuthRefreshNotifier();
  final router = createAppRouter(authRefresh);
  if (AppEnv.supabaseUrl.isNotEmpty) {
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null && initialUri.scheme == 'location-sharing') {
      if (initialUri.pathSegments.isNotEmpty &&
          initialUri.pathSegments.first == 'auth') {
        unawaited(_handleAuthDeepLink(initialUri));
      } else if (initialUri.pathSegments.length >= 2 &&
          initialUri.pathSegments.first == 'incidents') {
        _handleIncidentDeepLink(initialUri, router);
      }
    }
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri == null || uri.scheme != 'location-sharing') return;
      if (uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == 'auth') {
        _handleAuthDeepLink(uri);
      } else if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'incidents') {
        _handleIncidentDeepLink(uri, router);
      }
    });
  }
  final safetyNotifications = SafetyNotificationService();
  await safetyNotifications.initialize();
  final curfewRepo = CurfewRepository();
  final pendingCheckRepo = PendingSafetyCheckRepository();
  final curfewScheduler = CurfewScheduler(
    notificationService: safetyNotifications,
    curfewRepository: curfewRepo,
    pendingCheckRepository: pendingCheckRepo,
  );
  safetyNotifications.onNeedHelpPressed = (_, payload) async {
    await pendingCheckRepo.respond(scheduleId: payload);
    router.go('/incidents/create?trigger=need_help');
  };
  safetyNotifications.onSafePressed = (id, payload) async {
    await pendingCheckRepo.respond(scheduleId: payload);
    safetyNotifications.cancelSafetyCheck();
    if (payload != null && payload.isNotEmpty) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        curfewScheduler.scheduleRecheckIn10Min(userId, payload);
      }
    }
  };
  safetyNotifications.onNotificationOpened = (id, payload) {
    var attempts = 0;
    const maxAttempts = 20; // ~5 seconds total retry window
    void tryShow() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          showSafetyCheckDialog(ctx, payload: payload, timeoutMinutes: 5);
        } else if (attempts < maxAttempts) {
          attempts++;
          Future.delayed(const Duration(milliseconds: 250), tryShow);
        }
      });
    }
    tryShow();
  };
  final incidentNotifier = IncidentNotificationService(
    notificationPlugin: safetyNotifications.plugin,
    getSubjectDisplayName: (userId) async {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('display_name')
            .eq('id', userId)
            .maybeSingle();
        final name = res?['display_name'] as String?;
        return name?.trim().isNotEmpty == true ? name! : 'Someone';
      } catch (_) {
        return 'Someone';
      }
    },
  );
  safetyNotifications.onIncidentNotificationOpened = (incidentId) {
    var attempts = 0;
    const maxAttempts = 20;
    void tryNavigate() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rootNavigatorKey.currentContext != null) {
          router.go('/incidents/$incidentId');
        } else if (attempts < maxAttempts) {
          attempts++;
          Future.delayed(const Duration(milliseconds: 250), tryNavigate);
        }
      });
    }
    tryNavigate();
  };
  final splitUpService = SplitUpNotificationService(
    alwaysShareRepository: AlwaysShareRepository(),
  );
  splitUpService.onNoLongerWith = (displayName) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('You are no longer with $displayName.')),
        );
      }
    } else {
      safetyNotifications.showSplitUpNotification(displayName);
    }
  };
  if (AppEnv.supabaseUrl.isNotEmpty) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      curfewScheduler.rescheduleAllForUser(session.user.id);
      incidentNotifier.start(session.user.id);
      splitUpService.start(session.user.id);
      unawaited(incidentNotifier.checkForMissedNotifications());
      unawaited(incident_bg.persistIncidentBackgroundSession(
        supabaseUrl: AppEnv.supabaseUrl,
        anonKey: AppEnv.supabaseAnonKey,
        userId: session.user.id,
        accessToken: session.accessToken,
      ));
      try {
        await Workmanager().registerPeriodicTask(
          incident_bg.incidentCheckTaskName,
          incident_bg.incidentCheckTaskName,
          frequency: const Duration(minutes: 5),
        );
      } on PlatformException catch (_) {
        // Workmanager only supports Android/iOS; ignore on other platforms.
      }
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        safety_providers.safetyNotificationServiceProvider.overrideWithValue(safetyNotifications),
        safety_providers.curfewSchedulerProvider.overrideWithValue(curfewScheduler),
        splitUpNotificationServiceProvider.overrideWithValue(splitUpService),
      ],
      child: LocationSharingApp(
        router: router,
        authRefresh: authRefresh,
        curfewScheduler: curfewScheduler,
        incidentNotifier: incidentNotifier,
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
    required this.incidentNotifier,
  });

  final GoRouter router;
  final AuthRefreshNotifier authRefresh;
  final CurfewScheduler curfewScheduler;
  final IncidentNotificationService incidentNotifier;

  @override
  ConsumerState<LocationSharingApp> createState() => _LocationSharingAppState();
}

class _LocationSharingAppState extends ConsumerState<LocationSharingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (AppEnv.supabaseUrl.isNotEmpty) {
      Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
      WidgetsBinding.instance.addObserver(this);
      widget.incidentNotifier.onIncidentShown = () {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          ref.invalidate(mapDataProvider(user.id));
          ref.invalidate(activeIncidentsProvider);
        }
      };
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.incidentNotifier.checkForMissedNotifications();
      // Refresh incidents and map data so user sees new incidents when navigating
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.invalidate(mapDataProvider(user.id));
        ref.invalidate(activeIncidentsProvider);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Run immediately so we can show notification before iOS suspends the app.
      widget.incidentNotifier.checkForMissedNotifications();
      // Also schedule a one-off background check (helps on Android; iOS may run it opportunistically).
      try {
        Workmanager().registerOneOffTask(
          incident_bg.incidentCheckOneOffTaskName,
          incident_bg.incidentCheckTaskName,
          initialDelay: const Duration(seconds: 15),
        );
      } on PlatformException catch (_) {}
      Future.delayed(const Duration(seconds: 2), () {
        widget.incidentNotifier.checkForMissedNotifications();
      });
    }
  }

  void _onAuthChange(dynamic state) {
    widget.authRefresh.refresh();
    final session = (state as dynamic).session;
    if (session != null) {
      final userId = (session.user as dynamic).id as String;
      final accessToken = (session as dynamic).accessToken as String?;
      widget.curfewScheduler.rescheduleAllForUser(userId);
      widget.incidentNotifier.start(userId);
      unawaited(incident_bg.persistIncidentBackgroundSession(
        supabaseUrl: AppEnv.supabaseUrl,
        anonKey: AppEnv.supabaseAnonKey,
        userId: userId,
        accessToken: accessToken ?? '',
      ));
      unawaited(
        Workmanager()
            .registerPeriodicTask(
              incident_bg.incidentCheckTaskName,
              incident_bg.incidentCheckTaskName,
              frequency: const Duration(minutes: 5),
            )
            .catchError((Object _) {
          // Workmanager only supports Android/iOS; ignore on other platforms.
        }),
      );
    } else {
      widget.incidentNotifier.stop();
      unawaited(incident_bg.clearIncidentBackgroundSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final updater = ref.watch(alwaysShareLocationUpdaterProvider);
    final locationTracker = ref.watch(safety_providers.locationTrackingServiceProvider);
    final incidentSubjectUpdater = ref.watch(incidentSubjectLocationUpdaterProvider);
    final splitUpService = ref.watch(splitUpNotificationServiceProvider);
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null) {
        updater.start(next.id);
        locationTracker.startTracking(userId: next.id);
        incidentSubjectUpdater.start();
        splitUpService.start(next.id);
      } else {
        updater.stop();
        locationTracker.stopTracking();
        incidentSubjectUpdater.stop();
        splitUpService.stop();
      }
    });
    if (user != null && !updater.isRunning) {
      updater.start(user.id);
      locationTracker.startTracking(userId: user.id);
      incidentSubjectUpdater.start();
      splitUpService.start(user.id);
    } else if (user == null) {
      if (updater.isRunning) updater.stop();
      if (locationTracker.isTracking) locationTracker.stopTracking();
      incidentSubjectUpdater.stop();
      splitUpService.stop();
    }
    return MaterialApp.router(
      title: 'Location Sharing',
      theme: appTheme,
      routerConfig: widget.router,
      builder: (context, child) =>
          IncidentPopupGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
