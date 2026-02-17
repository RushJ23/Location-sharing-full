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
        .select('*, from_profile:profiles!from_user_id(display_name)')
        .eq('to_user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => ContactRequest.fromJson(_flattenProfile(e as Map, 'from_profile')))
        .toList();
  }

  Future<List<ContactRequest>> getOutgoing(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('contact_requests')
        .select('*, to_profile:profiles!to_user_id(display_name)')
        .eq('from_user_id', userId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => ContactRequest.fromJson(_flattenProfile(e as Map, 'to_profile')))
        .toList();
  }

  Map<String, dynamic> _flattenProfile(Map e, String key) {
    final m = Map<String, dynamic>.from(e);
    final p = m[key];
    if (p is List && p.isNotEmpty) {
      m[key] = p.first;
    } else if (p is Map) {
      m[key] = p;
    }
    return m;
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

  Future<void> accept(String requestId, String toUserId) async {
    if (_client == null) return;
    final req = await _client
        .from('contact_requests')
        .select()
        .eq('id', requestId)
        .eq('to_user_id', toUserId)
        .single();
    final r = Map<String, dynamic>.from(req as Map);
    final fromUserId = r['from_user_id'] as String;
    await _client.from('contact_requests').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
    await _client.from('contacts').insert([
      {'user_id': toUserId, 'contact_user_id': fromUserId, 'layer': 1},
      {'user_id': fromUserId, 'contact_user_id': toUserId, 'layer': 1},
    ]);
  }

  Future<void> decline(String requestId, String toUserId) async {
    if (_client == null) return;
    await _client
        .from('contact_requests')
        .update({'status': 'declined'})
        .eq('id', requestId)
        .eq('to_user_id', toUserId);
  }
}
