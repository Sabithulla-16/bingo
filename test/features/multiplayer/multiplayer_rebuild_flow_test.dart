import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Multiplayer Rebuild Complete Flow Tests (2, 3, and 4 Players)', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;

    final p1 = PlayerProfile(
      id: 'p1_host',
      displayName: 'Alice (Host)',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final p2 = PlayerProfile(
      id: 'p2_guest',
      displayName: 'Bob (Guest)',
      email: 'bob@bingo.dev',
      avatarColorHex: '#20243A',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final p3 = PlayerProfile(
      id: 'p3_guest',
      displayName: 'Charlie (Guest)',
      email: 'charlie@bingo.dev',
      avatarColorHex: '#4CAF50',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final p4 = PlayerProfile(
      id: 'p4_guest',
      displayName: 'Diana (Guest)',
      email: 'diana@bingo.dev',
      avatarColorHex: '#FFD166',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(p1);
      mockProfile = MockProfileRepository(p1);
      mockProfile.setProfile(p2);
      mockProfile.setProfile(p3);
      mockProfile.setProfile(p4);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test('2-Player Flow: Board Prep -> InProgress -> Line Claims -> Victory -> Rematch', () async {
      // 1. Create Room & Join
      mockAuth.currentProfile = p1;
      final room = await repository.createRoom(
        name: '2-Player Arena',
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      mockAuth.currentProfile = p2;
      await repository.joinRoomByCode(room.code);

      final game = await repository.getGameForRoom(room.id);
      expect(game.status, equals(MultiplayerGameStatus.preparing));

      final seqBoard = List<int>.generate(25, (i) => i + 1);

      // 2. Both players submit boards
      mockAuth.currentProfile = p1;
      await repository.submitBoard(
        gameId: game.id,
        numbers: seqBoard,
      );

      mockAuth.currentProfile = p2;
      await repository.submitBoard(
        gameId: game.id,
        numbers: seqBoard,
      );

      // Verify atomic transition to inProgress
      var activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.inProgress));
      expect(activeGame.currentTurnUserId, equals(p1.id));

      // 3. Turn alternation
      mockAuth.currentProfile = p1;
      await repository.callNumber(gameId: activeGame.id, number: 7);

      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.calledNumbers, contains(7));
      expect(activeGame.currentTurnUserId, equals(p2.id));

      // 4. Manual Line Claim outside turn (Player 1 claims Row 0 even though it is Player 2 turn)
      mockAuth.currentProfile = p1;
      final won1 = await repository.claimLine(
        gameId: activeGame.id,
        lineType: 'Row 0',
        numbers: seqBoard.sublist(0, 5),
      );
      expect(won1, isFalse);

      var players = await repository.watchGamePlayers(activeGame.id).first;
      var p1State = players.firstWhere((p) => p.userId == p1.id);
      expect(p1State.linesClaimed, equals(1));

      // 5. Overlapping lines claim (Column 0 shares cell (0,0) with Row 0)
      final won2 = await repository.claimLine(
        gameId: activeGame.id,
        lineType: 'Col 0',
        numbers: [seqBoard[0], seqBoard[5], seqBoard[10], seqBoard[15], seqBoard[20]],
      );
      expect(won2, isFalse);
      players = await repository.watchGamePlayers(activeGame.id).first;
      p1State = players.firstWhere((p) => p.userId == p1.id);
      expect(p1State.linesClaimed, equals(2));

      // 6. Complete 5 lines for Victory
      await repository.claimLine(
        gameId: activeGame.id,
        lineType: 'Row 1',
        numbers: seqBoard.sublist(5, 10),
      );
      await repository.claimLine(
        gameId: activeGame.id,
        lineType: 'Row 2',
        numbers: seqBoard.sublist(10, 15),
      );
      final wonFinal = await repository.claimLine(
        gameId: activeGame.id,
        lineType: 'Row 3',
        numbers: seqBoard.sublist(15, 20),
      );
      expect(wonFinal, isTrue);

      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.completed));
      expect(activeGame.winnerUserId, equals(p1.id));

      // 7. Rematch / Start Next Round
      mockAuth.currentProfile = p1;
      await repository.startNextRound(
        gameId: activeGame.id,
        roomId: room.id,
        hostId: p1.id,
      );

      final nextRoundGame = await repository.getGameForRoom(room.id);
      final updatedRoom = await repository.getRoom(room.id);

      expect(nextRoundGame.roundNumber, equals(2));
      expect(nextRoundGame.status, equals(MultiplayerGameStatus.preparing));
      expect(nextRoundGame.calledNumbers, isEmpty);
      expect(updatedRoom?.status, equals(RoomStatus.preparing));
    });

    test('3-Player Flow: Circular Turn Progression across 3 Participants', () async {
      mockAuth.currentProfile = p1;
      final room = await repository.createRoom(
        name: 'Trio Championship',
        maxPlayers: 3,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      mockAuth.currentProfile = p2;
      await repository.joinRoomByCode(room.code);

      mockAuth.currentProfile = p3;
      await repository.joinRoomByCode(room.code);

      final roomPlayers = await repository.getRoomPlayers(room.id);
      expect(roomPlayers.length, equals(3));

      final game = await repository.getGameForRoom(room.id);

      // All 3 confirm boards
      for (final player in [p1, p2, p3]) {
        mockAuth.currentProfile = player;
        await repository.submitBoard(
          gameId: game.id,
          numbers: BingoBoard.quickShuffle().numbers,
        );
      }

      var activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.inProgress));
      expect(activeGame.currentTurnUserId, equals(p1.id));

      // Alice calls -> Bob's turn
      mockAuth.currentProfile = p1;
      await repository.callNumber(gameId: activeGame.id, number: 10);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p2.id));

      // Bob calls -> Charlie's turn
      mockAuth.currentProfile = p2;
      await repository.callNumber(gameId: activeGame.id, number: 15);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p3.id));

      // Charlie calls -> loops back to Alice
      mockAuth.currentProfile = p3;
      await repository.callNumber(gameId: activeGame.id, number: 20);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p1.id));
    });

    test('4-Player Flow: Full Capacity Circular Turns and Membership', () async {
      mockAuth.currentProfile = p1;
      final room = await repository.createRoom(
        name: 'Quad Showdown',
        maxPlayers: 4,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      for (final guest in [p2, p3, p4]) {
        mockAuth.currentProfile = guest;
        await repository.joinRoomByCode(room.code);
      }

      final roomPlayers = await repository.getRoomPlayers(room.id);
      expect(roomPlayers.length, equals(4));

      final game = await repository.getGameForRoom(room.id);

      for (final player in [p1, p2, p3, p4]) {
        mockAuth.currentProfile = player;
        await repository.submitBoard(
          gameId: game.id,
          numbers: BingoBoard.quickShuffle().numbers,
        );
      }

      var activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.inProgress));

      // Test 4-step turn loop
      mockAuth.currentProfile = p1;
      await repository.callNumber(gameId: activeGame.id, number: 1);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p2.id));

      mockAuth.currentProfile = p2;
      await repository.callNumber(gameId: activeGame.id, number: 2);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p3.id));

      mockAuth.currentProfile = p3;
      await repository.callNumber(gameId: activeGame.id, number: 3);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p4.id));

      mockAuth.currentProfile = p4;
      await repository.callNumber(gameId: activeGame.id, number: 4);
      activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.currentTurnUserId, equals(p1.id));
    });

    test('Host Controls: Expired Timer removes unready players and starts with remaining >= 2', () async {
      mockAuth.currentProfile = p1;
      final room = await repository.createRoom(
        name: 'Timeout Test',
        maxPlayers: 3,
        prepTimeSeconds: 10,
        turnTimeSeconds: 15,
      );

      mockAuth.currentProfile = p2;
      await repository.joinRoomByCode(room.code);

      mockAuth.currentProfile = p3;
      await repository.joinRoomByCode(room.code);

      final game = await repository.getGameForRoom(room.id);

      // p1 and p2 confirm boards, p3 stays unready
      mockAuth.currentProfile = p1;
      await repository.submitBoard(
        gameId: game.id,
        numbers: BingoBoard.quickShuffle().numbers,
      );

      mockAuth.currentProfile = p2;
      await repository.submitBoard(
        gameId: game.id,
        numbers: BingoBoard.quickShuffle().numbers,
      );

      var preGame = await repository.getGameForRoom(room.id);
      expect(preGame.status, equals(MultiplayerGameStatus.preparing));

      // Host evicts unready p3
      mockAuth.currentProfile = p1;
      await repository.removeUnreadyPlayers(roomId: room.id, gameId: game.id);

      final remainingPlayers = await repository.getRoomPlayers(room.id);
      expect(remainingPlayers.length, equals(2));
      expect(remainingPlayers.any((p) => p.userId == p3.id), isFalse);

      // Game transitions to inProgress with the remaining 2 ready players
      final updatedGame = await repository.getGameForRoom(room.id);
      expect(updatedGame.status, equals(MultiplayerGameStatus.inProgress));
    });

    test('Return to Room Lobby transitions room status to waiting and preserves membership', () async {
      mockAuth.currentProfile = p1;
      final room = await repository.createRoom(
        name: 'Lobby Return Room',
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      mockAuth.currentProfile = p2;
      await repository.joinRoomByCode(room.code);

      // Host returns room to waiting lobby
      await repository.returnToLobby(roomId: room.id, hostId: p1.id);

      final updatedRoom = await repository.getRoom(room.id);
      expect(updatedRoom?.status, equals(RoomStatus.waiting));

      final members = await repository.getRoomPlayers(room.id);
      expect(members.length, equals(2));
      expect(members.map((m) => m.userId), containsAll([p1.id, p2.id]));
    });
  });
}
