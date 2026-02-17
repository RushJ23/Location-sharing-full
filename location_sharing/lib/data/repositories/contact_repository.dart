import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../features/contacts/domain/contact.dart';

class ContactRepository {
  ContactRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Search profiles by display name (for adding contacts).
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    if (_client == null || query.trim().isEmpty) return [];
    final res = await _client
        .from('profiles')
        .select('id, display_name, avatar_url')
        .ilike('display_name', '%${query.trim()}%')
        .limit(20);
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Contact>> getContacts(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('contacts')
        .select('*, profiles(display_name)')
        .eq('user_id', userId)
        .order('layer')
        .order('created_at', ascending: false);
    return (res as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final p = m['profiles'];
      if (p is List && p.isNotEmpty) m['profiles'] = p.first;
      return Contact.fromJson(m);
    }).toList();
  }

  Future<void> updateContact({
    required String contactId,
    required String userId,
    int? layer,
    bool? isAlwaysShare,
    int? manualPriority,
  }) async {
    if (_client == null) return;
    final updates = <String, dynamic>{};
    if (layer != null) updates['layer'] = layer;
    if (isAlwaysShare != null) updates['is_always_share'] = isAlwaysShare;
    if (manualPriority != null) updates['manual_priority'] = manualPriority;
    if (updates.isEmpty) return;
    await _client.from('contacts').update(updates).eq('id', contactId).eq('user_id', userId);
  }

  Future<void> deleteContact(String contactId, String userId) async {
    if (_client == null) return;
    await _client.from('contacts').delete().eq('id', contactId).eq('user_id', userId);
  }
}
