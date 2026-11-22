import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Multiplayer Gameplay Sync & In-Memory Engine Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;

    final host = PlayerProfile(
      id: 'host_p1',
      displayName: 'Captain Alice',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final guest = PlayerProfile(
      id: 'challenger_p2',
      displayName: 'Challenger Bob',
      email: 'bob@bingo.dev',
      avatarColorHex: '#20243A',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(host);
      mockProfile = MockProfileRepository(host);
      mockProfile.setProfile(guest);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test('getGameForRoom seeds game and players in preparing state', () async {
      final room = await repository.createRoom(
        name: 'Sync Cup',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final game = await repository.getGameForRoom(room.id);
      expect(game.roomId, equals(room.id));
      expect(game.status, equals(MultiplayerGameStatus.preparing));
      expect(game.calledNumbers, isEmpty);
      expect(game.prepDeadline.isAfter(DateTime.now()), isTrue);
    });

    test(
      'submitBoard from all players advances game to inProgress and seats host as first caller',
      () async {
        final room = await repository.createRoom(
          name: 'Sync Cup',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        // Guest joins
        mockAuth.currentProfile = guest;
        await repository.joinRoomByCode(room.code);

        final game = await repository.getGameForRoom(room.id);

        // Host submits board
        mockAuth.currentProfile = host;
        final boardHost = BingoBoard.quickShuffle().numbers;
        await repository.submitBoard(gameId: game.id, numbers: boardHost);

        var updatedGame = await repository.getGameForRoom(room.id);
        expect(
          updatedGame.status,
          equals(MultiplayerGameStatus.preparing),
        ); // Still waiting for guest

        // Guest submits board
        mockAuth.currentProfile = guest;
        final boardGuest = BingoBoard.quickShuffle().numbers;
        await repository.submitBoard(gameId: game.id, numbers: boardGuest);

        updatedGame = await repository.getGameForRoom(room.id);
        expect(updatedGame.status, equals(MultiplayerGameStatus.inProgress));
        expect(updatedGame.currentTurnUserId, equals(host.id));
        expect(updatedGame.turnDeadline, isNotNull);
      },
    );

    test(
      'callNumber appends called number and alternates turn to next seated player',
      () async {
        final room = await repository.createRoom(
          name: 'Turn Room',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        mockAuth.currentProfile = guest;
        await repository.joinRoomByCode(room.code);

        final game = await repository.getGameForRoom(room.id);

        // Both submit
        mockAuth.currentProfile = host;
        await repository.submitBoard(
          gameId: game.id,
          numbers: BingoBoard.quickShuffle().numbers,
        );
        mockAuth.currentProfile = guest;
        await repository.submitBoard(
          gameId: game.id,
          numbers: BingoBoard.quickShuffle().numbers,
        );

        // Host turn: calls 17
        mockAuth.currentProfile = host;
        await repository.callNumber(gameId: game.id, number: 17);

        var updatedGame = await repository.getGameForRoom(room.id);
        expect(updatedGame.calledNumbers, contains(17));
        expect(updatedGame.lastCalledNumber, equals(17));
        expect(updatedGame.currentTurnUserId, equals(guest.id));

        // Guest turn: calls 24
        mockAuth.currentProfile = guest;
        await repository.callNumber(gameId: game.id, number: 24);

        updatedGame = await repository.getGameForRoom(room.id);
        expect(updatedGame.calledNumbers, containsAll([17, 24]));
        expect(
          updatedGame.currentTurnUserId,
          equals(host.id),
        ); // Wrapped back to host
      },
    );

    test(
      'claimLine increments claimed lines count and marks winner upon 5 lines',
      () async {
        final room = await repository.createRoom(
          name: 'Winner Room',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        mockAuth.currentProfile = guest;
        await repository.joinRoomByCode(room.code);
        final game = await repository.getGameForRoom(room.id);

        // Host submits deterministic sequential board 1..25
        mockAuth.currentProfile = host;
        final seqBoard = List<int>.generate(25, (i) => i + 1);
        await repository.submitBoard(gameId: game.id, numbers: seqBoard);

        mockAuth.currentProfile = guest;
        await repository.submitBoard(gameId: game.id, numbers: seqBoard);

        // Host claims 4 lines
        mockAuth.currentProfile = host;
        for (int i = 0; i < 4; i++) {
          final won = await repository.claimLine(
            gameId: game.id,
            lineType: 'Row $i',
            numbers: seqBoard.sublist(i * 5, (i + 1) * 5),
          );
          expect(won, isFalse);
        }

        // 5th line claim triggers match victory!
        final hasWon = await repository.claimLine(
          gameId: game.id,
          lineType: 'Row 4',
          numbers: seqBoard.sublist(20, 25),
        );
        expect(hasWon, isTrue);

        final completedGame = await repository.getGameForRoom(room.id);
        expect(completedGame.status, equals(MultiplayerGameStatus.completed));
        expect(completedGame.winnerUserId, equals(host.id));
      },
    );

    test('extendPrepTime pushes prepDeadline into the future', () async {
      final room = await repository.createRoom(
        name: 'Prep Room',
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 20,
      );

      final game = await repository.getGameForRoom(room.id);
      final initialDeadline = game.prepDeadline;

      await repository.extendPrepTime(gameId: game.id, extensionSeconds: 30);
      final updatedGame = await repository.getGameForRoom(room.id);

      expect(
        updatedGame.prepDeadline.difference(initialDeadline).inSeconds,
        equals(30),
      );
    });
  });
}
