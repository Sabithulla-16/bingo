import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/achievements/data/achievements_repository.dart';
import 'package:bingo/features/achievements/domain/achievement.dart';
import 'package:bingo/features/profile/domain/player_career_stats.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import '../multiplayer/multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuth;
  late MockProfileRepository mockProfile;
  late AchievementsRepositoryImpl repository;

  final testProfile = PlayerProfile(
    id: 'ach_test_user',
    displayName: 'Achievement Tester',
    email: 'tester@bingo.dev',
    avatarColorHex: '#20243A',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthRepository(testProfile);
    mockProfile = MockProfileRepository(testProfile);
    repository = AchievementsRepositoryImpl(
      authRepo: mockAuth,
      profileRepo: mockProfile,
    );
  });

  group('Achievements Claim & Progression Tests', () {
    test('Initial achievements have valid default states', () async {
      final achievements = await repository.getAchievements();
      expect(achievements, isNotEmpty);

      // Verify default first task is ready to claim or in progress
      final firstTask = achievements.first;
      expect(firstTask.status, isNot(equals(AchievementStatus.claimed)));
      expect(firstTask.rewardChips, greaterThan(0));
    });

    test('Claiming an achievement marks it claimed and updates chips', () async {
      final initialAchievements = await repository.getAchievements();
      final firstAchievement = initialAchievements.first;

      // Update progress so it is ready to claim
      await repository.updateProgress(firstAchievement.id, firstAchievement.target);

      final claimResult = await repository.claimAchievement(firstAchievement.id);
      expect(claimResult, equals(firstAchievement.rewardChips));

      final updatedAchievements = await repository.getAchievements();
      final claimedItem = updatedAchievements.firstWhere((a) => a.id == firstAchievement.id);

      expect(claimedItem.status, equals(AchievementStatus.claimed));
    });

    test('Repeat claim is cleanly rejected with already claimed StateError', () async {
      final initialAchievements = await repository.getAchievements();
      final target = initialAchievements.first;

      await repository.updateProgress(target.id, target.target);
      final firstClaim = await repository.claimAchievement(target.id);
      expect(firstClaim, equals(target.rewardChips));

      // Attempt second claim on the exact same achievement
      await expectLater(
        () => repository.claimAchievement(target.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already been claimed'),
          ),
        ),
      );

      final refreshed = await repository.getAchievements();
      final item = refreshed.firstWhere((a) => a.id == target.id);
      expect(item.status, equals(AchievementStatus.claimed));
    });

    test('evaluateFromStats unlocks achievements based on actual player statistics', () async {
      const stats = PlayerCareerStats(
        totalMatches: 5,
        wins: 3,
        losses: 2,
        currentStreak: 3,
        bestStreak: 3,
        highestLinesClaimed: 5,
      );

      await repository.evaluateFromStats(
        stats,
        isMultiplayer: true,
        isVictory: true,
      );

      final achievements = await repository.getAchievements();
      final firstBingo = achievements.firstWhere((a) => a.id == 'card-first-bingo');
      final firstSteps = achievements.firstWhere((a) => a.id == 'card-first-steps');

      // First bingo (target 1, stats.totalWins = 3) must be ready or claimed
      expect(firstBingo.current, greaterThanOrEqualTo(1));
      expect(firstBingo.status.isReady || firstBingo.status.isClaimed, isTrue);

      // First steps (target 1, stats.totalMatches = 5)
      expect(firstSteps.current, greaterThanOrEqualTo(1));
      expect(firstSteps.status.isReady || firstSteps.status.isClaimed, isTrue);
    });
  });
}
