import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../data/repositories/incident_repository.dart';
import '../domain/incident.dart';
import '../presentation/incident_subject_location_updater.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository();
});

/// Active incidents visible to current user (subject or contact). Used on Home for discoverability.
final activeIncidentsProvider = FutureProvider<List<Incident>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(incidentRepositoryProvider).getActiveIncidents();
});

/// Display name of the subject (person the incident is about) for a given incident.
final incidentSubjectDisplayNameProvider = FutureProvider.family<String, String>((ref, incidentId) async {
  final incident = await ref.read(incidentRepositoryProvider).getIncident(incidentId);
  if (incident == null) return 'Someone';
  final profile = await ref.read(profileRepositoryProvider).getProfile(incident.userId);
  final name = profile?.displayName.trim();
  return name != null && name.isNotEmpty ? name : 'Someone';
});

/// Emergency fallback: subject's always_share location for this incident when subject_current_* is null.
/// Only returns data for active incidents the current user has access to.
final subjectFallbackLocationProvider = FutureProvider.family<({double lat, double lng})?, String>((ref, incidentId) async {
  return ref.read(incidentRepositoryProvider).getSubjectFallbackLocationForIncident(incidentId);
});

final incidentSubjectLocationUpdaterProvider = Provider<IncidentSubjectLocationUpdater>((ref) {
  return IncidentSubjectLocationUpdater(
    incidentRepo: ref.watch(incidentRepositoryProvider),
    getCurrentUserId: () => ref.read(currentUserProvider)?.id,
  );
});
