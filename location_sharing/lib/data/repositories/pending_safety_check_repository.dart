import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';

/// Calls RPCs for pending safety checks (server-side timeout).
class PendingSafetyCheckRepository {
  PendingSafetyCheckRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Registers a pending safety check. Server will create incident at [expiresAt] if no response.
  /// [scheduleId] is optional (null for manual trigger).
  Future<String?> register({String? scheduleId, required DateTime expiresAt}) async {
    if (_client == null) return null;
    final res = await _client!.rpc(
      'register_pending_safety_check',
      params: {
        'p_schedule_id': scheduleId,
        'p_expires_at': expiresAt.toIso8601String(),
      },
    );
    return res as String?;
  }

  /// Marks pending safety check as responded (user tapped I'm safe or I need help).
  /// [scheduleId] is optional; if null, marks all pending checks for current user.
  Future<void> respond({String? scheduleId}) async {
    if (_client == null) return;
    await _client!.rpc(
      'respond_to_safety_check',
      params: {'p_schedule_id': scheduleId},
    );
  }
}
