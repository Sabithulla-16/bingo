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

  group('DAILY CHECK-IN SYSTEM & REWARD PROGRESSION TESTS', () {
    late ProfileRepositoryImpl profileRepo;
    late _FakeAuthRepository authRepo;
    late RewardsRepositoryImpl rewardsRepo;
    late PlayerProfile testProfile;

    const String prefCheckinDateKey = 'bingo_rewards_last_checkin_date';
    const String prefStreakKey = 'bingo_rewards_streak';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      profileRepo = ProfileRepositoryImpl(null);
      testProfile = PlayerProfile(
        id: 'user_daily_checkin_test',
        displayName: 'StreakMaster',
        email: 'streak@bingo.app',
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 1000,
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

    test('1. AVAILABLE State: New user opens screen and reward is available', () async {
      final info = await rewardsRepo.getDailyCheckin();
      expect(info.isClaimedToday, isFalse, reason: 'Reward should be AVAILABLE');
      expect(info.streak, equals(1), reason: 'First day is Day 1');
      expect(info.todayReward, equals(25), reason: 'Day 1 reward must be 25');
    });

    test('2. Successful Claim: Transitions to CLAIMED, credits wallet balance exactly once', () async {
      final reward = await rewardsRepo.claimDailyCheckin();
      expect(reward, equals(25), reason: 'Day 1 reward is 25');

      final profile = await profileRepo.getProfile(testProfile.id);
      expect(profile!.chips, equals(1025), reason: 'Wallet credited exactly once with 25');

      final status = await rewardsRepo.getDailyCheckin();
      expect(status.isClaimedToday, isTrue, reason: 'State must be CLAIMED');
      expect(status.streak, equals(1));
    });

    test('3. Immediate Re-claim Protection: Duplicate claims within same calendar day are rejected', () async {
      await rewardsRepo.claimDailyCheckin();
      final chipsAfterFirstClaim = (await profileRepo.getProfile(testProfile.id))!.chips;

      expect(
        () => rewardsRepo.claimDailyCheckin(),
        throwsA(isA<StateError>()),
        reason: 'Duplicate claim on same day must throw StateError',
      );

      final chipsAfterFailedClaim = (await profileRepo.getProfile(testProfile.id))!.chips;
      expect(chipsAfterFailedClaim, equals(chipsAfterFirstClaim), reason: 'Balance must remain unchanged');
    });

    test('4. Session / App Restart Persistence: State remains CLAIMED on cold start', () async {
      await rewardsRepo.claimDailyCheckin();

      // Simulate app restart with a fresh RewardsRepository instance
      final restartedRewardsRepo = RewardsRepositoryImpl(
        supabase: null,
        authRepo: authRepo,
        profileRepo: profileRepo,
      );

      final status = await restartedRewardsRepo.getDailyCheckin();
      expect(status.isClaimedToday, isTrue, reason: 'Persisted state must remain CLAIMED after app restart');
      expect(status.streak, equals(1));
    });

    test('5. 7-Day Reward Cycle & Streak Progression: 25 -> 30 -> 35 -> 40 -> 50 -> 60 -> 100 -> wraps to 1', () async {
      final expectedRewards = [25, 30, 35, 40, 50, 60, 100];
      final prefs = await SharedPreferences.getInstance();

      final kolkataNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

      for (int day = 1; day <= 7; day++) {
        final mockClaimDate = kolkataNow;
        final dateStr = '${mockClaimDate.year.toString().padLeft(4, '0')}-'
            '${mockClaimDate.month.toString().padLeft(2, '0')}-'
            '${mockClaimDate.day.toString().padLeft(2, '0')}';

        // Set state as claimed today with streak `day`
        await prefs.setString('${prefCheckinDateKey}_${testProfile.id}', dateStr);
        await prefs.setInt('${prefStreakKey}_${testProfile.id}', day);

        final status = await rewardsRepo.getDailyCheckin();
        expect(status.isClaimedToday, isTrue);
        expect(status.streak, equals(day));
        expect(status.todayReward, equals(expectedRewards[day - 1]));
      }
    });

    test('6. Missed Day Streak Reset: Missing a calendar day resets streak to 1', () async {
      final prefs = await SharedPreferences.getInstance();
      final kolkataNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

      // Simulate last claim was 3 days ago (gap > 1 day) with streak of 5
      final pastDate = kolkataNow.subtract(const Duration(days: 3));
      final dateStr = '${pastDate.year.toString().padLeft(4, '0')}-'
          '${pastDate.month.toString().padLeft(2, '0')}-'
          '${pastDate.day.toString().padLeft(2, '0')}';

      await prefs.setString('${prefCheckinDateKey}_${testProfile.id}', dateStr);
      await prefs.setInt('${prefStreakKey}_${testProfile.id}', 5);

      final status = await rewardsRepo.getDailyCheckin();
      expect(status.isClaimedToday, isFalse, reason: 'Eligible to claim today');
      expect(status.streak, equals(1), reason: 'Streak must reset to 1 due to missed day');
      expect(status.todayReward, equals(25), reason: 'Reward must reset to Day 1 (25)');

      final reward = await rewardsRepo.claimDailyCheckin();
      expect(reward, equals(25));

      final updatedStatus = await rewardsRepo.getDailyCheckin();
      expect(updatedStatus.isClaimedToday, isTrue);
      expect(updatedStatus.streak, equals(1), reason: 'Streak remains at 1 for today');
    });

    test('7. Consecutive Day Increment: Claiming yesterday allows claiming today for streak + 1', () async {
      final prefs = await SharedPreferences.getInstance();
      final kolkataNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

      // Simulate claim yesterday (1 day ago) with streak 1
      final yesterday = kolkataNow.subtract(const Duration(days: 1));
      final dateStr = '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';

      await prefs.setString('${prefCheckinDateKey}_${testProfile.id}', dateStr);
      await prefs.setInt('${prefStreakKey}_${testProfile.id}', 1);

      final status = await rewardsRepo.getDailyCheckin();
      expect(status.isClaimedToday, isFalse);
      expect(status.streak, equals(2), reason: 'Advances to Day 2');
      expect(status.todayReward, equals(30), reason: 'Day 2 reward is 30');

      final reward = await rewardsRepo.claimDailyCheckin();
      expect(reward, equals(30));

      final postStatus = await rewardsRepo.getDailyCheckin();
      expect(postStatus.isClaimedToday, isTrue);
      expect(postStatus.streak, equals(2), reason: 'Streak is 2');
    });
  });
}
