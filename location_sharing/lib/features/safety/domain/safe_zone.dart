class SafeZone {
  const SafeZone({
    required this.id,
    required this.userId,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final DateTime createdAt;

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'center_lat': centerLat,
        'center_lng': centerLng,
        'radius_meters': radiusMeters,
        'created_at': createdAt.toIso8601String(),
      };
}
