import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_logger.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/player_career_stats.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/achievement.dart';

abstract class AchievementsRepository {
  Future<List<Achievement>> getAchievements();
  Future<int> claimAchievement(String achievementId);
  Future<void> updateProgress(String achievementId, int newProgress);
  Future<void> evaluateFromStats(
    PlayerCareerStats stats, {
    required bool isMultiplayer,
    required bool isVictory,
  });
  Stream<List<Achievement>> watchAchievements();
}

class AchievementsRepositoryImpl implements AchievementsRepository {
  final SupabaseClient? _supabase;
  final AuthRepository _authRepo;
  final ProfileRepository _profileRepo;

  static const String _prefAchievementsKey = 'bingo_player_achievements';

  final _achievementsController =
      StreamController<List<Achievement>>.broadcast();
  List<Achievement> _cached = Achievement.standardList;
  RealtimeChannel? _achievementsChannel;
  StreamSubscription<PlayerCareerStats>? _statsSub;

  AchievementsRepositoryImpl({
    SupabaseClient? supabase,
    required AuthRepository authRepo,
    required ProfileRepository profileRepo,
  }) : _supabase = supabase,
       _authRepo = authRepo,
       _profileRepo = profileRepo {
    _loadState();
    _subscribeRealtime();
    _statsSub = _profileRepo.watchCareerStats(_userId).listen((stats) {
      evaluateFromStats(stats, isMultiplayer: true, isVictory: stats.wins > 0);
    });
  }

  void _subscribeRealtime() {
    if (_isOnline && _achievementsChannel == null) {
      try {
        final channel = _supabase!.channel('public:player_achievements:$_userId');
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_achievements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (payload) async {
            await _loadState();
          },
        );
        channel.subscribe();
        _achievementsChannel = channel;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'Achievements_subscribeRealtime');
      }
    }
  }

  String get _userId => _authRepo.currentUserId ?? 'guest';
  bool get _isOnline => _supabase != null && _supabase.auth.currentUser != null;

  Future<void> _loadState() async {
    try {
      final mapState = <String, Map<String, dynamic>>{};

      if (_isOnline) {
        try {
          final res = await _supabase!
              .from('player_achievements')
              .select()
              .eq('user_id', _userId);

          for (final row in res as List) {
            final achId = row['achievement_id'] as String;
            mapState[achId] = {
              'progress': (row['progress'] as num?)?.toInt() ?? 0,
              'is_unlocked': row['is_unlocked'] as bool? ?? false,
              'is_claimed': row['is_claimed'] as bool? ?? false,
            };
          }
        } catch (e, st) {
          ErrorLogger.logUnhandled(
            e,
            st,
            source: 'AchievementsRepositoryImpl._loadState',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final localRaw = prefs.getString('${_prefAchievementsKey}_$_userId');
      if (localRaw != null) {
        final decoded = jsonDecode(localRaw) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          final localData = Map<String, dynamic>.from(val as Map);
          if (mapState.containsKey(key)) {
            final serverData = mapState[key]!;
            final isClaimed = (serverData['is_claimed'] == true) ||
                (localData['is_claimed'] == true);
            final serverProg = (serverData['progress'] as num?)?.toInt() ?? 0;
            final localProg = (localData['progress'] as num?)?.toInt() ?? 0;
            final isUnlocked = isClaimed ||
                (serverData['is_unlocked'] == true) ||
                (localData['is_unlocked'] == true);
            mapState[key] = {
              'progress': serverProg > localProg ? serverProg : localProg,
              'is_unlocked': isUnlocked,
              'is_claimed': isClaimed,
            };
          } else {
            mapState[key] = localData;
          }
        });
      }

      _cached = Achievement.standardList.map((item) {
        final saved = mapState[item.id];
        if (saved != null) {
          final isClaimed = saved['is_claimed'] as bool? ?? false;
          final isUnlocked = saved['is_unlocked'] as bool? ?? false;
          final prog = (saved['progress'] as num?)?.toInt() ?? item.current;

          AchievementStatus status;
          if (isClaimed) {
            status = AchievementStatus.claimed;
          } else if (isUnlocked || prog >= item.target) {
            status = AchievementStatus.ready;
          } else if (prog > 0) {
            status = AchievementStatus.inProgress;
          } else {
            status = AchievementStatus.locked;
          }

          return item.copyWith(current: prog, status: status);
        }
        return item;
      }).toList();

      _achievementsController.add(Achievement.sortList(_cached));
    } catch (_) {}
  }

  @override
  Stream<List<Achievement>> watchAchievements() {
    scheduleMicrotask(() {
      if (!_achievementsController.isClosed) {
        _achievementsController.add(Achievement.sortList(_cached));
      }
    });
    return _achievementsController.stream;
  }

  @override
  Future<List<Achievement>> getAchievements() async {
    await _loadState();
    return Achievement.sortList(_cached);
  }

  @override
  Future<int> claimAchievement(String achievementId) async {
    final item = _cached.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw StateError('Achievement $achievementId not found'),
    );

    if (item.status.isClaimed) {
      throw StateError('This achievement reward has already been claimed.');
    }
    if (!item.status.isReady) {
      throw StateError(
        'This achievement requirement has not been completed yet.',
      );
    }

    final reward = item.rewardChips;

    if (_isOnline) {
      try {
        await _supabase!.rpc(
          'rpc_claim_achievement',
          params: {
            'p_achievement_id': achievementId,
            'p_reward_amount': reward,
          },
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'claimAchievement_supabase');
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('already claimed') ||
            errorMsg.contains('duplicate')) {
          _cached = _cached.map((a) {
            if (a.id == achievementId) {
              return a.copyWith(status: AchievementStatus.claimed);
            }
            return a;
          }).toList();
          _achievementsController.add(Achievement.sortList(_cached));
          final prefs = await SharedPreferences.getInstance();
          final localRaw = prefs.getString('${_prefAchievementsKey}_$_userId');
          final Map<String, dynamic> stateMap = localRaw != null
              ? Map<String, dynamic>.from(jsonDecode(localRaw) as Map)
              : {};
          stateMap[achievementId] = {
            'progress': item.target,
            'is_unlocked': true,
            'is_claimed': true,
          };
          await prefs.setString(
            '${_prefAchievementsKey}_$_userId',
            jsonEncode(stateMap),
          );
          return reward;
        }
        rethrow;
      }
    }

    // Credit profile chips locally ONLY if offline.
    // When online, rpc_claim_achievement atomically credited chips in Supabase.
    if (!_isOnline) {
      final profile = await _profileRepo.getProfile(_userId);
      if (profile != null) {
        final updatedChips = profile.chips + reward;
        await _profileRepo.upsertProfile(profile.copyWith(chips: updatedChips));
      }
    }

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString('${_prefAchievementsKey}_$_userId');
    final Map<String, dynamic> stateMap = localRaw != null
        ? Map<String, dynamic>.from(jsonDecode(localRaw) as Map)
        : {};

    stateMap[achievementId] = {
      'progress': item.target,
      'is_unlocked': true,
      'is_claimed': true,
    };
    await prefs.setString(
      '${_prefAchievementsKey}_$_userId',
      jsonEncode(stateMap),
    );

    // Update memory
    _cached = _cached.map((a) {
      if (a.id == achievementId) {
        return a.copyWith(status: AchievementStatus.claimed);
      }
      return a;
    }).toList();

    _achievementsController.add(Achievement.sortList(_cached));
    return reward;
  }

  @override
  Future<void> updateProgress(String achievementId, int newProgress) async {
    final item = _cached.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw StateError('Achievement $achievementId not found'),
    );

    if (item.status.isClaimed) return;

    // Progress is monotonically non-decreasing
    final effectiveProgress =
        newProgress > item.current ? newProgress : item.current;

    AchievementStatus newStatus = item.status;
    if (effectiveProgress >= item.target) {
      newStatus = AchievementStatus.ready;
    } else if (effectiveProgress > 0) {
      newStatus = AchievementStatus.inProgress;
    }

    final updated = item.copyWith(
      current: effectiveProgress.clamp(0, item.target),
      status: newStatus,
    );

    _cached = _cached.map((a) => a.id == achievementId ? updated : a).toList();
    _achievementsController.add(Achievement.sortList(_cached));

    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString('${_prefAchievementsKey}_$_userId');
    final Map<String, dynamic> stateMap = localRaw != null
        ? Map<String, dynamic>.from(jsonDecode(localRaw) as Map)
        : {};

    final existing = stateMap[achievementId] as Map<String, dynamic>?;
    final bool wasClaimed = existing?['is_claimed'] as bool? ?? false;

    stateMap[achievementId] = {
      'progress': updated.current,
      'is_unlocked': wasClaimed || updated.status.isReady,
      'is_claimed': wasClaimed,
    };
    await prefs.setString(
      '${_prefAchievementsKey}_$_userId',
      jsonEncode(stateMap),
    );

    if (_isOnline) {
      try {
        await _supabase!.from('player_achievements').upsert({
          'user_id': _userId,
          'achievement_id': achievementId,
          'progress': updated.current,
          'is_unlocked': wasClaimed || updated.status.isReady,
          'is_claimed': wasClaimed,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'updateProgress_supabase');
      }
    }
  }

  @override
  Future<void> evaluateFromStats(
    PlayerCareerStats stats, {
    required bool isMultiplayer,
    required bool isVictory,
  }) async {
    if (stats.totalMatches >= 1) {
      await updateProgress('card-first-steps', 1);
      await updateProgress('card-getting-started', stats.totalMatches);
      await updateProgress('card-number-master', stats.totalMatches);
      if (isMultiplayer) {
        await updateProgress('card-social-player', 1);
        await updateProgress('card-room-regular', stats.totalMatches);
      }
    }
    if (stats.wins >= 1) {
      await updateProgress('card-first-bingo', 1);
      await updateProgress('card-bingo-champion', stats.wins);
      if (isMultiplayer && isVictory) {
        await updateProgress('card-room-champion', stats.wins);
      }
    }

    final streak =
        stats.bestStreak > 0 ? stats.bestStreak : stats.currentStreak;
    if (streak > 0) {
      await updateProgress('card-winning-streak', streak);
    }
  }
  void dispose() {
    _statsSub?.cancel();
    _achievementsChannel?.unsubscribe();
    _achievementsController.close();
  }
}

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  final repo = AchievementsRepositoryImpl(
    supabase: supabase,
    authRepo: authRepo,
    profileRepo: profileRepo,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final achievementsListProvider = StreamProvider<List<Achievement>>((ref) async* {
  final repo = ref.watch(achievementsRepositoryProvider);
  yield await repo.getAchievements();
  yield* repo.watchAchievements();
});
