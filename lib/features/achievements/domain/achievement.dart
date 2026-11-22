import 'package:flutter/foundation.dart';

/// Categories for achievement filtering.
enum AchievementCategory {
  all('All', 'all'),
  gameplay('Gameplay', 'gameplay'),
  winning('Winning', 'winning'),
  multiplayer('Multiplayer', 'multiplayer'),
  collection('Collection', 'collection'),
  streaks('Streaks', 'streaks');

  final String label;
  final String key;
  const AchievementCategory(this.label, this.key);

  static AchievementCategory fromKey(String key) {
    return AchievementCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => AchievementCategory.all,
    );
  }
}

/// Status of an individual achievement.
enum AchievementStatus {
  ready,
  inProgress,
  locked,
  claimed;

  bool get isReady => this == AchievementStatus.ready;
  bool get isInProgress => this == AchievementStatus.inProgress;
  bool get isLocked => this == AchievementStatus.locked;
  bool get isClaimed => this == AchievementStatus.claimed;

  static AchievementStatus fromString(String str) {
    switch (str.toLowerCase()) {
      case 'ready':
        return AchievementStatus.ready;
      case 'in_progress':
      case 'inprogress':
        return AchievementStatus.inProgress;
      case 'locked':
        return AchievementStatus.locked;
      case 'claimed':
        return AchievementStatus.claimed;
      default:
        return AchievementStatus.locked;
    }
  }

  String toDbString() {
    switch (this) {
      case AchievementStatus.ready:
        return 'ready';
      case AchievementStatus.inProgress:
        return 'in_progress';
      case AchievementStatus.locked:
        return 'locked';
      case AchievementStatus.claimed:
        return 'claimed';
    }
  }
}

/// Immutable model representing an achievement card in the Achievements screen.
@immutable
class Achievement {
  final String id;
  final String title;
  final AchievementCategory category;
  final String description;
  final String icon;
  final AchievementStatus status;
  final int current;
  final int target;
  final int rewardChips;

  const Achievement({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.status,
    required this.current,
    required this.target,
    required this.rewardChips,
  });

  double get progressPercentage =>
      target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

  int get progressPercentInt => (progressPercentage * 100).round();

  Achievement copyWith({
    String? id,
    String? title,
    AchievementCategory? category,
    String? description,
    String? icon,
    AchievementStatus? status,
    int? current,
    int? target,
    int? rewardChips,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      current: current ?? this.current,
      target: target ?? this.target,
      rewardChips: rewardChips ?? this.rewardChips,
    );
  }

  /// Sorts achievements using the exact mandated priority algorithm:
  /// 1. READY (highest reward chips first)
  /// 2. IN PROGRESS (highest completion % first, then reward chips)
  /// 3. LOCKED (nearest completion % first, then reward chips)
  /// 4. CLAIMED (always at bottom, highest reward chips first)
  static List<Achievement> sortList(List<Achievement> list) {
    const statusRank = {
      AchievementStatus.ready: 1,
      AchievementStatus.inProgress: 2,
      AchievementStatus.locked: 3,
      AchievementStatus.claimed: 4,
    };

    final sorted = List<Achievement>.from(list);
    sorted.sort((a, b) {
      final rankA = statusRank[a.status] ?? 99;
      final rankB = statusRank[b.status] ?? 99;

      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      final percentA = a.progressPercentage;
      final percentB = b.progressPercentage;

      switch (a.status) {
        case AchievementStatus.ready:
          return b.rewardChips.compareTo(a.rewardChips);

        case AchievementStatus.inProgress:
          if ((percentB - percentA).abs() > 0.001) {
            return percentB.compareTo(percentA);
          }
          return b.rewardChips.compareTo(a.rewardChips);

        case AchievementStatus.locked:
          final remainingA = a.target - a.current;
          final remainingB = b.target - b.current;
          if (remainingA != remainingB) {
            return remainingA.compareTo(remainingB);
          }
          return b.rewardChips.compareTo(a.rewardChips);

        case AchievementStatus.claimed:
          return b.rewardChips.compareTo(a.rewardChips);
      }
    });

    return sorted;
  }

  /// Standard approved definitions matching the Stitch design specifications.
  /// All initial progress starts strictly at 0 (locked) until verified genuine player activity occurs.
  static List<Achievement> get standardList => const [
    // 1. Getting Started
    Achievement(
      id: 'card-getting-started',
      title: 'Getting Started',
      category: AchievementCategory.gameplay,
      description: 'Complete 10 BINGO matches.',
      icon: 'ads_click',
      status: AchievementStatus.locked,
      current: 0,
      target: 10,
      rewardChips: 100,
    ),
    // 2. Winning Streak
    Achievement(
      id: 'card-winning-streak',
      title: 'Winning Streak',
      category: AchievementCategory.winning,
      description: 'Win 3 matches consecutively.',
      icon: 'local_fire_department',
      status: AchievementStatus.locked,
      current: 0,
      target: 3,
      rewardChips: 200,
    ),
    // 3. Room Regular
    Achievement(
      id: 'card-room-regular',
      title: 'Room Regular',
      category: AchievementCategory.multiplayer,
      description: 'Complete 10 multiplayer matches.',
      icon: 'sports_esports',
      status: AchievementStatus.locked,
      current: 0,
      target: 10,
      rewardChips: 150,
    ),
    // 4. Room Champion
    Achievement(
      id: 'card-room-champion',
      title: 'Room Champion',
      category: AchievementCategory.multiplayer,
      description: 'Win 5 multiplayer matches.',
      icon: 'hotel_class',
      status: AchievementStatus.locked,
      current: 0,
      target: 5,
      rewardChips: 250,
    ),
    // 5. Dedicated Player
    Achievement(
      id: 'card-dedicated-player',
      title: 'Dedicated Player',
      category: AchievementCategory.streaks,
      description: 'Check in for 7 consecutive days.',
      icon: 'calendar_month',
      status: AchievementStatus.locked,
      current: 0,
      target: 7,
      rewardChips: 200,
    ),
    // 6. Number Master
    Achievement(
      id: 'card-number-master',
      title: 'Number Master',
      category: AchievementCategory.gameplay,
      description: 'Play 25 matches.',
      icon: 'casino',
      status: AchievementStatus.locked,
      current: 0,
      target: 25,
      rewardChips: 150,
    ),
    // 7. BINGO Champion
    Achievement(
      id: 'card-bingo-champion',
      title: 'BINGO Champion',
      category: AchievementCategory.winning,
      description: 'Win 10 matches total.',
      icon: 'lock',
      status: AchievementStatus.locked,
      current: 0,
      target: 10,
      rewardChips: 300,
    ),
    // 8. Collector
    Achievement(
      id: 'card-collector',
      title: 'Collector',
      category: AchievementCategory.collection,
      description: 'Own 5 customizations.',
      icon: 'diamond',
      status: AchievementStatus.locked,
      current: 0,
      target: 5,
      rewardChips: 150,
    ),
    // 9. First Steps
    Achievement(
      id: 'card-first-steps',
      title: 'First Steps',
      category: AchievementCategory.gameplay,
      description: 'Complete your first BINGO match.',
      icon: 'military_tech',
      status: AchievementStatus.locked,
      current: 0,
      target: 1,
      rewardChips: 50,
    ),
    // 10. First BINGO
    Achievement(
      id: 'card-first-bingo',
      title: 'First BINGO',
      category: AchievementCategory.winning,
      description: 'Win your first match.',
      icon: 'emoji_events',
      status: AchievementStatus.locked,
      current: 0,
      target: 1,
      rewardChips: 100,
    ),
    // 11. Social Player
    Achievement(
      id: 'card-social-player',
      title: 'Social Player',
      category: AchievementCategory.multiplayer,
      description: 'Complete your first multiplayer match.',
      icon: 'group',
      status: AchievementStatus.locked,
      current: 0,
      target: 1,
      rewardChips: 75,
    ),
    // 12. Style Explorer
    Achievement(
      id: 'card-style-explorer',
      title: 'Style Explorer',
      category: AchievementCategory.collection,
      description: 'Equip your first customization.',
      icon: 'palette',
      status: AchievementStatus.locked,
      current: 0,
      target: 1,
      rewardChips: 50,
    ),
    // 13. Daily Visitor
    Achievement(
      id: 'card-daily-visitor',
      title: 'Daily Visitor',
      category: AchievementCategory.streaks,
      description: 'Check in for 3 consecutive days.',
      icon: 'event_available',
      status: AchievementStatus.locked,
      current: 0,
      target: 3,
      rewardChips: 75,
    ),
  ];
}
