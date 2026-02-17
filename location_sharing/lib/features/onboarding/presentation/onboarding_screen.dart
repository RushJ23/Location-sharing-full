import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          const Text(
            'Privacy first',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'We don\'t continuously share your location. It stays on your device unless an emergency is triggered.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Next steps',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Allow location (foreground and background) for safety checks.\n'
            '2. Add at least one safe zone (e.g. home).\n'
            '3. Set a curfew time if you want "Are you safe?" checks.\n'
            '4. Add emergency contacts in Layers 1–3.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/safety'),
            child: const Text('Set up safe zones'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Skip to Home'),
          ),
        ],
      ),
    );
  }
}
