import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../data/repositories/pending_safety_check_repository.dart';
import '../../incidents/providers/incident_providers.dart';
import '../providers/location_providers.dart';

/// Shows an in-app "Are you safe?" dialog with I'm safe / I need help and optional timeout.
/// Call from Safety screen (bell) or when app opens from notification tap.
/// [payload] Optional schedule id for scheduling 10-min recheck on "I'm safe".
/// [timeoutMinutes] If > 0, registers pending safety check and creates incident on timeout.
Future<void> showSafetyCheckDialog(
  BuildContext context, {
  String? payload,
  int timeoutMinutes = 5,
}) async {
  if (!context.mounted) return;
  final ref = ProviderScope.containerOf(context);
  if (timeoutMinutes > 0 && payload == null) {
    final expiresAt = DateTime.now().add(Duration(minutes: timeoutMinutes));
    await PendingSafetyCheckRepository().register(
      scheduleId: null,
      expiresAt: expiresAt,
    );
  }
  final result = await showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SafetyCheckDialogContent(
      payload: payload,
      timeoutMinutes: timeoutMinutes,
    ),
  );
  if (!context.mounted) return;
  if (result == true) {
    await PendingSafetyCheckRepository().respond(scheduleId: payload ?? null);
    ref.read(safetyNotificationServiceProvider).cancelSafetyCheck();
    if (payload != null && payload.isNotEmpty) {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null) {
        ref.read(curfewSchedulerProvider)?.scheduleRecheckIn10Min(userId, payload);
      }
    }
    return;
  }
  if (result == false) {
    await PendingSafetyCheckRepository().respond(scheduleId: payload ?? null);
    context.go('/incidents/create?trigger=need_help');
    return;
  }
  // result == null: dialog dismissed by timeout (handled inside dialog)
}

class _SafetyCheckDialogContent extends ConsumerStatefulWidget {
  const _SafetyCheckDialogContent({
    this.payload,
    required this.timeoutMinutes,
  });

  final String? payload;
  final int timeoutMinutes;

  @override
  ConsumerState<_SafetyCheckDialogContent> createState() => _SafetyCheckDialogContentState();
}

class _SafetyCheckDialogContentState extends ConsumerState<_SafetyCheckDialogContent> {
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.timeoutMinutes > 0) {
      _remainingSeconds = widget.timeoutMinutes * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            _timer?.cancel();
            _triggerTimeout();
          }
        });
      });
    }
  }

  Future<void> _triggerTimeout() async {
    _timer?.cancel();
    final user = ref.read(currentUserProvider);
    if (user == null || !mounted) return;
    await PendingSafetyCheckRepository().respond(scheduleId: widget.payload ?? null);
    final incidentRepo = ref.read(incidentRepositoryProvider);
    final locationRepo = ref.read(locationHistoryRepositoryProvider);
    final samples = await locationRepo.getLast12Hours();
    final layer1Ids = await incidentRepo.getLayer1ContactUserIds(user.id);
    final lat = samples.isNotEmpty ? samples.last.lat : null;
    final lng = samples.isNotEmpty ? samples.last.lng : null;
    final incident = await incidentRepo.createIncident(
      userId: user.id,
      trigger: 'curfew_timeout',
      lastKnownLat: lat,
      lastKnownLng: lng,
      locationSamples: samples,
      layer1ContactUserIds: layer1Ids,
    );
    if (!mounted) return;
    ref.read(safetyNotificationServiceProvider).cancelSafetyCheck();
    if (incident != null && mounted) {
      Navigator.of(context).pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No response in time. Your emergency contacts have been notified.')),
      );
      context.go('/incidents/${incident.id}');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;

    return AlertDialog(
      title: const Text('Are you safe?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please confirm you\'re safe or request help. If you don\'t respond in time, your emergency contacts will be notified.',
          ),
          if (widget.timeoutMinutes > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Time remaining: ${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 8),
              Text('I\'m safe'),
            ],
          ),
        ),
        FilledButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emergency_outlined, size: 20),
              SizedBox(width: 8),
              Text('I need help'),
            ],
          ),
        ),
      ],
    );
  }
}
