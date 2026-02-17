class Contact {
  const Contact({
    required this.id,
    required this.userId,
    required this.contactUserId,
    required this.layer,
    required this.isAlwaysShare,
    this.manualPriority,
    required this.createdAt,
    this.contactDisplayName,
  });

  final String id;
  final String userId;
  final String contactUserId;
  final int layer;
  final bool isAlwaysShare;
  final int? manualPriority;
  final DateTime createdAt;
  final String? contactDisplayName;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      contactUserId: json['contact_user_id'] as String,
      layer: json['layer'] as int,
      isAlwaysShare: json['is_always_share'] as bool? ?? false,
      manualPriority: json['manual_priority'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      contactDisplayName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['display_name'] as String?
          : null,
    );
  }
}
