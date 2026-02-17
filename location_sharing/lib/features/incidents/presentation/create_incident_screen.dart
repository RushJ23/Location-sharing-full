import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
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
    final layer1Ids = await incidentRepo.getLayer1ContactUserIds(user.id);
    final lat = samples.isNotEmpty ? samples.last.lat : null;
    final lng = samples.isNotEmpty ? samples.last.lng : null;
    final incident = await incidentRepo.createIncident(
      userId: user.id,
      trigger: widget.trigger,
      lastKnownLat: lat,
      lastKnownLng: lng,
      locationSamples: samples,
      layer1ContactUserIds: layer1Ids,
    );
    if (!mounted) return;
    if (incident != null) {
      setState(() => _created = true);
      ref.read(safetyNotificationServiceProvider).cancelSafetyCheck();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Incident')),
      body: Center(
        child: _error != null
            ? Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            : _created
                ? const Text('Incident created.')
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Creating incident...'),
                    ],
                  ),
      ),
    );
  }
}
