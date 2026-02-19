import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../data/local/app_database.dart';
import '../../features/incidents/domain/incident.dart';

class IncidentRepository {
  IncidentRepository() : _client = AppEnv.supabaseUrl.isNotEmpty ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Returns Layer 1 contact user IDs for a user (for incident creation).
  /// Escalation order (closest first) is applied in Phase 8.
  Future<List<String>> getLayer1ContactUserIds(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('contacts')
        .select('contact_user_id')
        .eq('user_id', userId)
        .eq('layer', 1);
    return (res as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['contact_user_id'] as String)
        .toList();
  }

  /// Creates an incident, uploads last 12h location history, and creates
  /// incident_access for Layer 1 contacts (order determined by escalation logic).
  Future<Incident?> createIncident({
    required String userId,
    required String trigger,
    required double? lastKnownLat,
    required double? lastKnownLng,
    required List<LocationSample> locationSamples,
    required List<String> layer1ContactUserIds,
  }) async {
    if (_client == null) return null;
    final res = await _client.from('incidents').insert({
      'user_id': userId,
      'status': 'active',
      'trigger': trigger,
      'last_known_lat': lastKnownLat,
      'last_known_lng': lastKnownLng,
    }).select().single();
    final incident = Incident.fromJson(Map<String, dynamic>.from(res as Map));
    for (final sample in locationSamples) {
      await _client.from('incident_location_history').insert({
        'incident_id': incident.id,
        'lat': sample.lat,
        'lng': sample.lng,
        'timestamp': sample.timestamp.toIso8601String(),
      });
    }
    for (final contactUserId in layer1ContactUserIds) {
      await _client.from('incident_access').insert({
        'incident_id': incident.id,
        'contact_user_id': contactUserId,
        'layer': 1,
        'notified_at': DateTime.now().toIso8601String(),
      });
    }
    try {
      await _client.functions.invoke('escalate', body: {
        'incident_id': incident.id,
        'layer': 1,
      });
    } catch (_) {
      // Escalate push may fail if FCM not configured
    }
    return incident;
  }

  /// Active incidents visible to current user (subject or in escalation). RLS filtered.
  Future<List<Incident>> getActiveIncidents() async {
    if (_client == null) return [];
    final res = await _client
        .from('incidents')
        .select()
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Incident.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Incident?> getIncident(String incidentId) async {
    if (_client == null) return null;
    final res = await _client
        .from('incidents')
        .select()
        .eq('id', incidentId)
        .maybeSingle();
    if (res == null) return null;
    return Incident.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<Map<String, dynamic>>> getIncidentLocationHistory(String incidentId) async {
    if (_client == null) return [];
    final res = await _client
        .from('incident_location_history')
        .select('lat, lng, timestamp')
        .eq('incident_id', incidentId)
        .order('timestamp', ascending: true);
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  /// Updates subject's current location for an active incident (live tracking during incident).
  Future<void> updateSubjectLocation(String incidentId, double lat, double lng) async {
    if (_client == null) return;
    await _client!.from('incidents').update({
      'subject_current_lat': lat,
      'subject_current_lng': lng,
      'subject_location_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', incidentId);
  }

  /// Returns active incidents where the current user is the subject.
  Future<List<Incident>> getActiveIncidentsWhereSubject(String userId) async {
    if (_client == null) return [];
    final res = await _client!
        .from('incidents')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return (res as List).map((e) => Incident.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> resolveIncident(String incidentId, String resolvedByUserId) async {
    if (_client == null) return;
    await _client.from('incidents').update({
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
      'resolved_by': resolvedByUserId,
    }).eq('id', incidentId);
  }

  Future<void> confirmSafe(String incidentId, String contactUserId) async {
    if (_client == null) return;
    await _client.from('incident_access').update({
      'confirmed_safe_at': DateTime.now().toIso8601String(),
    }).eq('incident_id', incidentId).eq('contact_user_id', contactUserId);
  }

  Future<void> couldNotReach(String incidentId, String contactUserId) async {
    if (_client == null) return;
    await _client.from('incident_access').update({
      'could_not_reach_at': DateTime.now().toIso8601String(),
    }).eq('incident_id', incidentId).eq('contact_user_id', contactUserId);
  }
}
