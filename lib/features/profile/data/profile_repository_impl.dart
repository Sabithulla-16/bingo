import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/player_profile.dart';
import '../domain/profile_repository.dart';

/// Concrete implementation of ProfileRepository backed by Supabase PostgreSQL.
class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient? _client;

  ProfileRepositoryImpl(this._client);

  @override
  Future<PlayerProfile?> getProfile(String userId) async {
    if (_client == null) {
      // Local fallback profile for development
      return PlayerProfile(
        id: userId,
        displayName: 'Guest Player',
        email: 'guest@bingo.app',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return PlayerProfile.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PlayerProfile> upsertProfile(PlayerProfile profile) async {
    if (_client == null) {
      return profile;
    }

    final data = profile.toJson();
    await _client.from('profiles').upsert(data);
    return profile;
  }

  @override
  Future<void> updateDisplayName(String userId, String displayName) async {
    if (_client == null) return;

    await _client
        .from('profiles')
        .update({
          'display_name': displayName,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> updateAvatar(String userId, String avatarId) async {
    if (_client == null) return;

    await _client
        .from('profiles')
        .update({
          'avatar_id': avatarId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }
}
