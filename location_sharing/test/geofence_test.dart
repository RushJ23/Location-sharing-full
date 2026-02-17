import 'package:flutter_test/flutter_test.dart';
import 'package:location_sharing/shared/utils/geofence.dart';

void main() {
  group('distanceMeters', () {
    test('same point returns 0', () {
      expect(distanceMeters(40.44, -79.94, 40.44, -79.94), 0);
    });

    test('returns positive distance for distinct points', () {
      final d = distanceMeters(40.44, -79.94, 40.45, -79.93);
      expect(d, greaterThan(0));
      expect(d, lessThan(2000));
    });
  });

  group('isInsideCircle', () {
    test('point at center is inside', () {
      expect(
        isInsideCircle(40.44, -79.94, 40.44, -79.94, 100),
        true,
      );
    });

    test('point within radius is inside', () {
      expect(
        isInsideCircle(40.4401, -79.94, 40.44, -79.94, 500),
        true,
      );
    });

    test('point outside radius is not inside', () {
      expect(
        isInsideCircle(41.0, -79.94, 40.44, -79.94, 1000),
        false,
      );
    });

    test('point exactly on boundary is inside', () {
      const centerLat = 40.44;
      const centerLng = -79.94;
      const radius = 100.0;
      final d = distanceMeters(40.44, -79.95, centerLat, centerLng);
      expect(d, greaterThan(0));
      expect(
        isInsideCircle(40.44, -79.95, centerLat, centerLng, d),
        true,
      );
    });
  });
}
