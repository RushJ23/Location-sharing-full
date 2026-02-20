import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/repositories/always_share_repository.dart';
import '../../map/providers/map_providers.dart';

/// Distance threshold in meters: notify when a contact goes from within to beyond this.
const double splitUpDistanceMeters = 50;

/// Check interval for "no longer with" detection.
const Duration splitUpCheckInterval = Duration(seconds: 45);

/// Listens to always-share locations every 45s; when a contact was within 50m
/// and is now beyond 50m, calls [onNoLongerWith] with their display name.
class SplitUpNotificationService {
  SplitUpNotificationService({
    required AlwaysShareRepository alwaysShareRepository,
  }) : _alwaysShareRepository = alwaysShareRepository;

  final AlwaysShareRepository _alwaysShareRepository;

  /// Called when a contact was near and is now beyond 50m. Pass their display name.
  void Function(String displayName)? onNoLongerWith;

  Timer? _timer;
  String? _userId;
  final Set<String> _previouslyNearUserIds = {};

  bool get isRunning => _timer != null;

  void start(String userId) {
    if (_userId == userId && _timer != null) return;
    stop();
    _userId = userId;
    _previouslyNearUserIds.clear();
    _timer = Timer.periodic(splitUpCheckInterval, (_) => _check());
    unawaited(_check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _userId = null;
    _previouslyNearUserIds.clear();
  }

  Future<void> _check() async {
    final userId = _userId;
    if (userId == null) return;

    Position? myPosition;
    try {
      myPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return;
    }

    List<AlwaysShareLocation> locations;
    try {
      locations = await _alwaysShareRepository.getAlwaysShareLocations(userId);
    } catch (_) {
      return;
    }

    final nowNearUserIds = <String>{};
    for (final loc in locations) {
      final distanceMeters = Geolocator.distanceBetween(
        myPosition.latitude,
        myPosition.longitude,
        loc.lat,
        loc.lng,
      );
      if (distanceMeters <= splitUpDistanceMeters) {
        nowNearUserIds.add(loc.userId);
      } else if (_previouslyNearUserIds.contains(loc.userId)) {
        final displayName = loc.displayName?.trim().isNotEmpty == true
            ? loc.displayName!
            : 'Someone';
        onNoLongerWith?.call(displayName);
        _previouslyNearUserIds.remove(loc.userId);
      }
    }
    _previouslyNearUserIds
      ..removeWhere((id) => !nowNearUserIds.contains(id))
      ..addAll(nowNearUserIds);
  }
}

final splitUpNotificationServiceProvider = Provider<SplitUpNotificationService>((ref) {
  return SplitUpNotificationService(
    alwaysShareRepository: ref.watch(alwaysShareRepositoryProvider),
  );
});
