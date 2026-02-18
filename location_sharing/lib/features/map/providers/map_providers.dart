import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/repositories/always_share_repository.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../features/contacts/providers/contact_providers.dart';
import '../../../features/incidents/domain/incident.dart';
import '../../../features/incidents/providers/incident_providers.dart';
import '../../../features/map/domain/always_share_location_updater.dart';
import '../../../features/safety/domain/safe_zone.dart';
import '../../../features/safety/providers/location_providers.dart';

final alwaysShareRepositoryProvider = Provider<AlwaysShareRepository>((ref) {
  return AlwaysShareRepository();
});

final alwaysShareLocationUpdaterProvider =
    Provider<AlwaysShareLocationUpdater>((ref) {
  return AlwaysShareLocationUpdater(
    contactRepository: ref.watch(contactRepositoryProvider),
    alwaysShareRepository: ref.watch(alwaysShareRepositoryProvider),
  );
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

/// Map data for the current user (always-share contact locations + active incidents).
/// Keyed by [userId] so it refetches when the user changes.
final mapDataProvider = FutureProvider.family<MapData, String>((ref, userId) async {
  final repoAlways = ref.read(alwaysShareRepositoryProvider);
  final repoIncidents = ref.read(incidentRepositoryProvider);
  final result = await Future.wait<List<dynamic>>([
    repoAlways.getAlwaysShareLocations(userId),
    repoIncidents.getActiveIncidents(),
  ]).timeout(
    const Duration(seconds: 15),
    onTimeout: () => [<AlwaysShareLocation>[], <Incident>[]],
  );
  return MapData(
    alwaysShare: result[0] as List<AlwaysShareLocation>,
    incidents: result[1] as List<Incident>,
  );
});

final userSafeZonesProvider =
    FutureProvider.family<List<SafeZone>, String>((ref, userId) async {
  return ref.watch(safeZoneRepositoryProvider).getSafeZones(userId);
});

/// Converts user safe zones to map circles (highlighted with semi-transparent green).
Set<Circle> safeZonesToCircles(List<SafeZone> zones) {
  const fillColor = Color(0x3300C853); // Green at ~20% opacity
  const strokeColor = Color(0xFF00C853); // Solid green border
  return {
    for (final z in zones)
      Circle(
        circleId: CircleId('safe_zone_${z.id}'),
        center: LatLng(z.centerLat, z.centerLng),
        radius: z.radiusMeters,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: 2,
      ),
  };
}
