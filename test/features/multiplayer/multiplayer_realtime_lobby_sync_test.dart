import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/authentication/domain/auth_repository.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_career_stats.dart';
import 'package:bingo/features/profile/domain/player_preferences.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/profile/domain/profile_repository.dart';
import 'package:bingo/features/earn_chips/data/rewards_repository.dart';
import 'package:bingo/features/achievements/data/achievements_repository.dart';
import 'package:bingo/features/achievements/domain/achievement.dart';
import 'package:bingo/core/services/network_connectivity_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTestAuthRepo implements AuthRepository {
  final String? _uid;
  final PlayerProfile? _profile;

  MockTestAuthRepo(this._uid, this._profile);

  @override
  String? get currentUserId => _uid;

  @override
  bool get isGuest => false;

  @override
  bool get isAuthenticated => _uid != null;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Stream<AppAuthState> get authStateChanges => const Stream.empty();

  @override
  Future<PlayerProfile?> restoreSession() async => _profile;

  @override
  Future<PlayerProfile> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async => _profile!;

  @override
  Future<PlayerProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => _profile!;

  @override
  Future<PlayerProfile> signInAsGuest({String? displayName}) async => _profile!;

  @override
  Future<void> signOut() async {}
}

class MockTestProfileRepo implements ProfileRepository {
  final Map<String, PlayerProfile> profiles = {};
  final Map<String, PlayerCareerStats> stats = {};

  @override
  Future<PlayerProfile?> getProfile(String userId) async => profiles[userId];

  @override
  Future<PlayerProfile> upsertProfile(PlayerProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<void> updateDisplayName(String userId, String displayName) async {
    final p = profiles[userId];
    if (p != null) profiles[userId] = p.copyWith(displayName: displayName);
  }

  @override
  Future<void> updateAvatar(
    String userId, {
    required String avatarId,
    required String avatarColorHex,
  }) async {
    final p = profiles[userId];
    if (p != null) {
      profiles[userId] = p.copyWith(
        avatarId: avatarId,
        avatarColorHex: avatarColorHex,
      );
    }
  }

  @override
  Future<PlayerCareerStats> getCareerStats(String userId) async =>
      stats[userId] ?? const PlayerCareerStats();

  @override
  Future<void> recordMatchResult({
    required String userId,
    required MatchOutcome outcome,
    required int linesClaimed,
    required int callsCount,
    required bool isMultiplayer,
  }) async {
    final current = await getCareerStats(userId);
    final isWin = outcome == MatchOutcome.victory;
    final isLoss = outcome == MatchOutcome.defeat;
    final isDraw = outcome == MatchOutcome.draw;

    stats[userId] = current.copyWith(
      totalMatches: current.totalMatches + 1,
      wins: current.wins + (isWin ? 1 : 0),
      losses: current.losses + (isLoss ? 1 : 0),
      draws: current.draws + (isDraw ? 1 : 0),
      currentStreak: isWin ? (current.currentStreak + 1) : 0,
      bestStreak: isWin && (current.currentStreak + 1) > current.bestStreak
          ? current.currentStreak + 1
          : current.bestStreak,
    );
  }

  @override
  Future<PlayerPreferences> getPreferences() async => const PlayerPreferences();

  @override
  Future<void> savePreferences(PlayerPreferences preferences) async {}

  @override
  Stream<PlayerProfile> watchProfile(String userId) {
    final p = profiles[userId];
    if (p != null) return Stream.value(p);
    return const Stream.empty();
  }

  @override
  Stream<PlayerCareerStats> watchCareerStats(String userId) {
    return Stream.value(stats[userId] ?? const PlayerCareerStats());
  }
}

void main() {
  group('Multiplayer Realtime Multi-Client Lobby Synchronization', () {
    late MockTestProfileRepo profileRepo;
    late MockTestAuthRepo authA;
    late MockTestAuthRepo authB;
    late MultiplayerRepositoryImpl clientA;
    late MultiplayerRepositoryImpl clientB;

    setUp(() {
      MultiplayerRepositoryImpl.resetStaticStoresForTesting();
      profileRepo = MockTestProfileRepo();

      final profileA = PlayerProfile(
        id: 'user_player_A',
        email: 'alice@bingo.game',
        displayName: 'Alice (Host)',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final profileB = PlayerProfile(
        id: 'user_player_B',
        email: 'bob@bingo.game',
        displayName: 'Bob (Joiner)',
        avatarColorHex: '#7C66DC',
        chips: 300,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      profileRepo.profiles[profileA.id] = profileA;
      profileRepo.profiles[profileB.id] = profileB;

      authA = MockTestAuthRepo(profileA.id, profileA);
      authB = MockTestAuthRepo(profileB.id, profileB);

      clientA = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authA,
        profileRepository: profileRepo,
      );

      clientB = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authB,
        profileRepository: profileRepo,
      );
    });

    test(
      'Step 1-4: Player A creates room, Player B joins -> Player A immediately sees Player B',
      () async {
        // 1. Player A creates room
        final room = await clientA.createRoom(
          name: "Alice's Room",
          maxPlayers: 4,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        expect(room.hostId, equals('user_player_A'));
        expect(room.isWaiting, isTrue);

        // Player A watches room players
        final playersInitialA = await clientA.getRoomPlayers(room.id);
        expect(playersInitialA.length, equals(1));
        expect(playersInitialA.first.userId, equals('user_player_A'));
        expect(playersInitialA.first.isHost, isTrue);

        // 2. Player B joins room by code using Client B
        final joinedRoom = await clientB.joinRoomByCode(room.code);
        expect(joinedRoom.id, equals(room.id));

        // Both Player A and Player B see 2 players
        final playersA = await clientA.getRoomPlayers(room.id);
        expect(playersA.length, equals(2));
        expect(playersA.any((p) => p.userId == 'user_player_B'), isTrue);

        final playersB = await clientB.getRoomPlayers(room.id);
        expect(playersB.length, equals(2));
      },
    );

    test('Step 5-6: Player B Ready Up -> Reflected across clients', () async {
      final room = await clientA.createRoom(
        name: 'Ready Test Room',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      // Join Player B
      await clientB.joinRoomByCode(room.code);

      // Initial: Player B is not ready
      var players = await clientA.getRoomPlayers(room.id);
      final playerB = players.firstWhere((p) => p.userId == 'user_player_B');
      expect(playerB.isReady, isFalse);

      // Player B toggles ready
      await clientB.toggleReady(roomId: room.id, isReady: true);

      // Both clients see that Player B is now READY
      players = await clientA.getRoomPlayers(room.id);
      final playerBReadyA = players.firstWhere(
        (p) => p.userId == 'user_player_B',
      );
      expect(playerBReadyA.isReady, isTrue);

      final playersB = await clientB.getRoomPlayers(room.id);
      final playerBReadyB = playersB.firstWhere(
        (p) => p.userId == 'user_player_B',
      );
      expect(playerBReadyB.isReady, isTrue);
    });

    test(
      'Step 7: Host Start Game Validation: Rejected if any player is NOT ready',
      () async {
        final room = await clientA.createRoom(
          name: 'Start Validation Room',
          maxPlayers: 4,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        // Try starting with only 1 player -> Must be rejected
        await expectLater(
          () => clientA.startGame(room.id),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('At least 2 players are required'),
            ),
          ),
        );

        // Player B joins
        await clientB.joinRoomByCode(room.code);

        // Player B is NOT ready yet -> Must be rejected with not ready name "Bob (Joiner)"
        await expectLater(
          () => clientA.startGame(room.id),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Bob (Joiner)'),
            ),
          ),
        );

        // Toggle Player B Ready
        await clientB.toggleReady(roomId: room.id, isReady: true);

        // Now Host starts game successfully!
        await clientA.startGame(room.id);

        final updatedRoomA = await clientA.getRoom(room.id);
        expect(updatedRoomA?.status, equals(RoomStatus.preparing));

        final updatedRoomB = await clientB.getRoom(room.id);
        expect(updatedRoomB?.status, equals(RoomStatus.preparing));
      },
    );

    test(
      'Step 8-9: Player leaves room -> Membership updates immediately',
      () async {
        final room = await clientA.createRoom(
          name: 'Leave Test Room',
          maxPlayers: 4,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        await clientB.joinRoomByCode(room.code);
        var players = await clientA.getRoomPlayers(room.id);
        expect(players.length, equals(2));

        // Player B leaves room
        await clientB.leaveRoom(room.id);

        // Player A immediately sees only 1 player remaining
        players = await clientA.getRoomPlayers(room.id);
        expect(players.length, equals(1));
        expect(players.first.userId, equals('user_player_A'));
        expect(players.first.isHost, isTrue);
      },
    );

    test('Network Monitoring: Status states adhere to Part 8 requirements', () {
      expect(NetworkStatus.online.isOnline, isTrue);
      expect(NetworkStatus.online.canPlayMultiplayer, isTrue);
      expect(NetworkStatus.offline.isOnline, isFalse);
      expect(NetworkStatus.offline.canPlayMultiplayer, isFalse);
      expect(NetworkStatus.backendUnavailable.canPlayMultiplayer, isFalse);
      expect(NetworkStatus.realtimeDisconnected.canPlayMultiplayer, isFalse);

      expect(NetworkStatus.offline.displayTitle, equals("You're Offline"));
      expect(
        NetworkStatus.backendUnavailable.displayTitle,
        equals("Server temporarily unavailable"),
      );
      expect(
        NetworkStatus.reconnecting.displayTitle,
        equals("Reconnecting..."),
      );
      expect(
        NetworkStatus.realtimeDisconnected.displayTitle,
        equals("Restoring live connection..."),
      );
    });

    test(
      'No Mock Progress: Initial career statistics strictly start at 0',
      () async {
        final freshStats = await profileRepo.getCareerStats('brand_new_user');
        expect(freshStats.totalMatches, equals(0));
        expect(freshStats.wins, equals(0));
        expect(freshStats.losses, equals(0));
        expect(freshStats.draws, equals(0));
        expect(freshStats.currentStreak, equals(0));
        expect(freshStats.winRatePercentage, equals(0));

        // Record a verified victory
        await profileRepo.recordMatchResult(
          userId: 'brand_new_user',
          outcome: MatchOutcome.victory,
          linesClaimed: 5,
          callsCount: 16,
          isMultiplayer: false,
        );

        final updatedStats = await profileRepo.getCareerStats('brand_new_user');
        expect(updatedStats.totalMatches, equals(1));
        expect(updatedStats.wins, equals(1));
        expect(updatedStats.currentStreak, equals(1));
        expect(updatedStats.winRatePercentage, equals(100));
      },
    );

    test(
      'Reward Claims: Idempotency, immediate credit and duplicate protection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final rewardsRepo = RewardsRepositoryImpl(
          supabase: null,
          authRepo: authA,
          profileRepo: profileRepo,
        );

        // Initial checkin
        final initialInfo = await rewardsRepo.getDailyCheckin();
        expect(initialInfo.isClaimedToday, isFalse);

        // First claim succeeds
        final rewardAmount = await rewardsRepo.claimDailyCheckin();
        expect(rewardAmount, greaterThan(0));

        final postClaimInfo = await rewardsRepo.getDailyCheckin();
        expect(postClaimInfo.isClaimedToday, isTrue);

        // Second claim attempt must be rejected immediately (idempotency protection)
        await expectLater(
          () => rewardsRepo.claimDailyCheckin(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already claimed'),
            ),
          ),
        );
      },
    );

    test(
      'Achievement Lifecycle: locked -> inProgress -> ready -> claimed with zero initial values',
      () async {
        SharedPreferences.setMockInitialValues({});
        final achRepo = AchievementsRepositoryImpl(
          supabase: null,
          authRepo: authA,
          profileRepo: profileRepo,
        );

        // Verify all initial achievements start at 0 (locked)
        final initial = await achRepo.getAchievements();
        final gettingStarted = initial.firstWhere(
          (a) => a.id == 'card-getting-started',
        );
        expect(gettingStarted.current, equals(0));
        expect(gettingStarted.status, equals(AchievementStatus.locked));

        // Progress updates to 5/10 -> inProgress
        await achRepo.updateProgress('card-getting-started', 5);
        var currentList = await achRepo.getAchievements();
        var item = currentList.firstWhere(
          (a) => a.id == 'card-getting-started',
        );
        expect(item.current, equals(5));
        expect(item.status, equals(AchievementStatus.inProgress));

        // Progress completes to 10/10 -> ready to claim
        await achRepo.updateProgress('card-getting-started', 10);
        currentList = await achRepo.getAchievements();
        item = currentList.firstWhere((a) => a.id == 'card-getting-started');
        expect(item.current, equals(10));
        expect(item.status, equals(AchievementStatus.ready));

        // Claim reward -> moves to claimed
        final claimedChips = await achRepo.claimAchievement(
          'card-getting-started',
        );
        expect(claimedChips, equals(100));

        currentList = await achRepo.getAchievements();
        item = currentList.firstWhere((a) => a.id == 'card-getting-started');
        expect(item.status, equals(AchievementStatus.claimed));

        // Duplicate claim rejected
        await expectLater(
          () => achRepo.claimAchievement('card-getting-started'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already been claimed'),
            ),
          ),
        );
      },
    );
  });
}
