import 'package:flutter_test/flutter_test.dart';
import 'package:location_sharing/features/safety/domain/curfew_check_service.dart';
import 'package:location_sharing/features/safety/domain/safe_zone.dart';

void main() {
  group('isInsideAnySafeZone', () {
    test('empty list returns false', () {
      expect(isInsideAnySafeZone(40.44, -79.94, []), false);
    });

    test('point inside one zone returns true', () {
      final zones = [
        SafeZone(
          id: '1',
          userId: 'u1',
          name: 'Home',
          centerLat: 40.44,
          centerLng: -79.94,
          radiusMeters: 500,
          createdAt: DateTime.now(),
        ),
      ];
      expect(isInsideAnySafeZone(40.44, -79.94, zones), true);
    });

    test('point outside all zones returns false', () {
      final zones = [
        SafeZone(
          id: '1',
          userId: 'u1',
          name: 'Home',
          centerLat: 40.44,
          centerLng: -79.94,
          radiusMeters: 100,
          createdAt: DateTime.now(),
        ),
      ];
      expect(isInsideAnySafeZone(41.0, -79.0, zones), false);
    });
  });
}
