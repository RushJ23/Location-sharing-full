import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
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
    final mapDataAsync = ref.watch(mapDataProvider);
    final safeZonesAsync = ref.watch(userSafeZonesProvider(user.id));

    // Build markers and camera target from data when available; otherwise empty/default so map always shows.
    final Set<Marker> markers = {};
    LatLng? cameraTarget;
    if (mapDataAsync.hasValue && mapDataAsync.value != null) {
      final data = mapDataAsync.value!;
      for (final loc in data.alwaysShare) {
        markers.add(
          Marker(
            markerId: MarkerId('always_${loc.userId}'),
            position: LatLng(loc.lat, loc.lng),
            infoWindow: InfoWindow(title: 'Always share'),
          ),
        );
        cameraTarget ??= LatLng(loc.lat, loc.lng);
      }
      for (final inc in data.incidents) {
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
    }

    final safeZoneCircles = safeZonesAsync.hasValue && safeZonesAsync.value != null
        ? safeZonesToCircles(safeZonesAsync.value!)
        : <Circle>{};
    final target = cameraTarget ?? _defaultCenter;

    return Scaffold(
      appBar: appBarWithBack(context, title: 'Map'),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: target,
              zoom: 14,
            ),
            markers: markers,
            circles: safeZoneCircles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
          ),
          if (mapDataAsync.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Loading locations…'),
                  ),
                ),
              ),
            ),
          if (mapDataAsync.hasError)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Could not load locations: ${mapDataAsync.error}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
