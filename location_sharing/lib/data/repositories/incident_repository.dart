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

  /// Creates an incident and uploads last 12h location history. Layer 1 is added to
  /// incident_access by a DB trigger on INSERT, so contacts see the incident when they
  /// open the app (works for both "I need help" and curfew-triggered incidents).
  Future<Incident?> createIncident({
    required String userId,
    required String trigger,
    required double? lastKnownLat,
    required double? lastKnownLng,
    required List<LocationSample> locationSamples,
  }) async {
    if (_client == null) return null;
    final res = await _client!.from('incidents').insert({
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
    try {
      await _client.functions.invoke('escalate', body: {
        'incident_id': incident.id,
        'layer': 1,
      });
    } catch (_) {
      // Trigger already added Layer 1; escalate used by cron for Layer 2/3
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

  /// Emergency override: when incident has no subject_current_*, returns the subject's
  /// always_share_locations row so the map can show current location (overrides normal
  /// always-share visibility; only allowed for active incidents the caller has access to).
  Future<({double lat, double lng})?> getSubjectFallbackLocationForIncident(String incidentId) async {
    if (_client == null) return null;
    final res = await _client.rpc('get_subject_location_for_incident', params: {'p_incident_id': incidentId});
    final list = res is List ? res : (res != null ? [res] : <dynamic>[]);
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    final lat = (row['lat'] as num?)?.toDouble();
    final lng = (row['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
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

  /// Returns the current user's layer for this incident (1, 2, or 3), or null if not in incident_access.
  Future<int?> getContactLayerForIncident(String incidentId, String contactUserId) async {
    if (_client == null) return null;
    final res = await _client
        .from('incident_access')
        .select('layer')
        .eq('incident_id', incidentId)
        .eq('contact_user_id', contactUserId)
        .maybeSingle();
    if (res == null) return null;
    final layer = res['layer'];
    if (layer is int && layer >= 1 && layer <= 3) return layer;
    return null;
  }

  /// Invokes the escalate Edge Function for the given layer (2 or 3). Used when a contact taps "I couldn't reach them".
  Future<void> invokeEscalation(String incidentId, int layer) async {
    if (_client == null) return;
    try {
      await _client.functions.invoke('escalate', body: {
        'incident_id': incidentId,
        'layer': layer,
      });
    } catch (_) {
      // Escalate may fail if Edge Function not available
    }
  }
}
