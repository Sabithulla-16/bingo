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

  DateTime get _nowKolkata =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  String _formatKolkataDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Stream<DailyCheckinInfo> watchDailyCheckin() => _checkinController.stream;

  @override
  Stream<List<MatchRewardTask>> watchTasks() => _tasksController.stream;

  @override
  Future<DailyCheckinInfo> getDailyCheckin() async {
    if (_isOnline) {
      try {
        final res = await _supabase!.rpc('rpc_get_daily_checkin_status');
        if (res is Map<String, dynamic>) {
          final isClaimed = res['is_claimed_today'] as bool? ?? false;
          final streak = (res['streak'] as num?)?.toInt() ?? 1;
          final todayReward = (res['today_reward'] as num?)?.toInt() ??
              DailyCheckinInfo.defaultDayRewards[(streak - 1).clamp(0, 6)];
          final claimedDays = (res['claimed_days'] as List?)
                  ?.map((e) => (e as num).toInt())
                  .toList() ??
              [];
          final secondsUntilReset =
              (res['seconds_until_reset'] as num?)?.toInt() ?? 86400;

          final info = DailyCheckinInfo(
            streak: streak,
            isClaimedToday: isClaimed,
            todayReward: todayReward,
            claimedDays: claimedDays,
            secondsUntilReset: secondsUntilReset,
          );
          _checkinController.add(info);
          return info;
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'getDailyCheckin_supabase');
      }
    }

    // Local / offline fallback with strict Asia/Kolkata date and streak rules
    final nowK = _nowKolkata;
    final todayStr = _formatKolkataDate(nowK);
    final yestStr = _formatKolkataDate(nowK.subtract(const Duration(days: 1)));

    final prefs = await SharedPreferences.getInstance();
    final lastCheckin =
        prefs.getString('${_prefCheckinDateKey}_$_userId') ?? '';
    final savedStreak = prefs.getInt('${_prefStreakKey}_$_userId') ?? 1;

    final bool isClaimedToday = lastCheckin == todayStr;
    int currentStreak = 1;
    final List<int> claimedDays = <int>[];

    if (isClaimedToday) {
      currentStreak = savedStreak;
      for (int i = 1; i <= currentStreak; i++) {
        claimedDays.add(i);
      }
    } else if (lastCheckin == yestStr) {
      // Consecutive calendar day
      currentStreak = (savedStreak % 7) + 1;
      for (int i = 1; i < currentStreak; i++) {
        claimedDays.add(i);
      }
    } else {
      // Missed day or first check-in
      currentStreak = 1;
    }

    // Reset countdown (midnight in Kolkata)
    final tomorrowMidnightKolkata = DateTime.utc(
      nowK.year,
      nowK.month,
      nowK.day + 1,
    ).subtract(const Duration(hours: 5, minutes: 30));
    final secondsUntilReset = tomorrowMidnightKolkata
        .difference(DateTime.now().toUtc())
        .inSeconds
        .clamp(0, 86400);

    final todayReward =
        DailyCheckinInfo.defaultDayRewards[(currentStreak - 1).clamp(0, 6)];

    final info = DailyCheckinInfo(
      streak: currentStreak,
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

    final nowK = _nowKolkata;
    final todayStr = _formatKolkataDate(nowK);
    final yestStr = _formatKolkataDate(nowK.subtract(const Duration(days: 1)));

    if (_isOnline) {
      try {
        final res = await _supabase!.rpc('rpc_claim_daily_checkin');
        int reward = info.todayReward;
        if (res is Map<String, dynamic> && res['reward_amount'] != null) {
          reward = (res['reward_amount'] as num).toInt();
        }
        await _addLifetimeChips(reward);
        await getDailyCheckin();
        return reward;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'claimDailyCheckin_supabase');
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('already claimed') ||
            errorMsg.contains('duplicate')) {
          await getDailyCheckin();
          throw StateError(
            'You have already claimed your daily check-in today.',
          );
        }
        rethrow;
      }
    }

    // Local / Offline fallback logic
    final prefs = await SharedPreferences.getInstance();
    final lastCheckin =
        prefs.getString('${_prefCheckinDateKey}_$_userId') ?? '';
    final savedStreak = prefs.getInt('${_prefStreakKey}_$_userId') ?? 1;

    int newStreak = 1;
    if (lastCheckin == yestStr) {
      newStreak = (savedStreak % 7) + 1;
    } else {
      newStreak = 1;
    }

    final reward =
        DailyCheckinInfo.defaultDayRewards[(newStreak - 1).clamp(0, 6)];

    // Credit profile chips
    final profile = await _profileRepo.getProfile(_userId);
    if (profile != null) {
      final updatedChips = profile.chips + reward;
      await _profileRepo.upsertProfile(profile.copyWith(chips: updatedChips));
    }

    // Save locally
    await prefs.setString('${_prefCheckinDateKey}_$_userId', todayStr);
    await prefs.setInt('${_prefStreakKey}_$_userId', newStreak);
    await _addLifetimeChips(reward);

    await getDailyCheckin();
    return reward;
  }

  @override
  Future<List<MatchRewardTask>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();

    Set<String> backendClaimedTasks = {};
    if (_isOnline) {
      try {
        final claimsRes = await _supabase!
            .from('reward_claims')
            .select('task_id')
            .eq('user_id', _userId);
        backendClaimedTasks =
            claimsRes.map((c) => c['task_id'].toString()).toSet();
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'getTasks_claims_supabase');
      }
    }

    final matchClaimed =
        backendClaimedTasks.contains('complete_match') ||
        (prefs.getBool('${_prefTaskKeyPrefix}complete_match_claimed_$_userId') ??
            false);
    final winClaimed =
        backendClaimedTasks.contains('win_match') ||
        (prefs.getBool('${_prefTaskKeyPrefix}win_match_claimed_$_userId') ??
            false) ||
        (prefs.getBool('${_prefTaskKeyPrefix}win_claimed_$_userId') ?? false);
    final multiClaimed =
        backendClaimedTasks.contains('play_multiplayer') ||
        (prefs.getBool(
              '${_prefTaskKeyPrefix}play_multiplayer_claimed_$_userId',
            ) ??
            false);
    final roomWinsClaimed =
        backendClaimedTasks.contains('room_champion') ||
        (prefs.getBool('${_prefTaskKeyPrefix}room_champion_claimed_$_userId') ??
            false);
    final friendsClaimed =
        backendClaimedTasks.contains('play_with_friends') ||
        (prefs.getBool(
              '${_prefTaskKeyPrefix}play_with_friends_claimed_$_userId',
            ) ??
            false);

    int matchPlayed =
        prefs.getInt('${_prefTaskKeyPrefix}match_played_$_userId') ?? 0;
    int matchWins =
        prefs.getInt('${_prefTaskKeyPrefix}match_wins_$_userId') ?? 0;
    int multiPlayed =
        prefs.getInt('${_prefTaskKeyPrefix}multi_played_$_userId') ?? 0;
    int roomWins =
        prefs.getInt('${_prefTaskKeyPrefix}room_wins_$_userId') ?? 0;
    int friendMatches =
        prefs.getInt('${_prefTaskKeyPrefix}friend_matches_$_userId') ?? 0;

    if (_isOnline) {
      try {
        final statsRes = await _supabase!
            .from('player_statistics')
            .select('total_matches, wins')
            .eq('user_id', _userId)
            .maybeSingle();
        if (statsRes != null) {
          final sMatches = (statsRes['total_matches'] as num?)?.toInt() ?? 0;
          final sWins = (statsRes['wins'] as num?)?.toInt() ?? 0;
          if (sMatches > matchPlayed) matchPlayed = sMatches;
          if (sWins > matchWins) matchWins = sWins;
        }
      } catch (_) {}
    }

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
        status: matchClaimed
            ? RewardTaskStatus.claimed
            : (matchPlayed >= 3
                  ? RewardTaskStatus.readyToClaim
                  : RewardTaskStatus.inProgress),
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
            : (matchWins >= 1
                  ? RewardTaskStatus.readyToClaim
                  : RewardTaskStatus.inProgress),
      ),
      MatchRewardTask(
        id: 'play_multiplayer',
        title: 'Play Multiplayer',
        category: 'match',
        description: 'Complete any live synchronized match',
        rewardChips: 20,
        current: multiPlayed.clamp(0, 1),
        target: 1,
        status: multiClaimed
            ? RewardTaskStatus.claimed
            : (multiPlayed >= 1
                  ? RewardTaskStatus.readyToClaim
                  : RewardTaskStatus.inProgress),
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
        status: roomWinsClaimed
            ? RewardTaskStatus.claimed
            : (roomWins >= 3
                  ? RewardTaskStatus.readyToClaim
                  : RewardTaskStatus.inProgress),
      ),
      MatchRewardTask(
        id: 'play_with_friends',
        title: 'Play with Friends',
        category: 'multiplayer',
        description: 'Complete matches with invited friends',
        rewardChips: 25,
        current: friendMatches.clamp(0, 2),
        target: 2,
        status: friendsClaimed
            ? RewardTaskStatus.claimed
            : (friendMatches >= 2
                  ? RewardTaskStatus.readyToClaim
                  : RewardTaskStatus.inProgress),
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

    final prefs = await SharedPreferences.getInstance();
    final isAlreadyClaimed =
        (prefs.getBool('$_prefTaskKeyPrefix${taskId}_claimed_$_userId') ??
            false) ||
        (taskId == 'win_match' &&
            (prefs.getBool('${_prefTaskKeyPrefix}win_claimed_$_userId') ??
                false));

    if (task.status.isClaimed || isAlreadyClaimed) {
      throw StateError('This reward has already been claimed.');
    }

    final reward = task.rewardChips;

    if (_isOnline) {
      try {
        await _supabase!.rpc(
          'rpc_claim_reward_task',
          params: {'p_task_id': taskId, 'p_reward_amount': reward},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'claimTask_supabase');
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('already claimed') ||
            errorMsg.contains('duplicate')) {
          await prefs.setBool(
            '$_prefTaskKeyPrefix${taskId}_claimed_$_userId',
            true,
          );
          if (taskId == 'win_match') {
            await prefs.setBool(
              '${_prefTaskKeyPrefix}win_claimed_$_userId',
              true,
            );
          }
          await getTasks();
          throw StateError('This reward has already been claimed.');
        }
      }
    }

    // Credit chips locally ONLY if offline.
    // When online, rpc_claim_reward_task atomically credited chips in Supabase.
    if (!_isOnline) {
      final profile = await _profileRepo.getProfile(_userId);
      if (profile != null) {
        final updatedChips = profile.chips + reward;
        await _profileRepo.upsertProfile(profile.copyWith(chips: updatedChips));
      }
    }

    await prefs.setBool('$_prefTaskKeyPrefix${taskId}_claimed_$_userId', true);
    if (taskId == 'win_match') {
      await prefs.setBool('${_prefTaskKeyPrefix}win_claimed_$_userId', true);
    }
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
      final currentMulti =
          prefs.getInt('${_prefTaskKeyPrefix}multi_played_$_userId') ?? 0;
      await prefs.setInt(
        '${_prefTaskKeyPrefix}multi_played_$_userId',
        currentMulti + 1,
      );

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
    final lifetime = prefs.getInt('${_prefLifetimeKey}_$_userId') ?? chips;

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
        (checkin.isClaimedToday ? 1 : 0);

    return WalletOverviewMetrics(
      balance: chips,
      availableRewards: available,
      lifetimeEarned: lifetime,
      tasksCompleted: completedCount,
      totalTasks: tasks.length + 1,
    );
  }

  Future<void> _addLifetimeChips(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profileRepo.getProfile(_userId);
    final chips = profile?.chips ?? 500;
    final current = prefs.getInt('${_prefLifetimeKey}_$_userId') ?? (chips - amount);
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
