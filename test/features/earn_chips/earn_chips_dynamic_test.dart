import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/earn_chips/data/rewards_repository.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import '../multiplayer/multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuth;
  late MockProfileRepository mockProfile;
  late RewardsRepositoryImpl repository;

  final testProfile = PlayerProfile(
    id: 'rewards_tester',
    displayName: 'Rewards Tester',
    email: 'rewards@bingo.dev',
    avatarColorHex: '#20243A',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthRepository(testProfile);
    mockProfile = MockProfileRepository(testProfile);
    repository = RewardsRepositoryImpl(
      authRepo: mockAuth,
      profileRepo: mockProfile,
    );
  });

  group('Earn Chips Dynamic Tasks & Wallet Tests', () {
    test('WalletOverviewMetrics starts with actual player chips without hardcoded lifetime chips', () async {
      final metrics = await repository.getWalletOverview();

      // Balance matches profile chips
      expect(metrics.balance, equals(500));
      // Lifetime chips is not hardcoded to 1450
      expect(metrics.lifetimeEarned, equals(500));
      // Day 1 daily check-in is ready to claim (+25)
      expect(metrics.availableRewards, equals(25));
    });

    test('All match reward tasks are dynamically generated with 0 initial progress', () async {
      final tasks = await repository.getTasks();

      expect(tasks, isNotEmpty);
      final completeTask = tasks.firstWhere((t) => t.id == 'complete_match');
      final winTask = tasks.firstWhere((t) => t.id == 'win_match');
      final playMultiplayer = tasks.firstWhere((t) => t.id == 'play_multiplayer');

      // None of the tasks are pre-claimed with mock data
      expect(completeTask.status.isClaimed, isFalse);
      expect(winTask.status.isClaimed, isFalse);
      expect(playMultiplayer.status.isClaimed, isFalse);
    });

    test('Claiming a task updates task status and credits chips', () async {
      // Claim daily check-in
      final reward = await repository.claimDailyCheckin();
      expect(reward, equals(25));

      final updatedProfile = await mockProfile.getProfile(testProfile.id);
      expect(updatedProfile?.chips, equals(525));

      final metrics = await repository.getWalletOverview();
      expect(metrics.balance, equals(525));
      expect(metrics.lifetimeEarned, equals(525));
    });
  });
}
