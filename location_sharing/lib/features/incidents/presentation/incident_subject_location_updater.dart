import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/repositories/incident_repository.dart';

/// When the current user has an active incident as subject, periodically uploads their current location.
class IncidentSubjectLocationUpdater {
  IncidentSubjectLocationUpdater({
    required IncidentRepository incidentRepo,
    required this.getCurrentUserId,
  }) : _incidentRepo = incidentRepo;

  final IncidentRepository _incidentRepo;
  final String? Function() getCurrentUserId;

  Timer? _timer;

  void start() {
    stop();
    _tick();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    try {
      final incidents = await _incidentRepo.getActiveIncidentsWhereSubject(userId);
      if (incidents.isEmpty) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      for (final inc in incidents) {
        try {
          await _incidentRepo.updateSubjectLocation(inc.id, pos.latitude, pos.longitude);
        } catch (e) {
          debugPrint('Failed to update subject location: $e');
        }
      }
    } catch (_) {
      // Ignore
    }
  }
}
