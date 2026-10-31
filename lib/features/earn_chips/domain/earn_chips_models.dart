import 'package:flutter/foundation.dart';

/// Status of a reward task or activity.
enum RewardTaskStatus {
  available,
  inProgress,
  readyToClaim,
  claimed,
  locked;

  bool get isReady => this == RewardTaskStatus.readyToClaim;
  bool get isClaimed => this == RewardTaskStatus.claimed;
  bool get isInProgress => this == RewardTaskStatus.inProgress;
}

/// Representation of the 7-day daily check-in sequence.
@immutable
class DailyCheckinInfo {
  final int streak; // 1..7
  final bool isClaimedToday;
  final int todayReward;
  final List<int> claimedDays; // List of day indices (1..7) claimed
  final int secondsUntilReset;

  const DailyCheckinInfo({
    required this.streak,
    required this.isClaimedToday,
    required this.todayReward,
    required this.claimedDays,
    required this.secondsUntilReset,
  });

  String get formattedResetCountdown {
    final hours = secondsUntilReset ~/ 3600;
    final mins = (secondsUntilReset % 3600) ~/ 60;
    return '${hours}h ${mins}m';
  }

  static const List<int> defaultDayRewards = [25, 30, 35, 40, 50, 60, 100];
}

/// Task representing a gameplay or multiplayer reward in the Earn Chips screen.
@immutable
class MatchRewardTask {
  final String id;
  final String title;
  final String category; // 'match', 'multiplayer'
  final String description;
  final int rewardChips;
  final int current;
  final int target;
  final RewardTaskStatus status;

  const MatchRewardTask({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.rewardChips,
    required this.current,
    required this.target,
    required this.status,
  });

  double get progressPercentage =>
      target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

  MatchRewardTask copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    int? rewardChips,
    int? current,
    int? target,
    RewardTaskStatus? status,
  }) {
    return MatchRewardTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      rewardChips: rewardChips ?? this.rewardChips,
      current: current ?? this.current,
      target: target ?? this.target,
      status: status ?? this.status,
    );
  }
}

/// Aggregated wallet metrics for the top bento overview.
@immutable
class WalletOverviewMetrics {
  final int balance;
  final int availableRewards;
  final int lifetimeEarned;
  final int tasksCompleted;
  final int totalTasks;

  const WalletOverviewMetrics({
    required this.balance,
    required this.availableRewards,
    required this.lifetimeEarned,
    required this.tasksCompleted,
    required this.totalTasks,
  });
}
