/// Local player preferences for audio, haptics, and session persistence.
class PlayerPreferences {
  final bool soundEffectsEnabled;
  final bool hapticsEnabled;
  final bool rememberMe;

  const PlayerPreferences({
    this.soundEffectsEnabled = true,
    this.hapticsEnabled = true,
    this.rememberMe = true,
  });

  PlayerPreferences copyWith({
    bool? soundEffectsEnabled,
    bool? hapticsEnabled,
    bool? rememberMe,
  }) {
    return PlayerPreferences(
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }

  factory PlayerPreferences.fromJson(Map<String, dynamic> json) {
    return PlayerPreferences(
      soundEffectsEnabled: json['sound_effects'] as bool? ?? true,
      hapticsEnabled: json['haptics'] as bool? ?? true,
      rememberMe: json['remember_me'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sound_effects': soundEffectsEnabled,
      'haptics': hapticsEnabled,
      'remember_me': rememberMe,
    };
  }
}
