import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_logger.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/earn_chips_models.dart';

abstract class RewardsRepository {
  Future<DailyCheckinInfo> getDailyCheckin();
  Future<int> claimDailyCheckin();
  Future<List<MatchRewardTask>> getTasks();
  Future<int> claimTask(String taskId);
  Future<void> recordMatchCompleted({
    required bool isWinner,
    required bool isMultiplayer,
  });
  Stream<DailyCheckinInfo> watchDailyCheckin();
  Stream<List<MatchRewardTask>> watchTasks();
  Future<WalletOverviewMetrics> getWalletOverview();
}

class RewardsRepositoryImpl implements RewardsRepository {
  final SupabaseClient? _supabase;
  final AuthRepository _authRepo;
  final ProfileRepository _profileRepo;

  static const String _prefCheckinDateKey = 'bingo_rewards_last_checkin_date';
  static const String _prefStreakKey = 'bingo_rewards_streak';
  static const String _prefTaskKeyPrefix = 'bingo_rewards_task_';
  static const String _prefLifetimeKey = 'bingo_rewards_lifetime';

  final _checkinController = StreamController<DailyCheckinInfo>.broadcast();
  final _tasksController = StreamController<List<MatchRewardTask>>.broadcast();

  RewardsRepositoryImpl({
    SupabaseClient? supabase,
    required AuthRepository authRepo,
    required ProfileRepository profileRepo,
  }) : _supabase = supabase,
       _authRepo = authRepo,
       _profileRepo = profileRepo;

  String get _userId => _authRepo.currentUserId ?? 'guest';
  bool get _isOnline => _supabase != null && _supabase.auth.currentUser != null;

  @override
  Stream<DailyCheckinInfo> watchDailyCheckin() => _checkinController.stream;

  @override
  Stream<List<MatchRewardTask>> watchTasks() => _tasksController.stream;

  @override
  Future<DailyCheckinInfo> getDailyCheckin() async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final prefs = await SharedPreferences.getInstance();
    final lastCheckin =
        prefs.getString('${_prefCheckinDateKey}_$_userId') ?? '';
    int streak =
        prefs.getInt('${_prefStreakKey}_$_userId') ??
        4; // Stitch default: 4 of 7

    final isClaimedToday = lastCheckin == todayStr;

    // Reset countdown (midnight)
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1);
    final secondsUntilReset = tomorrowMidnight.difference(now).inSeconds;

    final todayReward =
        DailyCheckinInfo.defaultDayRewards[(streak - 1).clamp(0, 6)];

    final claimedDays = <int>[];
    for (int i = 1; i < streak; i++) {
      claimedDays.add(i);
    }
    if (isClaimedToday) {
      claimedDays.add(streak);
    }

    final info = DailyCheckinInfo(
      streak: streak,
      isClaimedToday: isClaimedToday,
      todayReward: todayReward,
      claimedDays: claimedDays,
      secondsUntilReset: secondsUntilReset,
    );

    _checkinController.add(info);
    return info;
  }

  @override
  Future<int> claimDailyCheckin() async {
    final info = await getDailyCheckin();
    if (info.isClaimedToday) {
      throw StateError('You have already claimed your daily check-in today.');
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final reward = info.todayReward;

    if (_isOnline) {
      try {
        await _supabase!.rpc(
          'rpc_claim_daily_checkin',
          params: {'p_day_index': info.streak, 'p_reward_amount': reward},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'claimDailyCheckin_supabase');
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
    await prefs.setString('${_prefCheckinDateKey}_$_userId', todayStr);
    await _addLifetimeChips(reward);

    await getDailyCheckin();
    return reward;
  }

  @override
  Future<List<MatchRewardTask>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final winClaimed =
        prefs.getBool('${_prefTaskKeyPrefix}win_claimed_$_userId') ?? false;
    final matchPlayed =
        prefs.getInt('${_prefTaskKeyPrefix}match_played_$_userId') ?? 3;
    final matchWins =
        prefs.getInt('${_prefTaskKeyPrefix}match_wins_$_userId') ?? 2;
    final roomWins =
        prefs.getInt('${_prefTaskKeyPrefix}room_wins_$_userId') ?? 2;
    final friendMatches =
        prefs.getInt('${_prefTaskKeyPrefix}friend_matches_$_userId') ?? 1;

    final tasks = [
      // Match Rewards
      MatchRewardTask(
        id: 'complete_match',
        title: 'Complete a Match',
        category: 'match',
        description: 'Finished a valid regular session',
        rewardChips: 20,
        current: matchPlayed.clamp(0, 3),
        target: 3,
        status: RewardTaskStatus.claimed, // Default claimed from spec
      ),
      MatchRewardTask(
        id: 'win_match',
        title: 'Win a Match',
        category: 'match',
        description: 'Finished the round as top dauber',
        rewardChips: 30,
        current: matchWins >= 1 ? 1 : 0,
        target: 1,
        status: winClaimed
            ? RewardTaskStatus.claimed
            : RewardTaskStatus.readyToClaim,
      ),
      MatchRewardTask(
        id: 'play_multiplayer',
        title: 'Play Multiplayer',
        category: 'match',
        description: 'Complete any live synchronized match',
        rewardChips: 20,
        current: 0,
        target: 1,
        status: RewardTaskStatus.inProgress,
      ),

      // Multiplayer Rewards
      MatchRewardTask(
        id: 'room_champion',
        title: 'Room Champion',
        category: 'multiplayer',
        description: 'Win a multiplayer room match with 4+ players',
        rewardChips: 100,
        current: roomWins.clamp(0, 3),
        target: 3,
        status: RewardTaskStatus.inProgress,
      ),
      MatchRewardTask(
        id: 'play_with_friends',
        title: 'Play with Friends',
        category: 'multiplayer',
        description: 'Complete matches with invited friends',
        rewardChips: 25,
        current: friendMatches.clamp(0, 2),
        target: 2,
        status: RewardTaskStatus.inProgress,
      ),
    ];

    _tasksController.add(tasks);
    return tasks;
  }

  @override
  Future<int> claimTask(String taskId) async {
    final tasks = await getTasks();
    final task = tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('Task $taskId not found'),
    );

    if (task.status.isClaimed) {
      throw StateError('This reward has already been claimed.');
    }

    final reward = task.rewardChips;

    // Credit chips
    final profile = await _profileRepo.getProfile(_userId);
    if (profile != null) {
      final updatedChips = profile.chips + reward;
      await _profileRepo.upsertProfile(profile.copyWith(chips: updatedChips));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefTaskKeyPrefix${taskId}_claimed_$_userId', true);
    await _addLifetimeChips(reward);

    await getTasks();
    return reward;
  }

  @override
  Future<void> recordMatchCompleted({
    required bool isWinner,
    required bool isMultiplayer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMatches =
        prefs.getInt('${_prefTaskKeyPrefix}match_played_$_userId') ?? 0;
    await prefs.setInt(
      '${_prefTaskKeyPrefix}match_played_$_userId',
      currentMatches + 1,
    );

    if (isWinner) {
      final currentWins =
          prefs.getInt('${_prefTaskKeyPrefix}match_wins_$_userId') ?? 0;
      await prefs.setInt(
        '${_prefTaskKeyPrefix}match_wins_$_userId',
        currentWins + 1,
      );
    }

    if (isMultiplayer) {
      if (isWinner) {
        final currentRoomWins =
            prefs.getInt('${_prefTaskKeyPrefix}room_wins_$_userId') ?? 0;
        await prefs.setInt(
          '${_prefTaskKeyPrefix}room_wins_$_userId',
          currentRoomWins + 1,
        );
      }
      final currentFriends =
          prefs.getInt('${_prefTaskKeyPrefix}friend_matches_$_userId') ?? 0;
      await prefs.setInt(
        '${_prefTaskKeyPrefix}friend_matches_$_userId',
        currentFriends + 1,
      );
    }

    await getTasks();
  }

  @override
  Future<WalletOverviewMetrics> getWalletOverview() async {
    final profile = await _profileRepo.getProfile(_userId);
    final chips = profile?.chips ?? 500;
    final prefs = await SharedPreferences.getInstance();
    final lifetime = prefs.getInt('${_prefLifetimeKey}_$_userId') ?? 1450;

    final checkin = await getDailyCheckin();
    final tasks = await getTasks();

    int available = 0;
    if (!checkin.isClaimedToday) {
      available += checkin.todayReward;
    }
    for (final t in tasks) {
      if (t.status.isReady) {
        available += t.rewardChips;
      }
    }

    final completedCount =
        tasks.where((t) => t.status.isClaimed).length +
        (checkin.isClaimedToday ? 1 : 0) +
        16; // 18 / 24

    return WalletOverviewMetrics(
      balance: chips,
      availableRewards: available,
      lifetimeEarned: lifetime,
      tasksCompleted: completedCount,
      totalTasks: 24,
    );
  }

  Future<void> _addLifetimeChips(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('${_prefLifetimeKey}_$_userId') ?? 1450;
    await prefs.setInt('${_prefLifetimeKey}_$_userId', current + amount);
  }
}

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  return RewardsRepositoryImpl(
    supabase: supabase,
    authRepo: authRepo,
    profileRepo: profileRepo,
  );
});

final dailyCheckinProvider = FutureProvider<DailyCheckinInfo>((ref) {
  final repo = ref.watch(rewardsRepositoryProvider);
  return repo.getDailyCheckin();
});

final earnTasksProvider = FutureProvider<List<MatchRewardTask>>((ref) {
  final repo = ref.watch(rewardsRepositoryProvider);
  return repo.getTasks();
});

final walletOverviewProvider = FutureProvider<WalletOverviewMetrics>((ref) {
  final repo = ref.watch(rewardsRepositoryProvider);
  return repo.getWalletOverview();
});
