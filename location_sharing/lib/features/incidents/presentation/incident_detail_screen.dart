import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../../map/providers/map_providers.dart';
import '../domain/incident.dart';
import '../providers/incident_providers.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final incidentAsync = ref.watch(_incidentProvider(incidentId));
    final incident = incidentAsync.valueOrNull;
    final subjectName = ref.watch(incidentSubjectDisplayNameProvider(incidentId)).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final isSubject = user?.id == incident?.userId;
    final shouldBlockPop =
        incident != null && incident.isActive && isSubject == true;
    final appBarTitle = subjectName != null ? 'Incident — $subjectName' : 'Incident';

    return PopScope(
      canPop: !shouldBlockPop,
      child: Scaffold(
        appBar: appBarWithBack(
          context,
          title: appBarTitle,
          showBackButton: !shouldBlockPop,
        ),
        body: incidentAsync.when(
        data: (incident) {
          if (incident == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Incident not found',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          final user = ref.watch(currentUserProvider);
          final isSubject = user?.id == incident.userId;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 320,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: _IncidentMap(incidentId: incidentId, incident: incident),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  incident.isActive
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: incident.isActive
                                      ? theme.colorScheme.tertiary
                                      : theme.colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        incident.status,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            _DetailRow(
                              icon: Icons.flash_on_rounded,
                              label: 'Trigger',
                              value: incident.trigger,
                            ),
                            if (incident.lastKnownLat != null &&
                                incident.lastKnownLng != null) ...[
                              const SizedBox(height: 8),
                              _DetailRow(
                                icon: Icons.place_rounded,
                                label: 'Last known location',
                                value:
                                    '${incident.lastKnownLat!.toStringAsFixed(4)}, '
                                    '${incident.lastKnownLng!.toStringAsFixed(4)}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (incident.isActive && isSubject) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Resolve this incident',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _markSelfSafe(context, ref),
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('I am safe'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (incident.isActive && !isSubject) ...[
                      const SizedBox(height: 24),
                      Text(
                        'As a contact you can:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _confirmSafe(context, ref),
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text('I confirm they\'re safe'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _couldNotReach(ref),
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text('I couldn\'t reach them'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: $e'),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _markSelfSafe(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(incidentRepositoryProvider).resolveIncident(incidentId, user.id);
    ref.invalidate(_incidentProvider(incidentId));
    ref.invalidate(incidentRepositoryProvider);
    ref.invalidate(activeIncidentsProvider);
    ref.invalidate(mapDataProvider(user.id));
    if (!context.mounted) return;
    context.go('/');
  }

  Future<void> _confirmSafe(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(incidentRepositoryProvider).confirmSafe(incidentId, user.id);
    await ref.read(incidentRepositoryProvider).resolveIncident(incidentId, user.id);
    ref.invalidate(_incidentProvider(incidentId));
    ref.invalidate(activeIncidentsProvider);
    ref.invalidate(mapDataProvider(user.id));
    if (!context.mounted) return;
    context.go('/');
  }

  Future<void> _couldNotReach(WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(incidentRepositoryProvider);
    await repo.couldNotReach(incidentId, user.id);
    final myLayer = await repo.getContactLayerForIncident(incidentId, user.id);
    if (myLayer != null && myLayer < 3) {
      await repo.invokeEscalation(incidentId, myLayer + 1);
    }
    ref.invalidate(_incidentProvider(incidentId));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

final _incidentProvider = FutureProvider.family<Incident?, String>((ref, id) async {
  return ref.watch(incidentRepositoryProvider).getIncident(id);
});

final _incidentPathProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, incidentId) async {
  return ref.watch(incidentRepositoryProvider).getIncidentLocationHistory(incidentId);
});

class _IncidentMap extends ConsumerStatefulWidget {
  const _IncidentMap({
    required this.incidentId,
    required this.incident,
  });
  final String incidentId;
  final Incident incident;

  @override
  ConsumerState<_IncidentMap> createState() => _IncidentMapState();
}

class _IncidentMapState extends ConsumerState<_IncidentMap> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  Future<void> _flyTo(LatLng target) async {
    final c = await _controller.future;
    await c.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  Future<void> _zoomIn() async {
    final c = await _controller.future;
    await c.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final c = await _controller.future;
    await c.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pathAsync = ref.watch(_incidentPathProvider(widget.incidentId));
    final fallbackAsync = ref.watch(subjectFallbackLocationProvider(widget.incidentId));
    final fallback = fallbackAsync.valueOrNull;
    final effectiveCurrentLat = widget.incident.subjectCurrentLat ?? fallback?.lat;
    final effectiveCurrentLng = widget.incident.subjectCurrentLng ?? fallback?.lng;
    final hasSubjectCurrent = effectiveCurrentLat != null && effectiveCurrentLng != null;
    final isFallbackCurrent = hasSubjectCurrent && widget.incident.subjectCurrentLat == null;
    return pathAsync.when(
      data: (path) {
        final hasLastKnown = widget.incident.lastKnownLat != null && widget.incident.lastKnownLng != null;
        if (path.isEmpty && !hasSubjectCurrent && !hasLastKnown) {
          return const Center(child: Text('No location history'));
        }
        final points = path
            .map((e) => LatLng(
                  (e['lat'] as num).toDouble(),
                  (e['lng'] as num).toDouble(),
                ))
            .toList();
        final pointsWithTime = <({LatLng point, DateTime timestamp})>[];
        for (int i = 0; i < path.length; i++) {
          final e = path[i];
          final ts = e['timestamp'];
          if (ts != null && ts is String) {
            try {
              pointsWithTime.add((
                point: points[i],
                timestamp: DateTime.parse(ts),
              ));
            } catch (_) {}
          }
        }
        final lastTs = pointsWithTime.isNotEmpty
            ? pointsWithTime.last.timestamp
            : DateTime.now();
        final fallbackLatLng = hasLastKnown
            ? LatLng(widget.incident.lastKnownLat!, widget.incident.lastKnownLng!)
            : const LatLng(40.44, -79.94);

        /// Position for "X hours ago": from path (closest point to lastTs - Xh), or interpolated when path is short.
        LatLng positionForHoursAgo(int hours) {
          final targetTs = lastTs.subtract(Duration(hours: hours));
          if (pointsWithTime.isNotEmpty) {
            LatLng best = pointsWithTime.first.point;
            Duration bestDiff = const Duration(hours: 24);
            for (final pt in pointsWithTime) {
              final d = (pt.timestamp.difference(targetTs)).abs();
              if (d < bestDiff) {
                bestDiff = d;
                best = pt.point;
              }
            }
            return best;
          }
          // No path data: interpolate from "12h ago" = fallback to "now" = current
          final current = hasSubjectCurrent
              ? LatLng(effectiveCurrentLat!, effectiveCurrentLng!)
              : (hasLastKnown
                  ? LatLng(widget.incident.lastKnownLat!, widget.incident.lastKnownLng!)
                  : fallbackLatLng);
          if (!hasSubjectCurrent && !hasLastKnown) return fallbackLatLng;
          final t = (12 - hours) / 12; // 0 at 12h ago, 1 at now
          return LatLng(
            fallbackLatLng.latitude + t * (current.latitude - fallbackLatLng.latitude),
            fallbackLatLng.longitude + t * (current.longitude - fallbackLatLng.longitude),
          );
        }

        // 13 positions: 12h ago .. 1h ago (history) + current. Polyline connects them in that order.
        final currentLatLng = hasSubjectCurrent
            ? LatLng(effectiveCurrentLat!, effectiveCurrentLng!)
            : (hasLastKnown
                ? LatLng(widget.incident.lastKnownLat!, widget.incident.lastKnownLng!)
                : fallbackLatLng);
        final lineOrder = <LatLng>[
          for (int h = 12; h >= 1; h--) positionForHoursAgo(h),
          currentLatLng,
        ]; // 13 points: 12h, 11h, ..., 1h, current
        final navChipPositions = List<LatLng>.generate(12, (i) => positionForHoursAgo(i + 1)); // 1h..12h for chips

        final center = points.isNotEmpty
            ? points[points.length ~/ 2]
            : currentLatLng;

        final Set<Marker> markers = {};
        for (int h = 1; h <= 12; h++) {
          final pos = navChipPositions[h - 1];
          markers.add(
            Marker(
              markerId: MarkerId('${h}h_ago'),
              position: pos,
              infoWindow: InfoWindow(title: '$h h ago', snippet: ''),
            ),
          );
        }
        markers.add(
          Marker(
            markerId: const MarkerId('current'),
            position: currentLatLng,
            infoWindow: InfoWindow(
              title: 'Current location',
              snippet: hasSubjectCurrent
                  ? (isFallbackCurrent ? 'From sharing (emergency)' : 'Live position')
                  : (hasLastKnown ? 'Last known' : ''),
            ),
          ),
        );

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 12),
              onMapCreated: _controller.complete,
              polylines: lineOrder.length >= 2
                  ? {
                      Polyline(
                        polylineId: const PolylineId('path'),
                        points: lineOrder,
                        color: theme.colorScheme.primary,
                        width: 4,
                      ),
                    }
                  : {},
              markers: markers,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
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
                        if (hasSubjectCurrent)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(isFallbackCurrent ? 'Current (from sharing)' : 'Current location'),
                              onSelected: (_) => _flyTo(LatLng(
                                effectiveCurrentLat!,
                                effectiveCurrentLng!,
                              )),
                              showCheckmark: false,
                            ),
                          ),
                        for (int h = 1; h <= 12; h++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text('${h}h ago'),
                              onSelected: (_) => _flyTo(navChipPositions[h - 1]),
                              showCheckmark: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
