import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../features/contacts/domain/contact_request.dart';

class ContactRequestRepository {
  ContactRequestRepository()
      : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  Future<List<ContactRequest>> getIncoming(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('contact_requests')
        .select()
        .eq('to_user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final list = res as List;
    if (list.isEmpty) return [];
    final fromIds = list.map((e) => (e as Map)['from_user_id'] as String).toSet().toList();
    final names = await _getDisplayNames(fromIds);
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final fid = m['from_user_id'] as String?;
      if (fid != null && names.containsKey(fid)) {
        m['from_profile'] = <String, dynamic>{'display_name': names[fid]};
      }
      return ContactRequest.fromJson(m);
    }).toList();
  }

  Future<List<ContactRequest>> getOutgoing(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('contact_requests')
        .select()
        .eq('from_user_id', userId)
        .order('created_at', ascending: false);
    final list = res as List;
    if (list.isEmpty) return [];
    final toIds = list.map((e) => (e as Map)['to_user_id'] as String).toSet().toList();
    final names = await _getDisplayNames(toIds);
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final tid = m['to_user_id'] as String?;
      if (tid != null && names.containsKey(tid)) {
        m['to_profile'] = <String, dynamic>{'display_name': names[tid]};
      }
      return ContactRequest.fromJson(m);
    }).toList();
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

  Future<ContactRequest?> sendRequest({required String fromUserId, required String toUserId}) async {
    if (_client == null) return null;
    final res = await _client.from('contact_requests').insert({
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'status': 'pending',
    }).select().single();
    return ContactRequest.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Accepts the request. A DB trigger inserts both contact rows (acceptor and sender)
  /// so both users see each other in their contacts.
  Future<void> accept(String requestId, String toUserId) async {
    if (_client == null) return;
    await _client.from('contact_requests').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId).eq('to_user_id', toUserId);
  }

  Future<void> decline(String requestId, String toUserId) async {
    if (_client == null) return;
    await _client.from('contact_requests').update({
      'status': 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId).eq('to_user_id', toUserId);
  }
}
