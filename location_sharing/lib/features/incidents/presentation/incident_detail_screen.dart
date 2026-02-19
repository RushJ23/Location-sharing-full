import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
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
    final user = ref.watch(currentUserProvider);
    final isSubject = user?.id == incident?.userId;
    final shouldBlockPop =
        incident != null && incident.isActive && isSubject == true;

    return PopScope(
      canPop: !shouldBlockPop,
      child: Scaffold(
        appBar: appBarWithBack(
          context,
          title: 'Incident',
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
          return ListView(
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
                  onPressed: () => _confirmSafe(ref),
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
              const SizedBox(height: 24),
              Text(
                'Location path (last 12h)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _IncidentMap(incidentId: incidentId, incident: incident),
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
    if (!context.mounted) return;
    context.go('/');
  }

  Future<void> _confirmSafe(WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(incidentRepositoryProvider).confirmSafe(incidentId, user.id);
    await ref.read(incidentRepositoryProvider).resolveIncident(incidentId, user.id);
    ref.invalidate(_incidentProvider(incidentId));
  }

  Future<void> _couldNotReach(WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(incidentRepositoryProvider).couldNotReach(incidentId, user.id);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pathAsync = ref.watch(_incidentPathProvider(widget.incidentId));
    return pathAsync.when(
      data: (path) {
        if (path.isEmpty && widget.incident.subjectCurrentLat == null) {
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
        final center = points.isNotEmpty
            ? points[points.length ~/ 2]
            : (widget.incident.subjectCurrentLat != null && widget.incident.subjectCurrentLng != null
                ? LatLng(widget.incident.subjectCurrentLat!, widget.incident.subjectCurrentLng!)
                : const LatLng(40.44, -79.94));

        final Set<Marker> markers = {};
        if (widget.incident.subjectCurrentLat != null && widget.incident.subjectCurrentLng != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('current'),
              position: LatLng(widget.incident.subjectCurrentLat!, widget.incident.subjectCurrentLng!),
              infoWindow: const InfoWindow(title: 'Current location', snippet: 'Live position'),
            ),
          );
        }

        LatLng? pointForHoursAgo(int hours) {
          if (pointsWithTime.isEmpty) return null;
          final lastTs = pointsWithTime.last.timestamp;
          final targetTs = lastTs.subtract(Duration(hours: hours));
          LatLng? best;
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

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 12),
              onMapCreated: _controller.complete,
              polylines: points.length >= 2
                  ? {
                      Polyline(
                        polylineId: const PolylineId('path'),
                        points: points,
                        color: theme.colorScheme.primary,
                        width: 4,
                      ),
                    }
                  : {},
              markers: markers,
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
                        if (widget.incident.subjectCurrentLat != null &&
                            widget.incident.subjectCurrentLng != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('Current location'),
                              onSelected: (_) => _flyTo(LatLng(
                                widget.incident.subjectCurrentLat!,
                                widget.incident.subjectCurrentLng!,
                              )),
                              showCheckmark: false,
                            ),
                          ),
                        if (pointForHoursAgo(2) != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('2h ago'),
                              onSelected: (_) => _flyTo(pointForHoursAgo(2)!),
                              showCheckmark: false,
                            ),
                          ),
                        if (pointForHoursAgo(6) != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('6h ago'),
                              onSelected: (_) => _flyTo(pointForHoursAgo(6)!),
                              showCheckmark: false,
                            ),
                          ),
                        if (pointForHoursAgo(12) != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('12h ago'),
                              onSelected: (_) => _flyTo(pointForHoursAgo(12)!),
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
