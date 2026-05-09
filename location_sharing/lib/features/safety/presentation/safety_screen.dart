import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/config/app_env.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../../../shared/utils/places_service.dart';
import '../domain/curfew_check_service.dart';
import '../domain/curfew_schedule.dart';
import '../domain/safe_zone.dart';
import '../providers/location_providers.dart';
import 'safety_check_dialog.dart';

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
                            title: Text('${s.startTime} – ${s.endTime} ${s.timezone}'),
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
      ref.read(safetyNotificationServiceProvider).cancelSafetyCheck();
      if (!context.mounted) return;
      await showSafetyCheckDialog(context, timeoutMinutes: 5);
    }
  }

  Future<void> _addSafeZone(BuildContext context, WidgetRef ref, String userId) async {
    final result = await showDialog<_SafeZoneResult>(
      context: context,
      builder: (ctx) => _AddSafeZoneDialog(placesService: PlacesService(AppEnv.googleMapsApiKey)),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(safeZoneRepositoryProvider).insertSafeZone(
            userId: userId,
            name: result.name,
            centerLat: result.lat,
            centerLng: result.lng,
            radiusMeters: result.radiusMeters,
          );
      if (!context.mounted) return;
      ref.invalidate(_safeZonesProvider(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe zone added')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            startTime: result.startTime,
            endTime: result.endTime,
            timezone: result.timezone,
            responseTimeoutMinutes: result.responseTimeoutMinutes,
            enabled: result.enabled,
          );
      if (!context.mounted) return;
      ref.invalidate(_curfewSchedulesProvider(userId));
      await ref.read(curfewSchedulerProvider)?.rescheduleAllForUser(userId);
      if (!context.mounted) return;
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
              startTime: result.startTime,
              endTime: result.endTime,
              timezone: result.timezone,
              enabled: result.enabled,
              responseTimeoutMinutes: result.responseTimeoutMinutes,
              createdAt: schedule.createdAt,
              updatedAt: schedule.updatedAt,
            ),
          );
      if (!context.mounted) return;
      ref.invalidate(_curfewSchedulesProvider(userId));
      ref.read(curfewSchedulerProvider)?.rescheduleAllForUser(userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curfew updated')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteCurfew(WidgetRef ref, CurfewSchedule s) async {
    await ref.read(curfewRepositoryProvider).deleteCurfewSchedule(s.id);
    ref.invalidate(_curfewSchedulesProvider(s.userId));
    await ref.read(curfewSchedulerProvider)?.cancelForSchedule(s.id);
  }
}

class _CurfewEditorResult {
  const _CurfewEditorResult({
    required this.safeZoneIds,
    required this.startTime,
    required this.endTime,
    required this.timezone,
    required this.responseTimeoutMinutes,
    required this.enabled,
  });
  final List<String> safeZoneIds;
  final String startTime;
  final String endTime;
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
  // Parse start/end "HH:mm" or "23:30:00"
  TimeOfDay parseTime(String s) {
    final parts = s.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return const TimeOfDay(hour: 23, minute: 30);
  }
  TimeOfDay initialStart = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay initialEnd = const TimeOfDay(hour: 23, minute: 59);
  if (existing != null) {
    if (existing.startTime.isNotEmpty) initialStart = parseTime(existing.startTime);
    if (existing.endTime.isNotEmpty) initialEnd = parseTime(existing.endTime);
  }
  final selectedIds = <String>{...(existing?.safeZoneIds ?? [])};
  if (existing == null) {
    for (final z in zones) selectedIds.add(z.id);
  }
  final startTimeController = TextEditingController(
    text: '${initialStart.hour.toString().padLeft(2, '0')}:${initialStart.minute.toString().padLeft(2, '0')}',
  );
  final endTimeController = TextEditingController(
    text: '${initialEnd.hour.toString().padLeft(2, '0')}:${initialEnd.minute.toString().padLeft(2, '0')}',
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
                    'Start time (be in safe zone by)',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startTimeController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 22:00',
                      helperText: '24-hour HH:mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onTap: () async {
                      final parts = startTimeController.text.split(':');
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(parts.first) ?? 22,
                          minute: int.tryParse(parts.elementAtOrNull(1)?.substring(0, 2) ?? '') ?? 0,
                        ),
                      );
                      if (picked != null) {
                        startTimeController.text =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'End time (stop checking after)',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endTimeController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 06:00',
                      helperText: '24-hour HH:mm (can be next day)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onTap: () async {
                      final parts = endTimeController.text.split(':');
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(parts.first) ?? 6,
                          minute: int.tryParse(parts.elementAtOrNull(1)?.substring(0, 2) ?? '') ?? 0,
                        ),
                      );
                      if (picked != null) {
                        endTimeController.text =
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
                  String parseAndValidateTime(TextEditingController c, String label) {
                    final s = c.text.trim();
                    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
                    if (m == null) return '';
                    final h = int.parse(m.group(1)!);
                    final min = int.parse(m.group(2)!);
                    if (h < 0 || h > 23 || min < 0 || min > 59) return '';
                    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
                  }
                  final startStr = parseAndValidateTime(startTimeController, 'Start');
                  final endStr = parseAndValidateTime(endTimeController, 'End');
                  if (startStr.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter start time as HH:mm')),
                    );
                    return;
                  }
                  if (endStr.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter end time as HH:mm')),
                    );
                    return;
                  }
                  final timeout = int.tryParse(timeoutController.text);
                  if (timeout == null || timeout < 1 || timeout > 120) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter timeout between 1 and 120 minutes')),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(_CurfewEditorResult(
                    safeZoneIds: selectedIds.toList(),
                    startTime: startStr,
                    endTime: endStr,
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

// ---------------------------------------------------------------------------
// Add safe zone dialog with Places search
// ---------------------------------------------------------------------------

class _SafeZoneResult {
  const _SafeZoneResult({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
}

class _AddSafeZoneDialog extends StatefulWidget {
  const _AddSafeZoneDialog({required this.placesService});
  final PlacesService placesService;

  @override
  State<_AddSafeZoneDialog> createState() => _AddSafeZoneDialogState();
}

class _AddSafeZoneDialogState extends State<_AddSafeZoneDialog> {
  final _nameController = TextEditingController(text: 'Home');
  final _searchController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');

  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  bool _locationMode = true; // true = current location, false = place search
  double? _lat;
  double? _lng;
  Timer? _debounce;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _radiusController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await widget.placesService.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _suggestions = [];
      _searching = true;
      _searchController.text = suggestion.description;
    });
    final details = await widget.placesService.getDetails(suggestion.placeId);
    if (!mounted) return;
    if (details == null) {
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load place details. Try again.')),
      );
      return;
    }
    setState(() {
      _lat = details.lat;
      _lng = details.lng;
      _searching = false;
      if (_nameController.text.trim() == 'Home' || _nameController.text.trim().isEmpty) {
        _nameController.text = details.name;
      }
    });
  }

  Future<void> _useCurrentLocation(BuildContext context) async {
    setState(() => _searching = true);
    final pos = await _ensureLocationAndGetCurrent(context);
    if (!mounted) return;
    setState(() {
      _lat = pos?.latitude;
      _lng = pos?.longitude;
      _searching = false;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for this safe zone')),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a place or use your current location')),
      );
      return;
    }
    final radius = double.tryParse(_radiusController.text);
    if (radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid radius in meters')),
      );
      return;
    }
    Navigator.of(context).pop(_SafeZoneResult(
      name: name,
      lat: _lat!,
      lng: _lng!,
      radiusMeters: radius,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = _lat != null && _lng != null;

    return AlertDialog(
      title: const Text('Add safe zone'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Home, School, Work',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text('Location', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Current location'), icon: Icon(Icons.my_location_rounded)),
                ButtonSegment(value: false, label: Text('Search place'), icon: Icon(Icons.search_rounded)),
              ],
              selected: {_locationMode},
              onSelectionChanged: (v) => setState(() {
                _locationMode = v.first;
                _suggestions = [];
                _lat = null;
                _lng = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_locationMode) ...[
              FilledButton.tonal(
                onPressed: _searching ? null : () => _useCurrentLocation(context),
                child: _searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Use my current location'),
              ),
              if (hasLocation)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for a place…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _suggestions.map((s) {
                      return InkWell(
                        onTap: () => _selectSuggestion(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.place_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s.description, style: theme.textTheme.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (hasLocation && _suggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _searchController.text,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              decoration: const InputDecoration(
                labelText: 'Radius (meters)',
                hintText: 'e.g. 200',
                helperText: 'How far from the center counts as "safe"',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

final _safeZonesProvider =
    FutureProvider.family<List<SafeZone>, String>((ref, userId) async {
  return ref.watch(safeZoneRepositoryProvider).getSafeZones(userId);
});

final _curfewSchedulesProvider =
    FutureProvider.family<List<CurfewSchedule>, String>((ref, userId) async {
  return ref.watch(curfewRepositoryProvider).getCurfewSchedules(userId);
});
