import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../domain/curfew_check_service.dart';
import '../domain/curfew_schedule.dart';
import '../domain/safe_zone.dart';
import '../providers/location_providers.dart';

/// Ensures location service is on and permission granted, then gets current position.
/// Returns null and shows a message if location is disabled or permission denied.
Future<Position?> _ensureLocationAndGetCurrent(BuildContext context) async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is off. Turn it on in device settings to use your current location.'),
        ),
      );
      await Geolocator.openLocationSettings();
    }
    return null;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission was permanently denied. Open app settings to allow location.'),
        ),
      );
      await openAppSettings();
    }
    return null;
  }
  if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required to use your current position.')),
      );
    }
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get location. Try again or enter coordinates manually.')),
      );
    }
    return null;
  }
}

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
              final zonesAsync = ref.watch(_safeZonesProvider(user.id));
              final async = ref.watch(_curfewSchedulesProvider(user.id));
              return async.when(
                data: (schedules) {
                  final zones = zonesAsync.valueOrNull ?? [];
                  final zoneNames = {for (final z in zones) z.id: z.name};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...schedules.map((s) {
                        final names = s.safeZoneIds
                            .map((id) => zoneNames[id] ?? 'Unknown')
                            .where((n) => n != 'Unknown')
                            .toList();
                        final zoneSummary = names.isEmpty
                            ? 'No zones'
                            : (names.length <= 2 ? names.join(', ') : '${names.length} zones');
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiaryContainer,
                              child: Icon(
                                Icons.nightlight_round,
                                color: theme.colorScheme.onTertiaryContainer,
                                size: 22,
                              ),
                            ),
                            title: Text('${s.timeLocal} ${s.timezone}'),
                            subtitle: Text(
                              '$zoneSummary · Timeout: ${s.responseTimeoutMinutes} min${s.enabled ? '' : ' · Disabled'}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final z = await ref.read(safeZoneRepositoryProvider).getSafeZones(user.id);
                                    if (context.mounted) {
                                      _editCurfew(context, ref, user.id, s, z);
                                    }
                                  },
                                  tooltip: 'Edit curfew',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => _deleteCurfew(ref, s),
                                  tooltip: 'Remove curfew',
                                ),
                              ],
                            ),
                            onTap: () async {
                              final z = await ref.read(safeZoneRepositoryProvider).getSafeZones(user.id);
                              if (context.mounted) {
                                _editCurfew(context, ref, user.id, s, z);
                              }
                            },
                          ),
                        );
                      }),
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
                  );
                },
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
                      final pos = await _ensureLocationAndGetCurrent(ctx);
                      if (pos == null) return;
                      if (ctx.mounted) {
                        latController.text = pos.latitude.toString();
                        lngController.text = pos.longitude.toString();
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
      final pos = await _ensureLocationAndGetCurrent(context);
      if (pos == null) return;
      lat = pos.latitude;
      lng = pos.longitude;
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
    await ref.read(curfewRepositoryProvider).removeSafeZoneFromAllSchedules(zone.userId, zone.id);
    ref.invalidate(_safeZonesProvider(zone.userId));
    ref.invalidate(_curfewSchedulesProvider(zone.userId));
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
    if (!context.mounted) return;
    final result = await _showCurfewEditor(
      context,
      zones: zones,
      existing: null,
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(curfewRepositoryProvider).insertCurfewSchedule(
            userId: userId,
            safeZoneIds: result.safeZoneIds,
            timeLocal: result.timeLocal,
            timezone: result.timezone,
            responseTimeoutMinutes: result.responseTimeoutMinutes,
            enabled: result.enabled,
          );
      if (!context.mounted) return;
      ref.invalidate(_curfewSchedulesProvider(userId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curfew added')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editCurfew(
    BuildContext context,
    WidgetRef ref,
    String userId,
    CurfewSchedule schedule,
    List<SafeZone> zones,
  ) async {
    final result = await _showCurfewEditor(
      context,
      zones: zones,
      existing: schedule,
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(curfewRepositoryProvider).updateCurfewSchedule(
            CurfewSchedule(
              id: schedule.id,
              userId: schedule.userId,
              safeZoneIds: result.safeZoneIds,
              timeLocal: result.timeLocal,
              timezone: result.timezone,
              enabled: result.enabled,
              responseTimeoutMinutes: result.responseTimeoutMinutes,
              createdAt: schedule.createdAt,
              updatedAt: schedule.updatedAt,
            ),
          );
      if (!context.mounted) return;
      ref.invalidate(_curfewSchedulesProvider(userId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curfew updated')));
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

class _CurfewEditorResult {
  const _CurfewEditorResult({
    required this.safeZoneIds,
    required this.timeLocal,
    required this.timezone,
    required this.responseTimeoutMinutes,
    required this.enabled,
  });
  final List<String> safeZoneIds;
  final String timeLocal;
  final String timezone;
  final int responseTimeoutMinutes;
  final bool enabled;
}

Future<_CurfewEditorResult?> _showCurfewEditor(
  BuildContext context, {
  required List<SafeZone> zones,
  CurfewSchedule? existing,
}) async {
  assert(zones.isNotEmpty);
  // Parse existing time "HH:mm" or "23:30:00"
  TimeOfDay initialTime = const TimeOfDay(hour: 23, minute: 30);
  if (existing != null && existing.timeLocal.isNotEmpty) {
    final parts = existing.timeLocal.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        initialTime = TimeOfDay(hour: h, minute: m);
      }
    }
  }
  final selectedIds = <String>{...(existing?.safeZoneIds ?? [])};
  if (existing == null) {
    // New curfew: select all zones by default
    for (final z in zones) {
      selectedIds.add(z.id);
    }
  }
  final timeController = TextEditingController(
    text: '${initialTime.hour.toString().padLeft(2, '0')}:${initialTime.minute.toString().padLeft(2, '0')}',
  );
  const defaultTimezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Toronto',
    'Europe/London',
    'Europe/Paris',
    'Asia/Kolkata',
    'UTC',
  ];
  var initialTz = existing?.timezone ?? 'America/New_York';
  if (!defaultTimezones.contains(initialTz)) initialTz = defaultTimezones.first;
  final selectedTimezoneHolder = [initialTz];
  final timeoutController = TextEditingController(
    text: '${existing?.responseTimeoutMinutes ?? 10}',
  );
  bool enabled = existing?.enabled ?? true;

  final result = await showDialog<_CurfewEditorResult>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add curfew' : 'Edit curfew'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Which safe zones apply?',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...zones.map((z) => CheckboxListTile(
                        value: selectedIds.contains(z.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selectedIds.add(z.id);
                            } else {
                              selectedIds.remove(z.id);
                            }
                          });
                        },
                        title: Text(z.name),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      )),
                  const SizedBox(height: 16),
                  Text(
                    'Be in location by (local time)',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 23:30',
                      helperText: '24-hour format HH:mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(timeController.text.split(':').first) ?? 23,
                          minute: int.tryParse(timeController.text.split(':').elementAtOrNull(1)?.substring(0, 2) ?? '') ?? 30,
                        ),
                      );
                      if (picked != null) {
                        timeController.text =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Timezone (IANA)',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: defaultTimezones.contains(selectedTimezoneHolder[0])
                        ? selectedTimezoneHolder[0]
                        : defaultTimezones.first,
                    decoration: const InputDecoration(
                      hintText: 'e.g. America/New_York',
                    ),
                    items: defaultTimezones
                        .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        selectedTimezoneHolder[0] = v;
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeoutController,
                    decoration: const InputDecoration(
                      labelText: 'Response timeout (minutes)',
                      hintText: 'e.g. 10',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: enabled,
                    onChanged: (v) => setState(() => enabled = v),
                    title: const Text('Enabled'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedIds.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Select at least one safe zone')),
                    );
                    return;
                  }
                  final timeStr = timeController.text.trim();
                  final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr);
                  if (timeMatch == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter time as HH:mm (e.g. 23:30)')),
                    );
                    return;
                  }
                  final hour = int.parse(timeMatch.group(1)!);
                  final minute = int.parse(timeMatch.group(2)!);
                  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a valid time')),
                    );
                    return;
                  }
                  final timeLocal =
                      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                  final timeout = int.tryParse(timeoutController.text);
                  if (timeout == null || timeout < 1 || timeout > 120) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter timeout between 1 and 120 minutes')),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(_CurfewEditorResult(
                    safeZoneIds: selectedIds.toList(),
                    timeLocal: timeLocal,
                    timezone: selectedTimezoneHolder[0],
                    responseTimeoutMinutes: timeout,
                    enabled: enabled,
                  ));
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  return result;
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
