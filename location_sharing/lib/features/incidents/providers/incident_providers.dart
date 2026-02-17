import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/incident_repository.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository();
});
