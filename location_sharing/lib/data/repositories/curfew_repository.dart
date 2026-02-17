import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../features/safety/domain/curfew_schedule.dart';

class CurfewRepository {
  CurfewRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  Future<List<CurfewSchedule>> getCurfewSchedules(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('curfew_schedules')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => CurfewSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CurfewSchedule> insertCurfewSchedule({
    required String userId,
    required List<String> safeZoneIds,
    required String timeLocal,
    required String timezone,
    bool enabled = true,
    int responseTimeoutMinutes = 10,
  }) async {
    if (_client == null) throw StateError('Backend not configured');
    final res = await _client.from('curfew_schedules').insert({
      'user_id': userId,
      'safe_zone_ids': safeZoneIds,
      'time_local': timeLocal,
      'timezone': timezone,
      'enabled': enabled,
      'response_timeout_minutes': responseTimeoutMinutes,
    }).select().single();
    return CurfewSchedule.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> updateCurfewSchedule(CurfewSchedule schedule) async {
    if (_client == null) return;
    await _client.from('curfew_schedules').update({
      'safe_zone_ids': schedule.safeZoneIds,
      'time_local': schedule.timeLocal,
      'timezone': schedule.timezone,
      'enabled': schedule.enabled,
      'response_timeout_minutes': schedule.responseTimeoutMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', schedule.id);
  }

  Future<void> deleteCurfewSchedule(String id) async {
    if (_client == null) return;
    await _client.from('curfew_schedules').delete().eq('id', id);
  }
}
