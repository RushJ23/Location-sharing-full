import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Sharing')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home'),
            TextButton(
              onPressed: () => context.go('/profile'),
              child: const Text('Profile'),
            ),
            TextButton(
              onPressed: () => context.go('/safety'),
              child: const Text('Safety'),
            ),
            TextButton(
              onPressed: () => context.go('/contacts'),
              child: const Text('Contacts'),
            ),
            TextButton(
              onPressed: () => context.go('/settings'),
              child: const Text('Settings'),
            ),
            TextButton(
              onPressed: () => context.go('/map'),
              child: const Text('Map'),
            ),
            TextButton(
              onPressed: () => context.go('/onboarding'),
              child: const Text('Onboarding'),
            ),
          ],
        ),
      ),
    );
  }
}
