import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';

class AlwaysShareLocation {
  AlwaysShareLocation({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });
  final String userId;
  final double lat;
  final double lng;
  final DateTime updatedAt;
}

class AlwaysShareRepository {
  AlwaysShareRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Returns locations of users that the current user has as always-share contacts (RLS filtered).
  Future<List<AlwaysShareLocation>> getAlwaysShareLocations() async {
    if (_client == null) return [];
    final res = await _client.from('always_share_locations').select();
    return (res as List).map((e) {
      final m = e as Map<String, dynamic>;
      return AlwaysShareLocation(
        userId: m['user_id'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
    }).toList();
  }

  /// Update my current location for always-share (call when I have always-share enabled and app uploads).
  Future<void> updateMyLocation(double lat, double lng) async {
    if (_client == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('always_share_locations').upsert({
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
