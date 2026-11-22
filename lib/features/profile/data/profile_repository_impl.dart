import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_logger.dart';
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

  final Map<String, StreamController<PlayerProfile>> _profileControllers = {};
  final Map<String, RealtimeChannel> _profileChannels = {};

  final Map<String, StreamController<PlayerCareerStats>> _statsControllers = {};
  final Map<String, RealtimeChannel> _statsChannels = {};

  ProfileRepositoryImpl(this._client);

  @override
  Stream<PlayerProfile> watchProfile(String userId) {
    final controller = _profileControllers.putIfAbsent(
      userId,
      () => StreamController<PlayerProfile>.broadcast(),
    );

    getProfile(userId).then((p) {
      if (p != null && !controller.isClosed) {
        controller.add(p);
      }
    });

    if (_client != null && !_profileChannels.containsKey(userId)) {
      try {
        final channel = _client.channel('public:profiles:$userId');
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            final p = await getProfile(userId);
            if (p != null && !controller.isClosed) {
              controller.add(p);
            }
          },
        );
        channel.subscribe();
        _profileChannels[userId] = channel;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'watchProfile_realtime');
      }
    }

    return controller.stream;
  }

  @override
  Stream<PlayerCareerStats> watchCareerStats(String userId) {
    final controller = _statsControllers.putIfAbsent(
      userId,
      () => StreamController<PlayerCareerStats>.broadcast(),
    );

    getCareerStats(userId).then((s) {
      if (!controller.isClosed) {
        controller.add(s);
      }
    });

    if (_client != null && !_statsChannels.containsKey(userId)) {
      try {
        final channel = _client.channel('public:player_statistics:$userId');
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_statistics',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            final s = await getCareerStats(userId);
            if (!controller.isClosed) {
              controller.add(s);
            }
          },
        );
        channel.subscribe();
        _statsChannels[userId] = channel;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'watchCareerStats_realtime');
      }
    }

    return controller.stream;
  }

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

    final ctrl = _profileControllers[profile.id];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(profile);
    }

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

    // Return genuine empty stats for new users with no history
    return const PlayerCareerStats();
  }

  @override
  Future<void> recordMatchResult({
    required String userId,
    required MatchOutcome outcome,
    required int linesClaimed,
    required int callsCount,
    required bool isMultiplayer,
  }) async {
    final current = await getCareerStats(userId);
    final isWin = outcome == MatchOutcome.victory;
    final isLoss = outcome == MatchOutcome.defeat;
    final isDraw = outcome == MatchOutcome.draw;

    final newTotal = current.totalMatches + 1;
    final newWins = current.wins + (isWin ? 1 : 0);
    final newLosses = current.losses + (isLoss ? 1 : 0);
    final newDraws = current.draws + (isDraw ? 1 : 0);
    final newStreak = isWin ? (current.currentStreak + 1) : 0;
    final newBest = newStreak > current.bestStreak
        ? newStreak
        : current.bestStreak;
    final newHighestLines = linesClaimed > current.highestLinesClaimed
        ? linesClaimed
        : current.highestLinesClaimed;
    final newAvgCalls =
        (current.averageCallsPerMatch * current.totalMatches + callsCount) /
        newTotal;

    final record = MatchRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomName: isMultiplayer ? 'Multiplayer Room' : 'Solo vs AI',
      roundNumber: newTotal,
      linesClaimed: linesClaimed,
      callsCount: callsCount,
      outcome: outcome,
      timestamp: DateTime.now(),
    );

    final updated = current.copyWith(
      totalMatches: newTotal,
      wins: newWins,
      losses: newLosses,
      draws: newDraws,
      currentStreak: newStreak,
      bestStreak: newBest,
      highestLinesClaimed: newHighestLines,
      averageCallsPerMatch: double.parse(newAvgCalls.toStringAsFixed(1)),
      recentMatches: [record, ...current.recentMatches].take(10).toList(),
    );

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefStatsPrefix$userId',
      jsonEncode(updated.toJson()),
    );

    final statCtrl = _statsControllers[userId];
    if (statCtrl != null && !statCtrl.isClosed) {
      statCtrl.add(updated);
    }
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
