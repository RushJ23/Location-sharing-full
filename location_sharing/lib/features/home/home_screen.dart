import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../incidents/providers/incident_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Sharing'),
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Text(
              'Stay safe, stay connected',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            const _ActiveIncidentsCard(),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.person_rounded,
              iconColor: colorScheme.primary,
              title: 'Profile',
              subtitle: 'Name, phone, school',
              onTap: () => context.go('/profile'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF059669),
              title: 'Safety',
              subtitle: 'Safe zones & curfew',
              onTap: () => context.go('/safety'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.contacts_rounded,
              iconColor: const Color(0xFF0891B2),
              title: 'Contacts',
              subtitle: 'Emergency contacts & layers',
              onTap: () => context.go('/contacts'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.map_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: 'Map',
              subtitle: 'View shared locations',
              onTap: () => context.go('/map'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.settings_rounded,
              iconColor: colorScheme.onSurfaceVariant,
              title: 'Settings',
              subtitle: 'Privacy & preferences',
              onTap: () => context.go('/settings'),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.go('/onboarding'),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              label: const Text('How it works'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveIncidentsCard extends ConsumerWidget {
  const _ActiveIncidentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final incidentsAsync = ref.watch(activeIncidentsProvider);
    return incidentsAsync.when(
      data: (incidents) {
        if (incidents.isEmpty) return const SizedBox.shrink();
        final count = incidents.length;
        return Material(
          color: theme.colorScheme.errorContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/map'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count == 1 ? '1 active incident' : '$count active incidents',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to view on map',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
