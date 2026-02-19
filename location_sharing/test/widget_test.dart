import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_sharing/core/auth/auth_refresh.dart';
import 'package:location_sharing/core/router/app_router.dart';
import 'package:location_sharing/data/repositories/curfew_repository.dart';
import 'package:location_sharing/features/safety/domain/curfew_scheduler.dart';
import 'package:location_sharing/features/safety/domain/safety_notification_service.dart';
import 'package:location_sharing/main.dart';

void main() {
  testWidgets('App builds with router', (WidgetTester tester) async {
    final authRefresh = AuthRefreshNotifier();
    final router = createAppRouter(authRefresh);
    final safetyNotifications = SafetyNotificationService();
    final curfewScheduler = CurfewScheduler(
      notificationService: safetyNotifications,
      curfewRepository: CurfewRepository(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: LocationSharingApp(
          router: router,
          authRefresh: authRefresh,
          curfewScheduler: curfewScheduler,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
