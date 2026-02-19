class Incident {
  const Incident({
    required this.id,
    required this.userId,
    required this.status,
    required this.trigger,
    this.lastKnownLat,
    this.lastKnownLng,
    this.subjectCurrentLat,
    this.subjectCurrentLng,
    this.subjectLocationUpdatedAt,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String userId;
  final String status; // 'active' | 'resolved'
  final String trigger; // 'curfew_timeout' | 'need_help' | 'manual'
  final double? lastKnownLat;
  final double? lastKnownLng;
  final double? subjectCurrentLat;
  final double? subjectCurrentLng;
  final DateTime? subjectLocationUpdatedAt;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      trigger: json['trigger'] as String,
      lastKnownLat: (json['last_known_lat'] as num?)?.toDouble(),
      lastKnownLng: (json['last_known_lng'] as num?)?.toDouble(),
      subjectCurrentLat: (json['subject_current_lat'] as num?)?.toDouble(),
      subjectCurrentLng: (json['subject_current_lng'] as num?)?.toDouble(),
      subjectLocationUpdatedAt: json['subject_location_updated_at'] != null
          ? DateTime.parse(json['subject_location_updated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
    );
  }

  bool get isActive => status == 'active';
}
