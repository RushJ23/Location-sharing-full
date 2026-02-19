import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/repositories/location_history_repository.dart';
import '../../../data/repositories/user_location_upload_repository.dart';

/// Configurable sampling interval (battery-conscious). Default 5 minutes.
const Duration defaultSamplingInterval = Duration(minutes: 5);

/// Requests location permissions (foreground then background), then samples
/// periodically and persists to local DB. Prunes data older than 12h.
/// Uploads last 12h to Supabase when userId is provided.
/// On Android, when app is in background, use a foreground service for reliable sampling.
class LocationTrackingService {
  LocationTrackingService(this._repository, [this._uploadRepository]);

  final LocationHistoryRepository _repository;
  final UserLocationUploadRepository? _uploadRepository;
  Timer? _timer;

  bool get isTracking => _timer != null;

  /// Request foreground location permission first, then "always" for background.
  Future<bool> requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return false;
    final always = await Permission.locationAlways.request();
    return always.isGranted || status.isGranted;
  }

  /// Returns whether we have at least when-in-use (or always) permission.
  Future<bool> get hasPermission async {
    final s = await Permission.location.status;
    return s.isGranted || (await Permission.locationWhenInUse.status).isGranted;
  }

  /// Start periodic sampling and persist to DB. Prunes after each insert.
  /// If [userId] is provided and upload repository is set, uploads last 12h to Supabase after each sample.
  void startTracking({
    Duration interval = defaultSamplingInterval,
    String? userId,
  }) {
    stopTracking();
    void sample() async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        await _repository.addSample(pos.latitude, pos.longitude, pos.timestamp);
        await _repository.pruneOlderThan12Hours();
        if (userId != null && _uploadRepository != null) {
          try {
            final samples = await _repository.getLast12Hours();
            await _uploadRepository!.uploadLast12Hours(
              userId: userId,
              samples: samples,
            );
          } catch (_) {
            // Ignore upload failure; next sample will retry
          }
        }
      } catch (_) {
        // Ignore single failure; next interval will retry
      }
    }

    sample();
    _timer = Timer.periodic(interval, (_) => sample());
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }
}
