import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/config/app_env.dart';
import '../../../data/repositories/always_share_repository.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../providers/map_providers.dart';
import '../utils/marker_icon_utils.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  static const LatLng _defaultCenter = LatLng(40.44, -79.94);
  static const int _minMarkerSize = 44;
  static const int _maxMarkerSize = 96;

  Timer? _refreshTimer;
  RealtimeChannel? _incidentAccessChannel;
  double? _zoom;
  Set<Marker>? _contactMarkers;
  List<AlwaysShareLocation> _alwaysShareList = [];
  bool _boundsFitted = false;

  /// Icon size grows when zoomed out so people stay easy to find.
  int _markerSizeForZoom(double zoom) {
    final clamped = zoom.clamp(8.0, 18.0);
    final t = (18.0 - clamped) / 10.0;
    return (_minMarkerSize + t * (_maxMarkerSize - _minMarkerSize)).round();
  }

  Future<void> _buildContactMarkers(List<AlwaysShareLocation> list, double zoom) async {
    if (list.isEmpty) {
      if (mounted) setState(() => _contactMarkers = null);
      return;
    }
    final size = _markerSizeForZoom(zoom);
    final icon = await createPersonMarkerIcon(size);
    if (!mounted) return;
    final Set<Marker> markers = {};
    for (final loc in list) {
      final title = loc.displayName != null && loc.displayName!.isNotEmpty
          ? loc.displayName!
          : 'Sharing with you';
      markers.add(
        Marker(
          markerId: MarkerId('always_${loc.userId}'),
          position: LatLng(loc.lat, loc.lng),
          icon: icon,
          infoWindow: InfoWindow(title: title, snippet: 'Sharing location with you'),
        ),
      );
    }
    if (mounted) setState(() => _contactMarkers = markers);
  }

  Future<void> _fitBoundsToShowAll(GoogleMapController controller) async {
    if (_alwaysShareList.isEmpty) return;
    if (_boundsFitted) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _alwaysShareList.map((e) => e.lat).reduce((a, b) => a < b ? a : b) - 0.005,
        _alwaysShareList.map((e) => e.lng).reduce((a, b) => a < b ? a : b) - 0.005,
      ),
      northeast: LatLng(
        _alwaysShareList.map((e) => e.lat).reduce((a, b) => a > b ? a : b) + 0.005,
        _alwaysShareList.map((e) => e.lng).reduce((a, b) => a > b ? a : b) + 0.005,
      ),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
    if (mounted) setState(() => _boundsFitted = true);
  }

  Future<void> _flyToPerson(AlwaysShareLocation loc) async {
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 15),
    );
  }

  void _subscribeIncidentAccess(String userId) {
    _incidentAccessChannel?.unsubscribe();
    if (AppEnv.supabaseUrl.isNotEmpty) {
      _incidentAccessChannel = Supabase.instance.client
          .channel('incident_access_map_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'incident_access',
            callback: (_) {
              if (mounted) {
                final u = ref.read(currentUserProvider);
                if (u != null) ref.invalidate(mapDataProvider(u.id));
              }
            },
          )
          .subscribe();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.invalidate(mapDataProvider(user.id));
        ref.invalidate(userSafeZonesProvider(user.id));
        _subscribeIncidentAccess(user.id);
        _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
          if (mounted) {
            final u = ref.read(currentUserProvider);
            if (u != null) ref.invalidate(mapDataProvider(u.id));
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _incidentAccessChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _zoomIn() async {
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.zoomOut());
  }

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
    if (AppEnv.googleMapsApiKey.isEmpty) {
      return Scaffold(
        appBar: appBarWithBack(context, title: 'Map'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Add GOOGLE_MAPS_API_KEY to .env.local to use the map.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final mapDataAsync = ref.watch(mapDataProvider(user.id));
    final safeZonesAsync = ref.watch(userSafeZonesProvider(user.id));

    final Set<Marker> markers = {};
    LatLng? cameraTarget;
    List<AlwaysShareLocation> alwaysShare = [];
    if (mapDataAsync.hasValue && mapDataAsync.value != null) {
      final data = mapDataAsync.value!;
      alwaysShare = data.alwaysShare;
      final listChanged = alwaysShare.isNotEmpty &&
          (_alwaysShareList.length != alwaysShare.length ||
              _alwaysShareList.isEmpty);
      if (listChanged) {
        _alwaysShareList = alwaysShare;
        _boundsFitted = false;
        final zoom = _zoom ?? 14;
        _buildContactMarkers(alwaysShare, zoom);
        _mapController.future.then((c) => _fitBoundsToShowAll(c));
      }
      if (_contactMarkers != null) {
        markers.addAll(_contactMarkers!);
      } else if (alwaysShare.isNotEmpty) {
        for (final loc in alwaysShare) {
          final title = loc.displayName != null && loc.displayName!.isNotEmpty
              ? loc.displayName!
              : 'Sharing with you';
          markers.add(
            Marker(
              markerId: MarkerId('always_${loc.userId}'),
              position: LatLng(loc.lat, loc.lng),
              infoWindow: InfoWindow(
                title: title,
                snippet: 'Sharing location with you',
              ),
            ),
          );
        }
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
      cameraTarget ??= alwaysShare.isNotEmpty
          ? LatLng(alwaysShare.first.lat, alwaysShare.first.lng)
          : null;
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
              controller.getZoomLevel().then((zoom) {
                if (mounted) {
                  setState(() => _zoom = zoom);
                  if (_alwaysShareList.isNotEmpty) {
                    _buildContactMarkers(_alwaysShareList, zoom);
                    _fitBoundsToShowAll(controller);
                  }
                }
              });
            },
            onCameraMove: (position) {
              final z = position.zoom;
              final prev = _zoom;
              if (prev == null || (z - prev).abs() > 0.8) {
                _zoom = z;
                if (_alwaysShareList.isNotEmpty) {
                  _buildContactMarkers(_alwaysShareList, z);
                }
              }
            },
          ),
          if (alwaysShare.isNotEmpty)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Find:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...alwaysShare.map((loc) {
                          final name = loc.displayName != null &&
                                  loc.displayName!.isNotEmpty
                              ? loc.displayName!
                              : 'Someone';
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(name),
                              onSelected: (_) => _flyToPerson(loc),
                              selected: false,
                              showCheckmark: false,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
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
          if (mapDataAsync.hasValue &&
              mapDataAsync.value != null &&
              mapDataAsync.value!.alwaysShare.isEmpty)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    'No one is sharing location with you. Add contacts and turn on "Always share" to see them here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          // Zoom controls (work in simulator and when pinch is awkward)
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _zoomIn,
                    tooltip: 'Zoom in',
                  ),
                ),
                const SizedBox(height: 4),
                Material(
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _zoomOut,
                    tooltip: 'Zoom out',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
