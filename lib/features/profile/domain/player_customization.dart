import 'package:flutter/foundation.dart';

/// Centralized immutable model representing a player's currently equipped cosmetic customizations.
@immutable
class PlayerCustomization {
  final int boardThemeId;
  final int numberStyleId;
  final int avatarId;
  final int victoryEffectId;
  final int profileFrameId;
  final int soundPackId;

  const PlayerCustomization({
    this.boardThemeId = 1, // Classic Cream (free)
    this.numberStyleId = 5, // Classic Numbers (free)
    this.avatarId = 7, // Fun Collection / Default
    this.victoryEffectId = 0, // 0 = Classic Celebration, 8 = Golden Burst
    this.profileFrameId = 0, // 0 = None, 9 = Golden Frame
    this.soundPackId = 10, // Classic Sounds (free)
  });

  /// Key identifying the equipped board theme.
  String get boardThemeKey {
    switch (boardThemeId) {
      case 2:
        return 'lavender';
      case 3:
        return 'midnight';
      case 4:
        return 'neon';
      case 1:
      default:
        return 'classic';
    }
  }

  /// Key identifying the equipped number typography style.
  String get numberStyleKey {
    switch (numberStyleId) {
      case 6:
        return 'bold';
      case 5:
      default:
        return 'classic';
    }
  }

  /// Whether the user has equipped the Golden Frame cosmetic.
  bool get hasGoldenFrame => profileFrameId == 9;

  /// Whether the user has equipped the Golden Burst victory effect.
  bool get hasGoldenBurst => victoryEffectId == 8;

  /// Key identifying the equipped sound pack.
  String get soundPackKey {
    switch (soundPackId) {
      case 11:
        return 'arcade';
      case 12:
        return 'celebration';
      case 10:
      default:
        return 'classic';
    }
  }

  PlayerCustomization copyWith({
    int? boardThemeId,
    int? numberStyleId,
    int? avatarId,
    int? victoryEffectId,
    int? profileFrameId,
    int? soundPackId,
  }) {
    return PlayerCustomization(
      boardThemeId: boardThemeId ?? this.boardThemeId,
      numberStyleId: numberStyleId ?? this.numberStyleId,
      avatarId: avatarId ?? this.avatarId,
      victoryEffectId: victoryEffectId ?? this.victoryEffectId,
      profileFrameId: profileFrameId ?? this.profileFrameId,
      soundPackId: soundPackId ?? this.soundPackId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardThemeId': boardThemeId,
      'numberStyleId': numberStyleId,
      'avatarId': avatarId,
      'victoryEffectId': victoryEffectId,
      'profileFrameId': profileFrameId,
      'soundPackId': soundPackId,
    };
  }

  factory PlayerCustomization.fromMap(Map<String, dynamic> map) {
    return PlayerCustomization(
      boardThemeId: (map['boardThemeId'] as num?)?.toInt() ?? 1,
      numberStyleId: (map['numberStyleId'] as num?)?.toInt() ?? 5,
      avatarId: (map['avatarId'] as num?)?.toInt() ?? 7,
      victoryEffectId: (map['victoryEffectId'] as num?)?.toInt() ?? 0,
      profileFrameId: (map['profileFrameId'] as num?)?.toInt() ?? 0,
      soundPackId: (map['soundPackId'] as num?)?.toInt() ?? 10,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerCustomization &&
          runtimeType == other.runtimeType &&
          boardThemeId == other.boardThemeId &&
          numberStyleId == other.numberStyleId &&
          avatarId == other.avatarId &&
          victoryEffectId == other.victoryEffectId &&
          profileFrameId == other.profileFrameId &&
          soundPackId == other.soundPackId;

  @override
  int get hashCode => Object.hash(
    boardThemeId,
    numberStyleId,
    avatarId,
    victoryEffectId,
    profileFrameId,
    soundPackId,
  );
}
