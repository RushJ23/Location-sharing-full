import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/always_share_repository.dart';
import '../../../features/incidents/domain/incident.dart';
import '../../../features/incidents/providers/incident_providers.dart';

final alwaysShareRepositoryProvider = Provider<AlwaysShareRepository>((ref) {
  return AlwaysShareRepository();
});

/// Cached map data so the map doesn't re-fetch on every build (fixes map not loading).
class MapData {
  const MapData({
    required this.alwaysShare,
    required this.incidents,
  });
  final List<AlwaysShareLocation> alwaysShare;
  final List<Incident> incidents;
}

final mapDataProvider = FutureProvider<MapData>((ref) async {
  final repoAlways = ref.read(alwaysShareRepositoryProvider);
  final repoIncidents = ref.read(incidentRepositoryProvider);
  try {
    final result = await Future.wait<List<dynamic>>([
      repoAlways.getAlwaysShareLocations(),
      repoIncidents.getActiveIncidents(),
    ]).timeout(
      const Duration(seconds: 15),
      onTimeout: () => [<AlwaysShareLocation>[], <Incident>[]],
    );
    return MapData(
      alwaysShare: result[0] as List<AlwaysShareLocation>,
      incidents: result[1] as List<Incident>,
    );
  } catch (_) {
    return MapData(alwaysShare: [], incidents: []);
  }
});
