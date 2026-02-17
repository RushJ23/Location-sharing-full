import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:location_sharing/core/auth/auth_refresh.dart';
import 'package:location_sharing/core/router/app_router.dart';
import 'package:location_sharing/main.dart';

void main() {
  testWidgets('App builds with router', (WidgetTester tester) async {
    final authRefresh = AuthRefreshNotifier();
    final router = createAppRouter(authRefresh);
    await tester.pumpWidget(
      ProviderScope(
        child: LocationSharingApp(
          router: router,
          authRefresh: authRefresh,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
