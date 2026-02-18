import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository([SupabaseClient? client])
      : _client = client;

  final SupabaseClient? _client;

  bool get isAuthenticated => _client?.auth.currentUser != null;
  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ??
      Stream.value(AuthState(AuthChangeEvent.initialSession, null));

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    String? emailRedirectTo,
  }) async {
    if (_client == null) throw StateError('Backend not configured');
    return _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (_client == null) throw StateError('Backend not configured');
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (_client != null) await _client.auth.signOut();
  }
}
