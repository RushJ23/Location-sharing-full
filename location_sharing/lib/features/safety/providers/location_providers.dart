import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/curfew_repository.dart';
import '../../../data/repositories/location_history_repository.dart';
import '../../../data/repositories/safe_zone_repository.dart';
import '../domain/curfew_scheduler.dart';
import '../domain/location_tracking_service.dart';
import '../domain/safety_notification_service.dart';

final locationHistoryRepositoryProvider = Provider<LocationHistoryRepository>((ref) {
  return LocationHistoryRepository(ref.watch(appDatabaseProvider));
});

final locationTrackingServiceProvider = Provider<LocationTrackingService>((ref) {
  final repo = ref.watch(locationHistoryRepositoryProvider);
  return LocationTrackingService(repo);
});

/// Last 12 hours of location samples (e.g. for incident upload or map).
final last12HoursLocationProvider = FutureProvider<List<LocationSample>>((ref) async {
  return ref.watch(locationHistoryRepositoryProvider).getLast12Hours();
});

final safeZoneRepositoryProvider = Provider<SafeZoneRepository>((ref) {
  return SafeZoneRepository();
});

final curfewRepositoryProvider = Provider<CurfewRepository>((ref) {
  return CurfewRepository();
});

final safetyNotificationServiceProvider = Provider<SafetyNotificationService>((ref) {
  return SafetyNotificationService();
});

/// Set in main with the real scheduler; used to reschedule after curfew add/edit/delete.
final curfewSchedulerProvider = Provider<CurfewScheduler?>((ref) => null);
