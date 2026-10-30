import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/player_career_stats.dart';
import '../domain/player_preferences.dart';
import '../domain/player_profile.dart';
import '../domain/profile_repository.dart';

/// Concrete implementation of ProfileRepository backed by Supabase PostgreSQL
/// with local SharedPreferences caching and fallback resilience.
class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient? _client;

  static const String _prefKeyPrefix = 'bingo_profile_';
  static const String _prefStatsPrefix = 'bingo_stats_';
  static const String _prefPreferencesKey = 'bingo_player_preferences';

  ProfileRepositoryImpl(this._client);

  @override
  Future<PlayerProfile?> getProfile(String userId) async {
    // 1. Try Supabase if connected
    if (_client != null) {
      try {
        final response = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          final profile = PlayerProfile.fromJson(response);
          // Cache locally
          await _cacheProfileLocally(profile);
          return profile;
        }
      } catch (_) {
        // Fall back to local cache if network fails
      }
    }

    // 2. Read from local storage
    final local = await _readProfileLocally(userId);
    if (local != null) return local;

    // 3. Fallback default
    return PlayerProfile(
      id: userId,
      displayName: 'Valtry',
      email: 'valtry@bingo.app',
      avatarId: 'avatar_coral',
      avatarColorHex: '#FC695C',
      chips: 500,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<PlayerProfile> upsertProfile(PlayerProfile profile) async {
    // 1. Save locally
    await _cacheProfileLocally(profile);

    // 2. Sync to Supabase if connected
    if (_client != null) {
      try {
        final data = profile.toJson();
        await _client.from('profiles').upsert(data);
      } catch (_) {
        // Offline or connection failure - local cache is preserved
      }
    }

    return profile;
  }

  @override
  Future<void> updateDisplayName(String userId, String displayName) async {
    final existing = await getProfile(userId);
    if (existing != null) {
      final updated = existing.copyWith(
        displayName: displayName,
        updatedAt: DateTime.now(),
      );
      await upsertProfile(updated);
    }
  }

  @override
  Future<void> updateAvatar(
    String userId, {
    required String avatarId,
    required String avatarColorHex,
  }) async {
    final existing = await getProfile(userId);
    if (existing != null) {
      final updated = existing.copyWith(
        avatarId: avatarId,
        avatarColorHex: avatarColorHex,
        updatedAt: DateTime.now(),
      );
      await upsertProfile(updated);
    }
  }

  @override
  Future<PlayerCareerStats> getCareerStats(String userId) async {
    if (_client != null) {
      try {
        final response = await _client
            .from('player_statistics')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null) {
          return PlayerCareerStats.fromJson(response);
        }
      } catch (_) {
        // Fall back to local or sample data
      }
    }

    // Try reading local stats
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefStatsPrefix$userId');
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PlayerCareerStats.fromJson(decoded);
      }
    } catch (_) {}

    // Return sample stats consistent with the Stitch designs
    return PlayerCareerStats.sampleData();
  }

  @override
  Future<PlayerPreferences> getPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefPreferencesKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PlayerPreferences.fromJson(decoded);
      }
    } catch (_) {}

    return const PlayerPreferences();
  }

  @override
  Future<void> savePreferences(PlayerPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefPreferencesKey,
        jsonEncode(preferences.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _cacheProfileLocally(PlayerProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefKeyPrefix${profile.id}',
        jsonEncode(profile.toJson()),
      );
    } catch (_) {}
  }

  Future<PlayerProfile?> _readProfileLocally(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefKeyPrefix$userId');
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PlayerProfile.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
