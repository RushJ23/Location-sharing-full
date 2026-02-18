import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/auth/auth_providers.dart';
import '../domain/curfew_check_service.dart';
import '../domain/curfew_schedule.dart';
import '../domain/safe_zone.dart';
import '../providers/location_providers.dart';

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Safety')),
        body: const Center(child: Text('Sign in to manage safety settings')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () => _runCurfewCheck(context, user.id),
            tooltip: 'Run curfew check now',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Safe zones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(_safeZonesProvider(user.id));
              return async.when(
                data: (zones) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...zones.map((z) => ListTile(
                          title: Text(z.name),
                          subtitle: Text(
                            '${z.centerLat.toStringAsFixed(4)}, ${z.centerLng.toStringAsFixed(4)} · ${z.radiusMeters.toStringAsFixed(0)} m',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSafeZone(ref, z),
                          ),
                        )),
                    TextButton.icon(
                      onPressed: () => _addSafeZone(context, ref, user.id),
                      icon: const Icon(Icons.add),
                      label: const Text('Add safe zone'),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Curfew schedules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(_curfewSchedulesProvider(user.id));
              return async.when(
                data: (schedules) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...schedules.map((s) => ListTile(
                          title: Text('${s.timeLocal} (${s.timezone})'),
                          subtitle: Text(
                            'Safe zones: ${s.safeZoneIds.length} · Timeout: ${s.responseTimeoutMinutes} min',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteCurfew(ref, s),
                          ),
                        )),
                    TextButton.icon(
                      onPressed: () => _addCurfew(context, ref, user.id),
                      icon: const Icon(Icons.add),
                      label: const Text('Add curfew'),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runCurfewCheck(BuildContext context, String userId) async {
    final safeZoneRepo = ref.read(safeZoneRepositoryProvider);
    final zones = await safeZoneRepo.getSafeZones(userId);
    if (!context.mounted) return;
    final result = await runCurfewCheck(zones);
    if (!context.mounted) return;
    if (result.insideSafeZone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are in a safe zone')),
      );
    } else {
      await ref.read(safetyNotificationServiceProvider).showSafetyCheckNotification();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safety check notification shown')),
      );
    }
  }

  Future<void> _addSafeZone(BuildContext context, WidgetRef ref, String userId) async {
    final nameController = TextEditingController(text: 'Home');
    final latController = TextEditingController(text: '');
    final lngController = TextEditingController(text: '');
    final radiusController = TextEditingController(text: '200');
    bool useCurrentLocation = true;

    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add safe zone'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Home, Office',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: useCurrentLocation,
                      onChanged: (v) => setState(() => useCurrentLocation = v ?? true),
                      title: const Text('Use my current location'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (!useCurrentLocation) ...[
                      TextField(
                        controller: latController,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: lngController,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: radiusController,
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        hintText: 'e.g. 200',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (useCurrentLocation) {
                      try {
                        final pos = await Geolocator.getCurrentPosition(
                          locationSettings: const LocationSettings(
                            accuracy: LocationAccuracy.medium,
                          ),
                        );
                        latController.text = pos.latitude.toString();
                        lngController.text = pos.longitude.toString();
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Could not get location. Enable location or enter coordinates.')),
                          );
                        }
                        return;
                      }
                    }
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter a name')),
                      );
                      return;
                    }
                    final lat = double.tryParse(latController.text);
                    final lng = double.tryParse(lngController.text);
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter valid latitude and longitude')),
                      );
                      return;
                    }
                    final radius = double.tryParse(radiusController.text);
                    if (radius == null || radius <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter a valid radius in meters')),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !context.mounted) return;

    final name = nameController.text.trim();
    double? lat = double.tryParse(latController.text);
    double? lng = double.tryParse(lngController.text);
    if (lat == null || lng == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get location')),
          );
        }
        return;
      }
    }
    final radius = double.tryParse(radiusController.text) ?? 200.0;

    try {
      await ref.read(safeZoneRepositoryProvider).insertSafeZone(
            userId: userId,
            name: name,
            centerLat: lat,
            centerLng: lng,
            radiusMeters: radius,
          );
      if (!context.mounted) return;
      ref.invalidate(_safeZonesProvider(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe zone added')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteSafeZone(WidgetRef ref, SafeZone zone) async {
    await ref.read(safeZoneRepositoryProvider).deleteSafeZone(zone.id);
    ref.invalidate(_safeZonesProvider(zone.userId));
  }

  Future<void> _addCurfew(BuildContext context, WidgetRef ref, String userId) async {
    final safeZoneRepo = ref.read(safeZoneRepositoryProvider);
    final zones = await safeZoneRepo.getSafeZones(userId);
    if (zones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one safe zone first')),
        );
      }
      return;
    }
    try {
      await ref.read(curfewRepositoryProvider).insertCurfewSchedule(
            userId: userId,
            safeZoneIds: zones.map((z) => z.id).toList(),
            timeLocal: '23:30',
            timezone: 'America/New_York',
          );
      if (!context.mounted) return;
      ref.invalidate(_curfewSchedulesProvider(userId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curfew added')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteCurfew(WidgetRef ref, CurfewSchedule s) async {
    await ref.read(curfewRepositoryProvider).deleteCurfewSchedule(s.id);
    ref.invalidate(_curfewSchedulesProvider(s.userId));
  }
}

final _safeZonesProvider =
    FutureProvider.family<List<SafeZone>, String>((ref, userId) async {
  return ref.watch(safeZoneRepositoryProvider).getSafeZones(userId);
});

final _curfewSchedulesProvider =
    FutureProvider.family<List<CurfewSchedule>, String>((ref, userId) async {
  return ref.watch(curfewRepositoryProvider).getCurfewSchedules(userId);
});
