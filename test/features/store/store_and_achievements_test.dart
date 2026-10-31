import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/store/domain/store_item.dart';
import 'package:bingo/features/achievements/domain/achievement.dart';

void main() {
  group('StoreItem Domain Tests', () {
    test('contains all 12 approved store items with valid attributes', () {
      expect(StoreItem.catalog.length, 12);

      for (final item in StoreItem.catalog) {
        expect(item.id, greaterThan(0));
        expect(item.title.isNotEmpty, isTrue);
        expect(item.price, greaterThanOrEqualTo(0));
        expect(item.category, isNotNull);
      }
    });

    test('filters items accurately by category', () {
      final boards = StoreItem.catalog
          .where((i) => i.category == StoreCategory.board)
          .toList();
      expect(boards.length, 4);

      final sounds = StoreItem.catalog
          .where((i) => i.category == StoreCategory.sound)
          .toList();
      expect(sounds.length, 3);
    });
  });

  group('Achievements Priority Sorting Tests', () {
    test('orders strictly: READY -> IN PROGRESS -> LOCKED -> CLAIMED', () {
      const readyHigh = Achievement(
        id: 'ready_high',
        title: 'Ready High',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 10,
        current: 10,
        rewardChips: 500,
        status: AchievementStatus.ready,
      );

      const readyLow = Achievement(
        id: 'ready_low',
        title: 'Ready Low',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 5,
        current: 5,
        rewardChips: 100,
        status: AchievementStatus.ready,
      );

      const inProgressHighPercent = Achievement(
        id: 'prog_high',
        title: 'Prog High',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 10,
        current: 8, // 80%
        rewardChips: 200,
        status: AchievementStatus.inProgress,
      );

      const inProgressLowPercent = Achievement(
        id: 'prog_low',
        title: 'Prog Low',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 10,
        current: 2, // 20%
        rewardChips: 300,
        status: AchievementStatus.inProgress,
      );

      const lockedNear = Achievement(
        id: 'locked_near',
        title: 'Locked Near',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 5,
        current: 0,
        rewardChips: 100,
        status: AchievementStatus.locked,
      );

      const lockedFar = Achievement(
        id: 'locked_far',
        title: 'Locked Far',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 50,
        current: 0,
        rewardChips: 1000,
        status: AchievementStatus.locked,
      );

      const claimed = Achievement(
        id: 'claimed_item',
        title: 'Claimed Item',
        description: 'Desc',
        icon: 'trophy',
        category: AchievementCategory.gameplay,
        target: 1,
        current: 1,
        rewardChips: 50,
        status: AchievementStatus.claimed,
      );

      final unsorted = [
        claimed,
        lockedFar,
        readyLow,
        inProgressLowPercent,
        lockedNear,
        readyHigh,
        inProgressHighPercent,
      ];

      final sorted = Achievement.sortList(unsorted);

      // Verify the mandatory priority ordering:
      // 1. Ready to claim (highest reward chips first)
      expect(sorted[0].id, 'ready_high');
      expect(sorted[1].id, 'ready_low');

      // 2. In progress (highest progress % first)
      expect(sorted[2].id, 'prog_high');
      expect(sorted[3].id, 'prog_low');

      // 3. Locked (nearest requirement first)
      expect(sorted[4].id, 'locked_near');
      expect(sorted[5].id, 'locked_far');

      // 4. Claimed (always at the very bottom)
      expect(sorted[6].id, 'claimed_item');
    });
  });
}
