import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Scaffold(
      appBar: appBarWithBack(context, title: 'Incident'),
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
                  child: _IncidentMap(incidentId: incidentId),
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
    );
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

class _IncidentMap extends ConsumerWidget {
  const _IncidentMap({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(_incidentPathProvider(incidentId));
    return pathAsync.when(
      data: (path) {
        if (path.isEmpty) {
          return const Center(child: Text('No location history'));
        }
        final points = path
            .map((e) => LatLng(
                  (e['lat'] as num).toDouble(),
                  (e['lng'] as num).toDouble(),
                ))
            .toList();
        final center = points.isNotEmpty
            ? points[points.length ~/ 2]
            : const LatLng(40.44, -79.94);
        return GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 12),
          polylines: {
            Polyline(
              polylineId: const PolylineId('path'),
              points: points,
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
