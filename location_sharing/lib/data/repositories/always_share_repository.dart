import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';

class AlwaysShareLocation {
  AlwaysShareLocation({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    this.displayName,
  });
  final String userId;
  final double lat;
  final double lng;
  final DateTime updatedAt;
  final String? displayName;
}

class AlwaysShareRepository {
  AlwaysShareRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Returns locations of users that the current user has as always-share contacts.
  /// Fetches our always-share contact IDs first, then gets their locations via RPC.
  Future<List<AlwaysShareLocation>> getAlwaysShareLocations(String userId) async {
    if (_client == null) return [];

    final contactRes = await _client!
        .from('contacts')
        .select('contact_user_id')
        .eq('user_id', userId)
        .eq('is_always_share', true);
    final contactList = contactRes as List? ?? [];
    if (contactList.isEmpty) return [];

    final userIds = contactList
        .map((e) => (e as Map<String, dynamic>)['contact_user_id'] as String)
        .toSet()
        .toList();

    final res = await _client!.rpc(
      'get_always_share_locations_for_users',
      params: {'p_user_ids': userIds},
    );
    final rawList = res is List ? res : (res != null ? [res] : <dynamic>[]);
    if (rawList.isEmpty) return [];
    final list = rawList.map((e) {
      final m = e as Map<String, dynamic>;
      return AlwaysShareLocation(
        userId: m['user_id'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
    }).toList();
    if (list.isEmpty) return list;
    final idsForNames = list.map((e) => e.userId).toSet().toList();
    final names = await _getDisplayNames(idsForNames);
    return list
        .map((loc) => AlwaysShareLocation(
              userId: loc.userId,
              lat: loc.lat,
              lng: loc.lng,
              updatedAt: loc.updatedAt,
              displayName: names[loc.userId],
            ))
        .toList();
  }

  Future<Map<String, String>> _getDisplayNames(List<String> userIds) async {
    if (_client == null || userIds.isEmpty) return {};
    final res = await _client
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final map = <String, String>{};
    for (final row in res as List) {
      final m = row as Map<String, dynamic>;
      final id = m['id'] as String?;
      if (id != null) map[id] = m['display_name'] as String? ?? '';
    }
    return map;
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
