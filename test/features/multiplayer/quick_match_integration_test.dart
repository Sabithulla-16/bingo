import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/authentication/domain/auth_repository.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/quick_match.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/profile/domain/profile_repository.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockProfileRepository profileRepo;
  late MultiplayerRepositoryImpl repo;

  setUp(() {
    MultiplayerRepositoryImpl.resetStaticStoresForTesting();
    authRepo = MockAuthRepository();
    profileRepo = MockProfileRepository();
    repo = MultiplayerRepositoryImpl(
      authRepository: authRepo,
      profileRepository: profileRepo,
    );

    // Seed mock profiles
    profileRepo.setProfile(
      PlayerProfile(
        id: 'user_a',
        displayName: 'Alice',
        email: 'alice@bingo.app',
        avatarColorHex: '#20243A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    profileRepo.setProfile(
      PlayerProfile(
        id: 'user_b',
        displayName: 'Bob',
        email: 'bob@bingo.app',
        avatarColorHex: '#FC695C',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  group('Quick Match End-to-End Integration Flow', () {
    test('1. Matchmaking: Player A enters queue, Player B enters queue -> paired with identical match ID', () async {
      // Step 1: Player A enters queue
      authRepo.currentUserId = 'user_a';
      final queueStreamA = repo.watchMatchmakingQueue('user_a');
      MatchmakingQueueEntry? latestEntryA;
      final subA = queueStreamA.listen((entry) {
        if (entry != null) {
          latestEntryA = entry;
        }
      });

      final resA = await repo.enterMatchmaking();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(resA['success'], isTrue);
      expect(resA['status'], equals('SEARCHING'));
      expect(latestEntryA?.status, equals(MatchmakingQueueStatus.searching));

      // Step 2: Player B enters queue
      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      expect(resB['success'], isTrue);
      expect(resB['status'], equals('MATCHED'));

      final matchId = resB['match_id'] as String?;
      expect(matchId, isNotNull);
      final roomId = resB['room_id'] as String?;
      expect(roomId, isNotNull);
      final gameId = resB['game_id'] as String?;
      expect(gameId, isNotNull);

      // Verify Player A was also updated to MATCHED with the exact same match ID
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(latestEntryA?.status, equals(MatchmakingQueueStatus.matched));
      expect(latestEntryA?.matchId, equals(matchId));

      await subA.cancel();
    });

    test('2. Cancellation: Player starts searching, cancels search -> returned to idle, no stale entry', () async {
      authRepo.currentUserId = 'user_a';
      final resEnter = await repo.enterMatchmaking();
      expect(resEnter['status'], equals('SEARCHING'));

      final resCancel = await repo.cancelMatchmaking();
      expect(resCancel['success'], isTrue);
      expect(resCancel['status'], equals('CANCELLED'));

      // Player B enters afterwards -> should NOT pair with cancelled Player A
      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      expect(resB['status'], equals('SEARCHING'));
    });

    test('3. Countdown & Transition: Authoritative 10s deadline and transition to Board Preparation', () async {
      // Pair Player A and Player B
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      final matchId = resB['match_id'] as String;
      final roomId = resB['room_id'] as String;

      // Both players inspect quick match
      final qm = await repo.getQuickMatch(matchId);
      expect(qm, isNotNull);
      expect(qm!.status, equals(QuickMatchStatus.countdown));
      expect(qm.roomId, equals(roomId));

      // Transition to Board Preparation
      final resTransition = await repo.transitionToBoardPrep(matchId);
      expect(resTransition['success'], isTrue);
      expect(resTransition['status'], equals('BOARD_PREPARATION'));

      // Verify match state updated
      final updatedQm = await repo.getQuickMatch(matchId);
      expect(updatedQm!.status, equals(QuickMatchStatus.boardPreparation));

      // Verify room settings: max 2 players, 30s prep, 20s turns
      final room = await repo.getRoom(roomId);
      expect(room, isNotNull);
      expect(room!.maxPlayers, equals(2));
      expect(room.prepTimeSeconds, equals(30));
      expect(room.turnTimeSeconds, equals(20));
      expect(room.status, equals(RoomStatus.preparing));
    });

    test('4. Session Recovery: getActiveQuickMatch returns active match for reconnection', () async {
      authRepo.currentUserId = 'user_a';
      await repo.enterMatchmaking();
      authRepo.currentUserId = 'user_b';
      final resB = await repo.enterMatchmaking();
      final matchId = resB['match_id'] as String;

      // Simulate app restart / reconnection for Player A
      authRepo.currentUserId = 'user_a';
      final restoredMatch = await repo.getActiveQuickMatch();
      expect(restoredMatch, isNotNull);
      expect(restoredMatch!.id, equals(matchId));
      expect(restoredMatch.opponent?.displayName, equals('Bob'));
    });
  });
}

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
