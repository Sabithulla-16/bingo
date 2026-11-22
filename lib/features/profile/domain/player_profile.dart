/// Domain entity representing an authenticated player profile.
class PlayerProfile {
  final String id;
  final String displayName;
  final String email;
  final String avatarId;
  final String avatarColorHex;
  final int chips;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarId = 'avatar_coral',
    this.avatarColorHex = '#FC695C',
    this.chips = 500,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Indicates whether this profile is an anonymous local guest rather than a registered account.
  bool get isGuest => id.startsWith('guest_') || email == 'guest@bingo.app';

  String get shortPlayerId {
    if (id.length <= 8) return '#${id.toUpperCase()}';
    final cleanId = id.replaceAll('-', '').toUpperCase();
    return '#${cleanId.substring(0, 3)}-${cleanId.substring(cleanId.length - 4)}';
  }

  String get formattedMemberSince {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Member since ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  PlayerProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarId,
    String? avatarColorHex,
    int? chips,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
      chips: chips ?? this.chips,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Player',
      email: json['email'] as String? ?? '',
      avatarId: json['avatar_id'] as String? ?? 'avatar_coral',
      avatarColorHex: json['avatar_color_hex'] as String? ?? '#FC695C',
      chips: (json['chips'] as num?)?.toInt() ?? 500,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'avatar_id': avatarId,
      'avatar_color_hex': avatarColorHex,
      'chips': chips,
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
