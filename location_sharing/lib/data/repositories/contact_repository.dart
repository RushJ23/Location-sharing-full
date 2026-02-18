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
        .select()
        .eq('user_id', userId)
        .order('layer')
        .order('created_at', ascending: false);
    final list = res as List;
    if (list.isEmpty) return [];
    final contactIds = list.map((e) => (e as Map)['contact_user_id'] as String).toSet().toList();
    final names = await _getDisplayNames(contactIds);
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final cid = m['contact_user_id'] as String?;
      if (cid != null && names.containsKey(cid)) {
        m['profiles'] = <String, dynamic>{'display_name': names[cid]};
      }
      return Contact.fromJson(m);
    }).toList();
  }

  Future<Map<String, String>> _getDisplayNames(List<String> userIds) async {
    if (_client == null || userIds.isEmpty) return {};
    final res = await _client
        .from('profiles')
        .select('id, display_name')
        .filter('id', 'in', '(${userIds.map((e) => "'$e'").join(',')})');
    final map = <String, String>{};
    for (final row in res as List) {
      final m = row as Map<String, dynamic>;
      final id = m['id'] as String?;
      if (id != null) map[id] = m['display_name'] as String? ?? '';
    }
    return map;
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
