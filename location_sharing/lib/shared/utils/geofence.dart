import 'dart:math' as math;

/// Earth radius in meters (approximate).
const double earthRadiusMeters = 6371000;

/// Returns distance in meters between two (lat, lng) points using Haversine formula.
double distanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _toRad(double deg) => deg * math.pi / 180;

/// Returns true if (lat, lng) is inside the circle defined by center and radius_meters.
bool isInsideCircle(
  double lat,
  double lng,
  double centerLat,
  double centerLng,
  double radiusMeters,
) {
  return distanceMeters(lat, lng, centerLat, centerLng) <= radiusMeters;
}
