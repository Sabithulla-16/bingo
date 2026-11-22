import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuth;
  late MockProfileRepository mockProfile;
  late MultiplayerRepositoryImpl repository;

  final hostProfile = PlayerProfile(
    id: 'host_id',
    displayName: 'Host Player',
    email: 'host@bingo.dev',
    avatarColorHex: '#20243A',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final guest1Profile = PlayerProfile(
    id: 'player_bob_id',
    displayName: 'Bob Player',
    email: 'bob@bingo.dev',
    avatarColorHex: '#FC695C',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final guest2Profile = PlayerProfile(
    id: 'player_charlie_id',
    displayName: 'Charlie Player',
    email: 'charlie@bingo.dev',
    avatarColorHex: '#F6B443',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthRepository(hostProfile);
    mockProfile = MockProfileRepository(hostProfile);
    mockProfile.setProfile(guest1Profile);
    mockProfile.setProfile(guest2Profile);

    repository = MultiplayerRepositoryImpl(
      authRepository: mockAuth,
      profileRepository: mockProfile,
    );
  });

  group('Multiplayer Forfeit Handling Tests', () {
    test('Scenario A (2-Player Match): Forfeit immediately finalizes match with remaining player as winner', () async {
      // 1. Create room and join guest
      final room = await repository.createRoom(
        name: '2-Player Arena',
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 20,
      );

      mockAuth.currentProfile = guest1Profile;
      await repository.joinRoomByCode(room.code);

      final game = await repository.getGameForRoom(room.id);

      // Both submit boards to enter inProgress
      mockAuth.currentProfile = hostProfile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => i + 1));
      mockAuth.currentProfile = guest1Profile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => 25 - i));

      final activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.inProgress));

      // Host chooses to forfeit
      mockAuth.currentProfile = hostProfile;
      final result = await repository.forfeitMatch(
        gameId: game.id,
        roomId: room.id,
      );

      expect(result['status'], equals('completed'));
      expect(result['winner_id'], equals(guest1Profile.id));
      expect(result['winner_name'], equals(guest1Profile.displayName));
      expect(result['is_forfeit'], isTrue);
      expect(result['forfeit_by_id'], equals(hostProfile.id));

      // Verify game state reflects forfeit victory
      final completedGame = await repository.getGameForRoom(room.id);
      expect(completedGame.status, equals(MultiplayerGameStatus.completed));
      expect(completedGame.winnerUserId, equals(guest1Profile.id));

      // Verify player states: host forfeited, guest not forfeited
      final players = await repository.getGamePlayers(game.id);
      final hostState = players.firstWhere((p) => p.userId == hostProfile.id);
      final guestState = players.firstWhere((p) => p.userId == guest1Profile.id);

      expect(hostState.isForfeited, isTrue);
      expect(guestState.isForfeited, isFalse);
    });

    test('Scenario B (3+ Player Match): Forfeit marks player forfeited, preserves match, and advances turn', () async {
      // 1. Create room with max 4
      final room = await repository.createRoom(
        name: '3-Player Arena',
        maxPlayers: 4,
        prepTimeSeconds: 30,
        turnTimeSeconds: 20,
      );

      mockAuth.currentProfile = guest1Profile;
      await repository.joinRoomByCode(room.code);

      mockAuth.currentProfile = guest2Profile;
      await repository.joinRoomByCode(room.code);

      final game = await repository.getGameForRoom(room.id);

      // Submit boards for all 3 players
      mockAuth.currentProfile = hostProfile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => i + 1));
      mockAuth.currentProfile = guest1Profile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => 25 - i));
      mockAuth.currentProfile = guest2Profile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => i + 1));

      final activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.inProgress));

      // Current turn player forfeits
      final currentTurnUid = activeGame.currentTurnUserId!;
      final forfeitingPlayer = currentTurnUid == hostProfile.id
          ? hostProfile
          : (currentTurnUid == guest1Profile.id ? guest1Profile : guest2Profile);

      mockAuth.currentProfile = forfeitingPlayer;
      final result = await repository.forfeitMatch(
        gameId: game.id,
        roomId: room.id,
      );

      expect(result['status'], equals('player_forfeited'));
      expect(result['forfeited_user_id'], equals(forfeitingPlayer.id));

      // Game must still be in progress with remaining active players
      final updatedGame = await repository.getGameForRoom(room.id);
      expect(updatedGame.status, equals(MultiplayerGameStatus.inProgress));

      // Turn must advance away from forfeited player
      expect(updatedGame.currentTurnUserId, isNot(equals(forfeitingPlayer.id)));

      // Forfeiter is marked isForfeited = true
      final players = await repository.getGamePlayers(game.id);
      final forfeiterState = players.firstWhere((p) => p.userId == forfeitingPlayer.id);
      expect(forfeiterState.isForfeited, isTrue);

      final remainingStates = players.where((p) => p.userId != forfeitingPlayer.id);
      for (final s in remainingStates) {
        expect(s.isForfeited, isFalse);
      }
    });

    test('Scenario C: Second forfeit in 3-player match leaves 1 active player and awards victory', () async {
      final room = await repository.createRoom(
        name: '3-Player Elimination',
        maxPlayers: 3,
        prepTimeSeconds: 30,
        turnTimeSeconds: 20,
      );

      mockAuth.currentProfile = guest1Profile;
      await repository.joinRoomByCode(room.code);
      mockAuth.currentProfile = guest2Profile;
      await repository.joinRoomByCode(room.code);

      final game = await repository.getGameForRoom(room.id);

      mockAuth.currentProfile = hostProfile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => i + 1));
      mockAuth.currentProfile = guest1Profile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => 25 - i));
      mockAuth.currentProfile = guest2Profile;
      await repository.submitBoard(gameId: game.id, numbers: List.generate(25, (i) => i + 1));

      // First player forfeits (host)
      mockAuth.currentProfile = hostProfile;
      await repository.forfeitMatch(gameId: game.id, roomId: room.id);

      // Second player forfeits (guest 1)
      mockAuth.currentProfile = guest1Profile;
      final secondResult = await repository.forfeitMatch(gameId: game.id, roomId: room.id);

      // Now only guest 2 remains -> match completes with guest 2 as winner
      expect(secondResult['status'], equals('completed'));
      expect(secondResult['winner_id'], equals(guest2Profile.id));

      final finalGame = await repository.getGameForRoom(room.id);
      expect(finalGame.status, equals(MultiplayerGameStatus.completed));
      expect(finalGame.winnerUserId, equals(guest2Profile.id));
    });
  });
}
