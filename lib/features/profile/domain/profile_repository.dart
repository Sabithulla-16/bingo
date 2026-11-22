import 'player_career_stats.dart';
import 'player_preferences.dart';
import 'player_profile.dart';

/// Contract for profile data operations.
abstract class ProfileRepository {
  /// Fetches a player profile by unique user ID.
  Future<PlayerProfile?> getProfile(String userId);

  /// Idempotently inserts or updates a player profile.
  Future<PlayerProfile> upsertProfile(PlayerProfile profile);

  /// Updates only the display name of the specified user.
  Future<void> updateDisplayName(String userId, String displayName);

  /// Updates the avatar selection and color theme of the specified user.
  Future<void> updateAvatar(
    String userId, {
    required String avatarId,
    required String avatarColorHex,
  });

  /// Listens to real-time updates of a player profile.
  Stream<PlayerProfile> watchProfile(String userId);

  /// Fetches lifetime career statistics for the specified user.
  Future<PlayerCareerStats> getCareerStats(String userId);

  /// Listens to real-time updates of lifetime career statistics.
  Stream<PlayerCareerStats> watchCareerStats(String userId);

  /// Authoritatively records a verified match result and updates career stats.
  Future<void> recordMatchResult({
    required String userId,
    required MatchOutcome outcome,
    required int linesClaimed,
    required int callsCount,
    required bool isMultiplayer,
  });

  /// Fetches local client preferences (sound, haptics, remember me).
  Future<PlayerPreferences> getPreferences();

  /// Persists updated client preferences to local storage.
  Future<void> savePreferences(PlayerPreferences preferences);
}
