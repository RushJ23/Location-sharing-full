import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../data/repositories/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _phoneController;
  late TextEditingController _schoolController;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _phoneController = TextEditingController();
    _schoolController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  void _fillFromProfile(Profile? p) {
    if (p == null) return;
    _displayNameController.text = p.displayName;
    _phoneController.text = p.phone ?? '';
    _schoolController.text = p.school ?? '';
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            displayName: _displayNameController.text.trim().isEmpty
                ? null
                : _displayNameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            school: _schoolController.text.trim().isEmpty
                ? null
                : _schoolController.text.trim(),
          );
      ref.invalidate(profileProvider(user.id));
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = user != null ? ref.watch(profileProvider(user.id)) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : profileAsync == null
              ? const Center(child: CircularProgressIndicator())
              : profileAsync.when(
                  data: (profile) {
                    if (!_initialized) {
                      _initialized = true;
                      _fillFromProfile(profile);
                      if (profile == null && _displayNameController.text.isEmpty) {
                        _displayNameController.text = user.email ?? '';
                      }
                    }
                    return SafeArea(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            TextFormField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone (optional)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _schoolController,
                              decoration: const InputDecoration(
                                labelText: 'School (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _loading ? null : _save,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => context.go('/'),
                              child: const Text('Back to Home'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
    );
  }
}
