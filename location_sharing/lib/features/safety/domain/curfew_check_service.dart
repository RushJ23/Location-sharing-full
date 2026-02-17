import 'package:geolocator/geolocator.dart';

import '../../../shared/utils/geofence.dart';
import 'safe_zone.dart';

/// Returns true if (lat, lng) is inside any of the given safe zones (point-in-circle).
bool isInsideAnySafeZone(
  double lat,
  double lng,
  List<SafeZone> safeZones,
) {
  for (final zone in safeZones) {
    if (isInsideCircle(
      lat,
      lng,
      zone.centerLat,
      zone.centerLng,
      zone.radiusMeters,
    )) {
      return true;
    }
  }
  return false;
}

/// Runs curfew check: gets current location, returns whether user is in any of the safe zones.
/// Caller is responsible for showing "Are you safe?" notification if not inside.
Future<CurfewCheckResult> runCurfewCheck(List<SafeZone> safeZones) async {
  if (safeZones.isEmpty) {
    return CurfewCheckResult(insideSafeZone: false, lat: null, lng: null);
  }
  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    final inside = isInsideAnySafeZone(pos.latitude, pos.longitude, safeZones);
    return CurfewCheckResult(
      insideSafeZone: inside,
      lat: pos.latitude,
      lng: pos.longitude,
    );
  } catch (_) {
    return CurfewCheckResult(insideSafeZone: false, lat: null, lng: null);
  }
}

class CurfewCheckResult {
  const CurfewCheckResult({
    required this.insideSafeZone,
    this.lat,
    this.lng,
  });
  final bool insideSafeZone;
  final double? lat;
  final double? lng;
}
