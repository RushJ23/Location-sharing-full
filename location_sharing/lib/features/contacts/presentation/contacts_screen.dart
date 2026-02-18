import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/app_bar_with_back.dart';
import '../domain/contact.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.invalidate(incomingRequestsProvider(user.id));
        ref.invalidate(contactsProvider(user.id));
      }
    });
  }

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

  Future<void> _showEditContactDialog(
    BuildContext context, {
    required Contact contact,
    required String userId,
  }) async {
    int layer = contact.layer;
    bool isAlwaysShare = contact.isAlwaysShare;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Edit ${contact.contactDisplayName ?? contact.contactUserId}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Layer',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {layer},
                    onSelectionChanged: (v) =>
                        setDialogState(() => layer = v.first),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Always share location',
                              style: Theme.of(ctx).textTheme.titleSmall,
                            ),
                            Text(
                              'They can see your live location on the map',
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isAlwaysShare,
                        onChanged: (v) =>
                            setDialogState(() => isAlwaysShare = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true || !mounted) return;
    await ref.read(contactRepositoryProvider).updateContact(
          contactId: contact.id,
          userId: userId,
          layer: layer,
          isAlwaysShare: isAlwaysShare,
        );
    ref.invalidate(contactsProvider(userId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact updated')),
      );
    }
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
                data: (list) {
                  final pending = list.where((r) => r.isPending).toList();
                  if (pending.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No pending requests',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: pending.map((req) {
                      final displayName = req.fromDisplayName != null &&
                              req.fromDisplayName!.isNotEmpty
                          ? req.fromDisplayName!
                          : 'Unknown';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.secondaryContainer,
                                child: Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'Wants to add you as a contact',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filled(
                                    icon: const Icon(Icons.check_rounded),
                                    onPressed: () => _accept(req),
                                    tooltip: 'Accept',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () => _decline(req),
                                    tooltip: 'Decline',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load requests: $e',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
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
                                if (v == 'edit') {
                                  await _showEditContactDialog(
                                    context,
                                    contact: c,
                                    userId: user.id,
                                  );
                                } else if (v == 'delete') {
                                  await ref
                                      .read(contactRepositoryProvider)
                                      .deleteContact(c.id, user.id);
                                  ref.invalidate(contactsProvider(user.id));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Contact removed')),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded),
                                      SizedBox(width: 12),
                                      Text('Edit layer & sharing'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_remove_rounded),
                                      SizedBox(width: 12),
                                      Text('Remove'),
                                    ],
                                  ),
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
