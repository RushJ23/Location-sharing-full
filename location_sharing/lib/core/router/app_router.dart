import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/incidents/presentation/create_incident_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/incidents/presentation/incident_detail_screen.dart';
import '../../features/safety/presentation/safety_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../config/app_env.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(Listenable? authRefresh) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authRefresh ?? Listenable.merge([]),
    initialLocation: '/login',
    redirect: (context, state) {
      if (AppEnv.supabaseUrl.isEmpty) return null;
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isAuthRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/safety',
        builder: (context, state) => const SafetyScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/incidents/create',
        builder: (context, state) {
          final trigger = state.uri.queryParameters['trigger'] ?? 'need_help';
          return CreateIncidentScreen(trigger: trigger);
        },
      ),
      GoRoute(
        path: '/incidents/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return IncidentDetailScreen(incidentId: id);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
}
