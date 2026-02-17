class CurfewSchedule {
  const CurfewSchedule({
    required this.id,
    required this.userId,
    required this.safeZoneIds,
    required this.timeLocal,
    required this.timezone,
    required this.enabled,
    required this.responseTimeoutMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final List<String> safeZoneIds;
  final String timeLocal; // "HH:mm"
  final String timezone; // IANA e.g. America/New_York
  final bool enabled;
  final int responseTimeoutMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CurfewSchedule.fromJson(Map<String, dynamic> json) {
    final ids = json['safe_zone_ids'] as List<dynamic>?;
    return CurfewSchedule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      safeZoneIds: ids?.map((e) => e.toString()).toList() ?? [],
      timeLocal: json['time_local'] as String,
      timezone: json['timezone'] as String,
      enabled: json['enabled'] as bool? ?? true,
      responseTimeoutMinutes: json['response_timeout_minutes'] as int? ?? 10,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'safe_zone_ids': safeZoneIds,
        'time_local': timeLocal,
        'timezone': timezone,
        'enabled': enabled,
        'response_timeout_minutes': responseTimeoutMinutes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
