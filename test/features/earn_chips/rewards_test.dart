import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/authentication/domain/auth_repository.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/earn_chips/data/rewards_repository.dart';
import 'package:bingo/features/profile/data/profile_repository_impl.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';

class _FakeAuthRepository implements AuthRepository {
  final PlayerProfile profile;
  _FakeAuthRepository(this.profile);

  @override
  String? get currentUserId => profile.id;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => profile.isGuest;

  @override
  Stream<AppAuthState> get authStateChanges =>
      Stream.value(Authenticated(profile));

  @override
  Future<PlayerProfile?> restoreSession() async => profile;

  @override
  Future<PlayerProfile> signInAsGuest({String? displayName}) async => profile;

  @override
  Future<PlayerProfile> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async => profile;

  @override
  Future<PlayerProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => profile;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RewardsRepository Integrity & Idempotency Tests', () {
    late ProfileRepositoryImpl profileRepo;
    late _FakeAuthRepository authRepo;
    late RewardsRepositoryImpl rewardsRepo;
    late PlayerProfile testProfile;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      profileRepo = ProfileRepositoryImpl(null);
      testProfile = PlayerProfile(
        id: 'user_reward_test',
        displayName: 'ChipCollector',
        email: 'chips@bingo.app',
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await profileRepo.upsertProfile(testProfile);
      authRepo = _FakeAuthRepository(testProfile);
      rewardsRepo = RewardsRepositoryImpl(
        supabase: null,
        authRepo: authRepo,
        profileRepo: profileRepo,
      );
    });

    test('daily check-in credits chips and marks claimed', () async {
      final initialInfo = await rewardsRepo.getDailyCheckin();
      expect(initialInfo.isClaimedToday, isFalse);

      final reward = await rewardsRepo.claimDailyCheckin();
      expect(reward, greaterThan(0));

      final updatedProfile = await profileRepo.getProfile(testProfile.id);
      expect(updatedProfile!.chips, equals(500 + reward));

      final refreshedInfo = await rewardsRepo.getDailyCheckin();
      expect(refreshedInfo.isClaimedToday, isTrue);
    });

    test(
      'daily check-in rejects duplicate claims and preserves balance',
      () async {
        final reward = await rewardsRepo.claimDailyCheckin();
        final expectedBalance = 500 + reward;

        // Second attempt must fail with StateError
        expect(
          () => rewardsRepo.claimDailyCheckin(),
          throwsA(isA<StateError>()),
        );

        final balanceAfterSecondAttempt = (await profileRepo.getProfile(
          testProfile.id,
        ))!.chips;
        expect(balanceAfterSecondAttempt, equals(expectedBalance));
      },
    );

    test(
      'daily check-in claimed state persists across new repository instances',
      () async {
        await rewardsRepo.claimDailyCheckin();

        // Create a brand new instance of repository simulating app restart
        final newRepoInstance = RewardsRepositoryImpl(
          supabase: null,
          authRepo: authRepo,
          profileRepo: profileRepo,
        );

        final info = await newRepoInstance.getDailyCheckin();
        expect(info.isClaimedToday, isTrue);

        expect(
          () => newRepoInstance.claimDailyCheckin(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('task claim idempotency prevents double payout', () async {
      // Complete a match win
      await rewardsRepo.recordMatchCompleted(
        isWinner: true,
        isMultiplayer: false,
      );

      final tasks = await rewardsRepo.getTasks();
      final winTask = tasks.firstWhere((t) => t.id == 'win_match');
      expect(winTask.status.isReady, isTrue);
      expect(winTask.status.isClaimed, isFalse);

      // Claim reward
      final payout = await rewardsRepo.claimTask('win_match');
      expect(payout, equals(winTask.rewardChips));

      final currentBalance = (await profileRepo.getProfile(
        testProfile.id,
      ))!.chips;
      expect(currentBalance, equals(500 + payout));

      // Second claim attempt must reject
      expect(
        () => rewardsRepo.claimTask('win_match'),
        throwsA(isA<StateError>()),
      );

      final finalBalance = (await profileRepo.getProfile(
        testProfile.id,
      ))!.chips;
      expect(finalBalance, equals(currentBalance));

      // Reload tasks from storage
      final reloadedTasks = await rewardsRepo.getTasks();
      final reloadedWinTask = reloadedTasks.firstWhere(
        (t) => t.id == 'win_match',
      );
      expect(reloadedWinTask.status.isClaimed, isTrue);
      expect(reloadedWinTask.status.isReady, isFalse);
    });
  });
}
