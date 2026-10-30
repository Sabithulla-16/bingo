/// Domain entity representing an authenticated player profile.
class PlayerProfile {
  final String id;
  final String displayName;
  final String email;
  final String avatarId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarId = 'avatar_default',
    required this.createdAt,
    required this.updatedAt,
  });

  PlayerProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Player',
      email: json['email'] as String? ?? '',
      avatarId: json['avatar_id'] as String? ?? 'avatar_default',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'avatar_id': avatarId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
