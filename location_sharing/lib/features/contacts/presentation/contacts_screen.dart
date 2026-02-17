import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
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
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contacts')),
        body: const Center(child: Text('Sign in to manage contacts')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by name',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _searching ? null : _search, child: const Text('Search')),
            ],
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Search results', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._searchResults.map((p) => ListTile(
                  title: Text(p['display_name'] as String? ?? 'Unknown'),
                  trailing: TextButton(
                    onPressed: () => _sendRequest(p['id'] as String),
                    child: const Text('Add'),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          const Text('Incoming requests', style: TextStyle(fontWeight: FontWeight.bold)),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(incomingRequestsProvider(user.id));
              return async.when(
                data: (list) => Column(
                  children: list.map((req) => ListTile(
                    title: Text(req.fromDisplayName ?? req.fromUserId),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _accept(req),
                          child: const Text('Accept'),
                        ),
                        TextButton(
                          onPressed: () => _decline(req),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('My contacts', style: TextStyle(fontWeight: FontWeight.bold)),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(contactsProvider(user.id));
              return async.when(
                data: (list) => Column(
                  children: list.map((c) => ListTile(
                    title: Text(c.contactDisplayName ?? c.contactUserId),
                    subtitle: Text('Layer ${c.layer}${c.isAlwaysShare ? ' · Always share' : ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') {
                          await ref.read(contactRepositoryProvider).deleteContact(c.id, user.id);
                          ref.invalidate(contactsProvider(user.id));
                        }
                      },
                      itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Remove'))],
                    ),
                  )).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            },
          ),
        ],
      ),
    );
  }
}
