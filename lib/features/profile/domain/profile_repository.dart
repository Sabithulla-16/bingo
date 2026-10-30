import 'player_profile.dart';

/// Contract for fetching and updating player profile data.
abstract class ProfileRepository {
  Future<PlayerProfile?> getProfile(String userId);
  Future<PlayerProfile> upsertProfile(PlayerProfile profile);
  Future<void> updateDisplayName(String userId, String displayName);
  Future<void> updateAvatar(String userId, String avatarId);
}
