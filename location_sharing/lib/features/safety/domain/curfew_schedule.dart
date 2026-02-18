class CurfewSchedule {
  const CurfewSchedule({
    required this.id,
    required this.userId,
    required this.safeZoneIds,
    required this.startTime,
    required this.endTime,
    required this.timezone,
    required this.enabled,
    required this.responseTimeoutMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final List<String> safeZoneIds;
  /// Start of curfew window (user should be in safe zone by this time). "HH:mm" or "HH:mm:ss".
  final String startTime;
  /// End of curfew window; after this time we stop checking. "HH:mm" or "HH:mm:ss".
  final String endTime;
  final String timezone; // IANA e.g. America/New_York
  final bool enabled;
  final int responseTimeoutMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// For backward compatibility with UI that used single "time" display.
  String get timeLocal => startTime;

  factory CurfewSchedule.fromJson(Map<String, dynamic> json) {
    final ids = json['safe_zone_ids'] as List<dynamic>?;
    final start = json['start_time'] ?? json['time_local'];
    final end = json['end_time'];
    return CurfewSchedule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      safeZoneIds: ids?.map((e) => e.toString()).toList() ?? [],
      startTime: _timeToString(start),
      endTime: end != null ? _timeToString(end) : _timeToString(start),
      timezone: json['timezone'] as String,
      enabled: json['enabled'] as bool? ?? true,
      responseTimeoutMinutes: json['response_timeout_minutes'] as int? ?? 10,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static String _timeToString(dynamic value) {
    if (value == null) return '23:59';
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'safe_zone_ids': safeZoneIds,
        'start_time': startTime,
        'end_time': endTime,
        'timezone': timezone,
        'enabled': enabled,
        'response_timeout_minutes': responseTimeoutMinutes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
