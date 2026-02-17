import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'We don\'t continuously share your location. It stays on your device unless an emergency is triggered.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Contacts & layers'),
            subtitle: const Text('Manage emergency contacts and always-share'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/contacts'),
          ),
          ListTile(
            title: const Text('Safety'),
            subtitle: const Text('Safe zones and curfew'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/safety'),
          ),
        ],
      ),
    );
  }
}
