import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../providers/incident_providers.dart';

/// Shows a blocking "I am safe" dialog when the current user has an active incident as subject.
/// Wraps child and checks on build + app resume.
class IncidentPopupGuard extends ConsumerStatefulWidget {
  const IncidentPopupGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncidentPopupGuard> createState() => _IncidentPopupGuardState();
}

class _IncidentPopupGuardState extends ConsumerState<IncidentPopupGuard> with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopup());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeShowPopup();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _maybeShowPopup() async {
    if (_checking) return;
    final user = ref.read(currentUserProvider);
    if (user == null || !mounted) return;

    _checking = true;
    try {
      final incidents = await ref.read(incidentRepositoryProvider).getActiveIncidentsWhereSubject(user.id);
      if (!mounted || incidents.isEmpty) return;

      final incident = incidents.first;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Active incident'),
          content: const Text(
            'You have an active incident. Your emergency contacts have been notified. Tap "I am safe" to resolve it.',
          ),
          actions: [
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(incidentRepositoryProvider).resolveIncident(incident.id, user.id);
                ref.invalidate(incidentRepositoryProvider);
                if (mounted) _maybeShowPopup();
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('I am safe'),
            ),
          ],
        ),
      );
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
