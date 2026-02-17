import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import '../config/app_env.dart';
import '../../data/repositories/profile_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;
  return AuthRepository(client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  if (AppEnv.supabaseUrl.isEmpty) {
    return Stream.value(AuthState(AuthChangeEvent.initialSession, null));
  }
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session?.user;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileProvider = FutureProvider.family<Profile?, String>((ref, userId) async {
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});
