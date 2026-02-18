import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../domain/contact_request.dart';
import '../providers/contact_providers.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final results = await ref.read(contactRepositoryProvider).searchProfiles(q);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(String toUserId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(contactRequestRepositoryProvider).sendRequest(
          fromUserId: user.id,
          toUserId: toUserId,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent')));
      setState(() => _searchResults = []);
    }
  }

  Future<void> _accept(ContactRequest req) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(contactRequestRepositoryProvider).accept(req.id, user.id);
    ref.invalidate(incomingRequestsProvider(user.id));
    ref.invalidate(contactsProvider(user.id));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact added')));
  }

  Future<void> _decline(ContactRequest req) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(contactRequestRepositoryProvider).decline(req.id, user.id);
    ref.invalidate(incomingRequestsProvider(user.id));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: appBarWithBack(context, title: 'Contacts'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts_outlined, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Sign in to manage contacts',
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
      appBar: appBarWithBack(context, title: 'Contacts'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by name',
              hintText: 'Find people to add',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded, size: 20),
              label: Text(_searching ? 'Searching...' : 'Search'),
            ),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle(icon: Icons.person_add_rounded, title: 'Search results'),
            const SizedBox(height: 8),
            ..._searchResults.map((p) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        (p['display_name'] as String? ?? '?').isNotEmpty
                            ? ((p['display_name'] as String).substring(0, 1).toUpperCase())
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(p['display_name'] as String? ?? 'Unknown'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _sendRequest(p['id'] as String),
                      child: const Text('Add'),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          _SectionTitle(icon: Icons.mail_rounded, title: 'Incoming requests'),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(incomingRequestsProvider(user.id));
              return async.when(
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No pending requests',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Column(
                        children: list.map((req) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Icon(
                                Icons.person_rounded,
                                color: theme.colorScheme.onSecondaryContainer,
                                size: 22,
                              ),
                            ),
                            title: Text(req.fromDisplayName ?? req.fromUserId),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline_rounded),
                                  onPressed: () => _accept(req),
                                  tooltip: 'Accept',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined),
                                  onPressed: () => _decline(req),
                                  tooltip: 'Decline',
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e',
                    style: TextStyle(color: theme.colorScheme.error)),
              );
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle(icon: Icons.people_rounded, title: 'My contacts'),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(contactsProvider(user.id));
              return async.when(
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No contacts yet. Search to add someone.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Column(
                        children: list.map((c) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                (c.contactDisplayName ?? c.contactUserId)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(c.contactDisplayName ?? c.contactUserId),
                            subtitle: Text(
                              'Layer ${c.layer}${c.isAlwaysShare ? ' · Always share' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (v) async {
                                if (v == 'delete') {
                                  await ref
                                      .read(contactRepositoryProvider)
                                      .deleteContact(c.id, user.id);
                                  ref.invalidate(contactsProvider(user.id));
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove_rounded),
                                        SizedBox(width: 12),
                                        Text('Remove'),
                                      ],
                                    )),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e',
                    style: TextStyle(color: theme.colorScheme.error)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
