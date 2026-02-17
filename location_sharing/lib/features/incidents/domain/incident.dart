class Incident {
  const Incident({
    required this.id,
    required this.userId,
    required this.status,
    required this.trigger,
    this.lastKnownLat,
    this.lastKnownLng,
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
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
    );
  }

  bool get isActive => status == 'active';
}
