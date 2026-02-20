import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../../../features/safety/providers/location_providers.dart';
import '../providers/incident_providers.dart';

class CreateIncidentScreen extends ConsumerStatefulWidget {
  const CreateIncidentScreen({super.key, this.trigger = 'need_help'});

  final String trigger;

  @override
  ConsumerState<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends ConsumerState<CreateIncidentScreen> {
  bool _created = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createIncident());
  }

  Future<void> _createIncident() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Not signed in');
      return;
    }
    final incidentRepo = ref.read(incidentRepositoryProvider);
    final locationRepo = ref.read(locationHistoryRepositoryProvider);
    final samples = await locationRepo.getLast12Hours();
    final lat = samples.isNotEmpty ? samples.last.lat : null;
    final lng = samples.isNotEmpty ? samples.last.lng : null;
    final incident = await incidentRepo.createIncident(
      userId: user.id,
      trigger: widget.trigger,
      lastKnownLat: lat,
      lastKnownLng: lng,
      locationSamples: samples,
    );
    if (!mounted) return;
    if (incident != null) {
      setState(() => _created = true);
      ref.invalidate(activeIncidentsProvider);
      ref.read(safetyNotificationServiceProvider).cancelSafetyCheck();
      await ref.read(safetyNotificationServiceProvider).showIncidentCreatedConfirmation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident created. Your contacts have been notified.')),
      );
      context.go('/incidents/${incident.id}');
    } else {
      setState(() => _error = 'Could not create incident');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: appBarWithBack(context, title: 'Incident'),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : _created
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Incident created.',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'Creating incident...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
