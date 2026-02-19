import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../data/repositories/incident_repository.dart';
import '../presentation/incident_subject_location_updater.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository();
});

final incidentSubjectLocationUpdaterProvider = Provider<IncidentSubjectLocationUpdater>((ref) {
  return IncidentSubjectLocationUpdater(
    incidentRepo: ref.watch(incidentRepositoryProvider),
    getCurrentUserId: () => ref.read(currentUserProvider)?.id,
  );
});
