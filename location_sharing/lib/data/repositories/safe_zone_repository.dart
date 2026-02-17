import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../features/safety/domain/safe_zone.dart';

class SafeZoneRepository {
  SafeZoneRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  Future<List<SafeZone>> getSafeZones(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('safe_zones')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => SafeZone.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<SafeZone> insertSafeZone({
    required String userId,
    required String name,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) async {
    if (_client == null) throw StateError('Backend not configured');
    final res = await _client.from('safe_zones').insert({
      'user_id': userId,
      'name': name,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'radius_meters': radiusMeters,
    }).select().single();
    return SafeZone.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> updateSafeZone(SafeZone zone) async {
    if (_client == null) return;
    await _client.from('safe_zones').update({
      'name': zone.name,
      'center_lat': zone.centerLat,
      'center_lng': zone.centerLng,
      'radius_meters': zone.radiusMeters,
    }).eq('id', zone.id);
  }

  Future<void> deleteSafeZone(String id) async {
    if (_client == null) return;
    await _client.from('safe_zones').delete().eq('id', id);
  }
}
