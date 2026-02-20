import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';

class Profile {
  Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.phone,
    this.school,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? phone;
  final String? school;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      school: json['school'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'school': school,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ProfileRepository {
  ProfileRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  Future<Profile?> getProfile(String userId) async {
    if (AppEnv.supabaseUrl.isEmpty) return null;
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (res == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> upsertProfile(Profile profile) async {
    if (AppEnv.supabaseUrl.isEmpty) return;
    await _client.from('profiles').upsert(
          {
            'id': profile.id,
            'display_name': profile.displayName,
            'avatar_url': profile.avatarUrl,
            'phone': profile.phone,
            'school': profile.school,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'id',
        );
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? phone,
    String? school,
  }) async {
    if (AppEnv.supabaseUrl.isEmpty) return;
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (phone != null) updates['phone'] = phone;
    if (school != null) updates['school'] = school;
    await _client.from('profiles').update(updates).eq('id', userId);
  }
}
