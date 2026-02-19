import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../data/local/app_database.dart';

/// Uploads last 12h location samples to Supabase user_location_samples.
/// Keeps cloud in sync with local for incident creation and contact visibility.
class UserLocationUploadRepository {
  UserLocationUploadRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Uploads samples to user_location_samples and prunes older than 12h server-side.
  Future<void> uploadLast12Hours({
    required String userId,
    required List<LocationSample> samples,
  }) async {
    if (_client == null || samples.isEmpty) return;

    // Delete samples older than 12h, then upsert all current samples.
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    await _client!
        .from('user_location_samples')
        .delete()
        .eq('user_id', userId)
        .lt('timestamp', cutoff.toIso8601String());

    final rows = samples
        .map((s) => {
              'user_id': userId,
              'lat': s.lat,
              'lng': s.lng,
              'timestamp': s.timestamp.toIso8601String(),
            })
        .toList();
    if (rows.isNotEmpty) {
      await _client!
          .from('user_location_samples')
          .upsert(rows, onConflict: 'user_id,timestamp');
    }
  }
}
