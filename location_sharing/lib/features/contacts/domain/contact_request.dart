class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.fromDisplayName,
    this.toDisplayName,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String status; // pending | accepted | declined
  final DateTime createdAt;
  final String? fromDisplayName;
  final String? toDisplayName;

  factory ContactRequest.fromJson(Map<String, dynamic> json) {
    return ContactRequest(
      id: json['id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      fromDisplayName: json['from_profile'] != null
          ? (json['from_profile'] as Map<String, dynamic>)['display_name'] as String?
          : null,
      toDisplayName: json['to_profile'] != null
          ? (json['to_profile'] as Map<String, dynamic>)['display_name'] as String?
          : null,
    );
  }

  bool get isPending => status == 'pending';
}
