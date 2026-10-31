import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_logger.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/achievement.dart';

abstract class AchievementsRepository {
  Future<List<Achievement>> getAchievements();
  Future<int> claimAchievement(String achievementId);
  Future<void> updateProgress(String achievementId, int newProgress);
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

  AchievementsRepositoryImpl({
    SupabaseClient? supabase,
    required AuthRepository authRepo,
    required ProfileRepository profileRepo,
  }) : _supabase = supabase,
       _authRepo = authRepo,
       _profileRepo = profileRepo {
    _loadState();
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
          mapState[key] = Map<String, dynamic>.from(val as Map);
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
  Stream<List<Achievement>> watchAchievements() =>
      _achievementsController.stream;

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
      }
    }

    // Credit profile chips
    final profile = await _profileRepo.getProfile(_userId);
    if (profile != null) {
      final updatedChips = profile.chips + reward;
      await _profileRepo.upsertProfile(profile.copyWith(chips: updatedChips));
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

    AchievementStatus newStatus = item.status;
    if (newProgress >= item.target) {
      newStatus = AchievementStatus.ready;
    } else if (newProgress > 0) {
      newStatus = AchievementStatus.inProgress;
    }

    final updated = item.copyWith(
      current: newProgress.clamp(0, item.target),
      status: newStatus,
    );

    _cached = _cached.map((a) => a.id == achievementId ? updated : a).toList();
    _achievementsController.add(Achievement.sortList(_cached));

    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString('${_prefAchievementsKey}_$_userId');
    final Map<String, dynamic> stateMap = localRaw != null
        ? Map<String, dynamic>.from(jsonDecode(localRaw) as Map)
        : {};

    stateMap[achievementId] = {
      'progress': updated.current,
      'is_unlocked': updated.status.isReady,
      'is_claimed': false,
    };
    await prefs.setString(
      '${_prefAchievementsKey}_$_userId',
      jsonEncode(stateMap),
    );
  }
}

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  return AchievementsRepositoryImpl(
    supabase: supabase,
    authRepo: authRepo,
    profileRepo: profileRepo,
  );
});

final achievementsListProvider = StreamProvider<List<Achievement>>((ref) {
  final repo = ref.watch(achievementsRepositoryProvider);
  return repo.watchAchievements();
});
