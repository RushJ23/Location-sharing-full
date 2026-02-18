import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../data/repositories/always_share_repository.dart';
import '../../../data/repositories/contact_repository.dart';

/// When the current user has at least one contact with "always share" enabled,
/// periodically updates their location in [always_share_locations] so those
/// contacts can see it on the map.
class AlwaysShareLocationUpdater {
  AlwaysShareLocationUpdater({
    required ContactRepository contactRepository,
    required AlwaysShareRepository alwaysShareRepository,
  })  : _contactRepository = contactRepository,
        _alwaysShareRepository = alwaysShareRepository;

  final ContactRepository _contactRepository;
  final AlwaysShareRepository _alwaysShareRepository;

  static const Duration _interval = Duration(seconds: 45);

  Timer? _timer;
  String? _userId;

  bool get isRunning => _timer != null;

  /// Start periodic updates when [userId] is the current user. No-op if already
  /// running for the same user.
  void start(String userId) {
    if (_userId == userId && _timer != null) return;
    stop();
    _userId = userId;
    _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _userId = null;
  }

  Future<void> _tick() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final contacts = await _contactRepository.getContacts(userId);
      final hasAlwaysShare = contacts.any((c) => c.isAlwaysShare);
      if (!hasAlwaysShare) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await _alwaysShareRepository.updateMyLocation(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      // Ignore single failure; next interval will retry
    }
  }
}
