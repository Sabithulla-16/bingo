import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/authentication/domain/auth_repository.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/quick_match.dart';
import 'package:bingo/features/multiplayer/presentation/quick_match_notifier.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/profile/domain/profile_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  String? currentUserId;

  @override
  bool get isAuthenticated => currentUserId != null;

  @override
  Stream<AppAuthState> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProfileRepository implements ProfileRepository {
  final Map<String, PlayerProfile> _profiles = {};

  void setProfile(PlayerProfile p) => _profiles[p.id] = p;

  @override
  Future<PlayerProfile?> getProfile(String userId) async => _profiles[userId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAuthRepository authRepo;
  late MockProfileRepository profileRepo;
  late MultiplayerRepositoryImpl repo;

  final profileA = PlayerProfile(
    id: 'user_a',
    displayName: 'Alice',
    email: 'alice@bingo.app',
    avatarColorHex: '#20243A',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final profileB = PlayerProfile(
    id: 'user_b',
    displayName: 'Bob',
    email: 'bob@bingo.app',
    avatarColorHex: '#FC695C',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final profileC = PlayerProfile(
    id: 'user_c',
    displayName: 'Charlie',
    email: 'charlie@bingo.app',
    avatarColorHex: '#4CAF50',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    MultiplayerRepositoryImpl.resetStaticStoresForTesting();
    authRepo = MockAuthRepository();
    profileRepo = MockProfileRepository();
    repo = MultiplayerRepositoryImpl(
      authRepository: authRepo,
      profileRepository: profileRepo,
    );

    profileRepo.setProfile(profileA);
    profileRepo.setProfile(profileB);
    profileRepo.setProfile(profileC);
  });

  group('Strict Matchmaking Lifecycle Test Scenarios (A - I)', () {
    test('Test A – Normal matchmaking: A searches, B searches -> paired into exactly 1 match', () async {
      authRepo.currentUserId = 'user_a';
      final resA = await repo.enterMatchmaking();
      expect(resA['status'], equals('SEARCHING'));

      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      expect(resB['status'], equals('MATCHED'));
      expect(resB['match_id'], isNotNull);

      authRepo.currentUserId = 'user_a';
      final matchA = await repo.getActiveQuickMatch();
      expect(matchA, isNotNull);
      expect(matchA!.id, equals(resB['match_id']));
      expect(matchA.opponent?.displayName, equals('Bob'));
    });

    test('Test B – No available opponent: A searches, nobody else searches -> remains SEARCHING', () async {
      authRepo.currentUserId = 'user_a';
      final resA = await repo.enterMatchmaking();
      expect(resA['status'], equals('SEARCHING'));
      expect(resA['match_id'], isNull);

      final activeMatch = await repo.getActiveQuickMatch();
      expect(activeMatch, isNull);
    });

    test('Test C – Completed previous match: A and B complete match, A searches, B does not search -> A not paired with B', () async {
      // 1. Initial match between A and B
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      authRepo.currentUserId = 'user_b';
      final res1 = await repo.enterMatchmaking();
      final matchId1 = res1['match_id'] as String;

      // 2. Conclude match
      await repo.transitionToBoardPrep(matchId1);
      final qm = await repo.getQuickMatch(matchId1);
      await repo.forfeitMatch(gameId: qm!.gameId, roomId: qm.roomId);

      // 3. Player A starts new search. Player B has NOT searched.
      authRepo.currentUserId = 'user_a';
      final res2 = await repo.enterMatchmaking();

      // A MUST remain in SEARCHING state; must NOT be paired with previous opponent Bob!
      expect(res2['status'], equals('SEARCHING'));
      expect(res2['match_id'], isNull);
    });

    test('Test D – Both players explicitly search again: A searches, B searches -> paired in fresh match', () async {
      // Initial match
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      authRepo.currentUserId = 'user_b';
      final res1 = await repo.enterMatchmaking();
      final matchId1 = res1['match_id'] as String;

      // Conclude initial match
      await repo.transitionToBoardPrep(matchId1);
      final qm = await repo.getQuickMatch(matchId1);
      await repo.forfeitMatch(gameId: qm!.gameId, roomId: qm.roomId);

      // Both players explicitly search again
      authRepo.currentUserId = 'user_a';
      final resA2 = await repo.enterMatchmaking();
      expect(resA2['status'], equals('SEARCHING'));

      authRepo.currentUserId = 'user_b';
      final resB2 = await repo.enterMatchmaking();
      expect(resB2['status'], equals('MATCHED'));
      expect(resB2['match_id'], isNotNull);
      expect(resB2['match_id'], isNot(equals(matchId1)));
    });

    test('Test E – Duplicate requests: A sends multiple START SEARCHING requests -> single active queue state', () async {
      authRepo.currentUserId = 'user_a';
      final notifier = QuickMatchNotifier(
        repository: repo,
        authRepo: authRepo,
        profileRepo: profileRepo,
        authState: Authenticated(profileA),
      );

      // Send first search
      await notifier.startSearching();
      expect(notifier.state.isSearching, isTrue);

      // Second search call while already searching is rejected by guard
      await notifier.startSearching();
      expect(notifier.state.isSearching, isTrue);

      notifier.dispose();
    });

    test('Test F – Already active match: A is playing, sends another search -> no second match created', () async {
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      authRepo.currentUserId = 'user_b';
      final res1 = await repo.enterMatchmaking();
      final matchId1 = res1['match_id'] as String;

      // Player A attempts to enter matchmaking again while match 1 is active
      authRepo.currentUserId = 'user_a';
      final resDup = await repo.enterMatchmaking();
      expect(resDup['status'], equals('MATCHED'));
      // Must return existing match, not a newly generated one
      expect(resDup['match_id'], equals(matchId1));
    });

    test('Test G – Concurrent matchmaking: A, B, C enter queue -> each in only 1 match', () async {
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      expect(resB['status'], equals('MATCHED'));

      // Player C enters -> cannot steal A or B who are already matched!
      authRepo.currentUserId = 'user_c';
      final resC = await repo.enterMatchmaking();
      expect(resC['status'], equals('SEARCHING'));
      expect(resC['match_id'], isNull);
    });

    test('Test H – Cancelled search: A starts and cancels, B starts -> A is not selected', () async {
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      final resCancel = await repo.cancelMatchmaking();
      expect(resCancel['status'], equals('CANCELLED'));

      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      // Bob must not pair with Alice whose entry was cancelled
      expect(resB['status'], equals('SEARCHING'));
      expect(resB['match_id'], isNull);
    });

    test('Test I – Stale Realtime event: old MATCHED entry does not hijack new search session', () async {
      authRepo.currentUserId = 'user_a';
      final notifier = QuickMatchNotifier(
        repository: repo,
        authRepo: authRepo,
        profileRepo: profileRepo,
        authState: Authenticated(profileA),
      );

      // Start new search
      await notifier.startSearching();
      expect(notifier.state.isSearching, isTrue);

      // Create a stale entry timestamped 30 seconds ago
      final staleEntry = MatchmakingQueueEntry(
        id: 'old_queue_1',
        userId: 'user_a',
        status: MatchmakingQueueStatus.matched,
        matchId: 'stale_match_123',
        queuedAt: DateTime.now().subtract(const Duration(seconds: 30)),
        matchedAt: DateTime.now().subtract(const Duration(seconds: 25)),
      );

      // Emit stale entry to repository stream
      repo.emitQueueUpdateForTesting('user_a', staleEntry);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Notifier MUST reject the stale entry and stay in SEARCHING state!
      expect(notifier.state.isSearching, isTrue);
      expect(notifier.state.matchId, isNull);

      notifier.dispose();
    });
  });
}
