import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../../../data/repositories/always_share_repository.dart';
import '../../../features/incidents/domain/incident.dart';
import '../../../features/incidents/providers/incident_providers.dart';
import '../providers/map_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  static const LatLng _defaultCenter = LatLng(40.44, -79.94);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: appBarWithBack(context, title: 'Map'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Sign in to see the map',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: appBarWithBack(context, title: 'Map'),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          ref.read(alwaysShareRepositoryProvider).getAlwaysShareLocations(),
          ref.read(incidentRepositoryProvider).getActiveIncidents(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final alwaysShare = snapshot.data![0] as List<AlwaysShareLocation>;
          final incidents = snapshot.data![1] as List<Incident>;
          final markers = <Marker>{};
          LatLng? cameraTarget;
          for (final loc in alwaysShare) {
            markers.add(
              Marker(
                markerId: MarkerId('always_${loc.userId}'),
                position: LatLng(loc.lat, loc.lng),
                infoWindow: const InfoWindow(title: 'Always share'),
              ),
            );
            cameraTarget ??= LatLng(loc.lat, loc.lng);
          }
          for (final inc in incidents) {
            if (inc.lastKnownLat != null && inc.lastKnownLng != null) {
              markers.add(
                Marker(
                  markerId: MarkerId('incident_${inc.id}'),
                  position: LatLng(inc.lastKnownLat!, inc.lastKnownLng!),
                  infoWindow: InfoWindow(title: 'Incident', snippet: inc.trigger),
                  onTap: () => context.go('/incidents/${inc.id}'),
                ),
              );
              cameraTarget ??= LatLng(inc.lastKnownLat!, inc.lastKnownLng!);
            }
          }
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: cameraTarget ?? _defaultCenter,
              zoom: 14,
            ),
            markers: markers,
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
          );
        },
      ),
    );
  }
}
