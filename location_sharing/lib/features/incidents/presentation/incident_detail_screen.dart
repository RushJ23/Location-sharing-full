import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../domain/incident.dart';
import '../providers/incident_providers.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentAsync = ref.watch(_incidentProvider(incidentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Incident')),
      body: incidentAsync.when(
        data: (incident) {
          if (incident == null) {
            return const Center(child: Text('Incident not found'));
          }
          final user = ref.watch(currentUserProvider);
          final isSubject = user?.id == incident.userId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Status: ${incident.status}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Trigger: ${incident.trigger}'),
              if (incident.lastKnownLat != null && incident.lastKnownLng != null)
                Text(
                  'Last known: ${incident.lastKnownLat!.toStringAsFixed(4)}, '
                  '${incident.lastKnownLng!.toStringAsFixed(4)}',
                ),
              const SizedBox(height: 24),
              if (incident.isActive && !isSubject) ...[
                const Text('As a contact you can:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _confirmSafe(ref),
                  child: const Text('I confirm they\'re safe'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _couldNotReach(ref),
                  child: const Text('I couldn\'t reach them'),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Location path (last 12h)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: _IncidentMap(incidentId: incidentId),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Home'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
        final center = points.isNotEmpty ? points[points.length ~/ 2] : const LatLng(40.44, -79.94);
        return GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 12),
          polylines: {
            Polyline(
              polylineId: const PolylineId('path'),
              points: points,
              color: Colors.blue,
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