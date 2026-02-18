import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
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
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: appBarWithBack(context, title: 'Safety'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Sign in to manage safety settings',
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
      appBar: appBarWithBack(
        context,
        title: 'Safety',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded),
            onPressed: () => _runCurfewCheck(context, user.id),
            tooltip: 'Run curfew check now',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(
            icon: Icons.place_rounded,
            title: 'Safe zones',
            subtitle: 'Places where you\'re considered safe',
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(_safeZonesProvider(user.id));
              return async.when(
                data: (zones) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...zones.map((z) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.home_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 22,
                              ),
                            ),
                            title: Text(z.name),
                            subtitle: Text(
                              '${z.centerLat.toStringAsFixed(4)}, ${z.centerLng.toStringAsFixed(4)} · ${z.radiusMeters.toStringAsFixed(0)} m',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _deleteSafeZone(ref, z),
                              tooltip: 'Remove zone',
                            ),
                          ),
                        )),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => _addSafeZone(context, ref, user.id),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Add safe zone'),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e',
                    style: TextStyle(color: theme.colorScheme.error)),
              );
            },
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            icon: Icons.schedule_rounded,
            title: 'Curfew schedules',
            subtitle: 'When to run "Are you safe?" checks',
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(_curfewSchedulesProvider(user.id));
              return async.when(
                data: (schedules) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...schedules.map((s) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiaryContainer,
                              child: Icon(
                                Icons.nightlight_round,
                                color: theme.colorScheme.onTertiaryContainer,
                                size: 22,
                              ),
                            ),
                            title: Text('${s.timeLocal} (${s.timezone})'),
                            subtitle: Text(
                              'Safe zones: ${s.safeZoneIds.length} · Timeout: ${s.responseTimeoutMinutes} min',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _deleteCurfew(ref, s),
                              tooltip: 'Remove curfew',
                            ),
                          ),
                        )),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => _addCurfew(context, ref, user.id),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Add curfew'),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e',
                    style: TextStyle(color: theme.colorScheme.error)),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
