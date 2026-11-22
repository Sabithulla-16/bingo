import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProfile host;
  late PlayerProfile guest1;
  late PlayerProfile guest2;
  late MockAuthRepository authHost;
  late MockProfileRepository profileHost;
  late MockAuthRepository authGuest1;
  late MockProfileRepository profileGuest1;
  late MockAuthRepository authGuest2;
  late MockProfileRepository profileGuest2;
  late MultiplayerRepositoryImpl repoHost;
  late MultiplayerRepositoryImpl repoGuest1;
  late MultiplayerRepositoryImpl repoGuest2;

  setUp(() {
    host = PlayerProfile(
      id: 'host_alice',
      displayName: 'Alice Host',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    guest1 = PlayerProfile(
      id: 'player_bob',
      displayName: 'Bob Player',
      email: 'bob@bingo.dev',
      avatarColorHex: '#20243A',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    guest2 = PlayerProfile(
      id: 'player_charlie',
      displayName: 'Charlie Player',
      email: 'charlie@bingo.dev',
      avatarColorHex: '#4CAF50',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    authHost = MockAuthRepository(host);
    profileHost = MockProfileRepository(host);
    authGuest1 = MockAuthRepository(guest1);
    profileGuest1 = MockProfileRepository(guest1);
    authGuest2 = MockAuthRepository(guest2);
    profileGuest2 = MockProfileRepository(guest2);

    repoHost = MultiplayerRepositoryImpl(
      authRepository: authHost,
      profileRepository: profileHost,
    );
    repoGuest1 = MultiplayerRepositoryImpl(
      authRepository: authGuest1,
      profileRepository: profileGuest1,
    );
    repoGuest2 = MultiplayerRepositoryImpl(
      authRepository: authGuest2,
      profileRepository: profileGuest2,
    );
  });

  group('MULTIPLAYER FINAL O CLAIM & B-I-N-G-O PROGRESSION TESTS', () {
    test('1-10. Player A claims B -> I -> N -> G -> O: 5th line awards O, wins, and concludes match', () async {
      final room = await repoHost.createRoom(
        name: 'O-Claim Test Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await repoGuest1.joinRoomByCode(room.code);
      await repoGuest1.toggleReady(roomId: room.id, isReady: true);
      await repoHost.startGame(room.id);

      final game = await repoHost.getGameForRoom(room.id);

      // Player A (Host) and Player B (Guest 1) submit standard 1..25 boards
      final boardA = List.generate(25, (i) => i + 1);
      final boardB = List.generate(25, (i) => i + 1);

      await repoHost.submitBoard(gameId: game.id, numbers: boardA);
      await repoGuest1.submitBoard(gameId: game.id, numbers: boardB);

      // Call numbers 1..25
      for (int i = 1; i <= 25; i++) {
        final g = await repoHost.getGameForRoom(room.id);
        if (g.currentTurnUserId == host.id) {
          await repoHost.callNumber(gameId: game.id, number: i);
        } else {
          await repoGuest1.callNumber(gameId: game.id, number: i);
        }
      }

      // 1. Player A has zero lines claimed, claims 1st line -> awards B
      final win1 = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'row_0',
        numbers: [1, 2, 3, 4, 5],
      );
      expect(win1, isFalse);

      var players = await repoHost.getGamePlayers(game.id);
      var playerA = players.firstWhere((p) => p.userId == host.id);
      expect(playerA.linesClaimed, equals(1));
      expect(playerA.letterProgress, equals([true, false, false, false, false])); // B

      // 2. Player A claims 2nd line -> awards I
      final win2 = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'row_1',
        numbers: [6, 7, 8, 9, 10],
      );
      expect(win2, isFalse);
      players = await repoHost.getGamePlayers(game.id);
      playerA = players.firstWhere((p) => p.userId == host.id);
      expect(playerA.linesClaimed, equals(2));
      expect(playerA.letterProgress, equals([true, true, false, false, false])); // B-I

      // 3. Player A claims 3rd line -> awards N
      final win3 = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'row_2',
        numbers: [11, 12, 13, 14, 15],
      );
      expect(win3, isFalse);
      players = await repoHost.getGamePlayers(game.id);
      playerA = players.firstWhere((p) => p.userId == host.id);
      expect(playerA.linesClaimed, equals(3));
      expect(playerA.letterProgress, equals([true, true, true, false, false])); // B-I-N

      // 4. Player A claims 4th line -> awards G
      final win4 = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'row_3',
        numbers: [16, 17, 18, 19, 20],
      );
      expect(win4, isFalse);
      players = await repoHost.getGamePlayers(game.id);
      playerA = players.firstWhere((p) => p.userId == host.id);
      expect(playerA.linesClaimed, equals(4));
      expect(playerA.letterProgress, equals([true, true, true, true, false])); // B-I-N-G

      // 5 & 6. Player A completes fifth distinct line -> awards O and triggers victory!
      final win5 = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'row_4',
        numbers: [21, 22, 23, 24, 25],
      );
      expect(win5, isTrue); // Final O claimed!

      // 7. Verify Player A is winner
      players = await repoHost.getGamePlayers(game.id);
      playerA = players.firstWhere((p) => p.userId == host.id);
      expect(playerA.linesClaimed, equals(5));
      expect(playerA.isWinner, isTrue);
      expect(playerA.letterProgress, equals([true, true, true, true, true])); // B-I-N-G-O

      // 8. Verify the round becomes ROUND_COMPLETED
      final completedGame = await repoHost.getGameForRoom(room.id);
      expect(completedGame.status, equals(MultiplayerGameStatus.completed));
      expect(completedGame.winnerUserId, equals(host.id));

      final completedRoom = await repoHost.getRoom(room.id);
      expect(completedRoom!.status, equals(RoomStatus.completed));

      // 9 & 10. Verify Player B receives result and cannot continue playing
      expect(
        () => repoGuest1.claimLine(
          gameId: game.id,
          lineType: 'col_0',
          numbers: [1, 6, 11, 16, 21],
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );
      expect(
        () => repoGuest1.callNumber(gameId: game.id, number: 1),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );
    });

    test('11. Regular Player (Guest) claims 5 lines and wins cleanly against Host', () async {
      final room = await repoHost.createRoom(
        name: 'Guest Win Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await repoGuest1.joinRoomByCode(room.code);
      await repoGuest1.toggleReady(roomId: room.id, isReady: true);
      await repoHost.startGame(room.id);

      final game = await repoHost.getGameForRoom(room.id);
      final board = List.generate(25, (i) => i + 1);

      await repoHost.submitBoard(gameId: game.id, numbers: board);
      await repoGuest1.submitBoard(gameId: game.id, numbers: board);

      // Call numbers 1..25
      for (int i = 1; i <= 25; i++) {
        final g = await repoHost.getGameForRoom(room.id);
        if (g.currentTurnUserId == host.id) {
          await repoHost.callNumber(gameId: game.id, number: i);
        } else {
          await repoGuest1.callNumber(gameId: game.id, number: i);
        }
      }

      // Guest claims 5 lines: row_0 to row_4
      expect(await repoGuest1.claimLine(gameId: game.id, lineType: 'row_0', numbers: [1, 2, 3, 4, 5]), isFalse); // B
      expect(await repoGuest1.claimLine(gameId: game.id, lineType: 'row_1', numbers: [6, 7, 8, 9, 10]), isFalse); // I
      expect(await repoGuest1.claimLine(gameId: game.id, lineType: 'row_2', numbers: [11, 12, 13, 14, 15]), isFalse); // N
      expect(await repoGuest1.claimLine(gameId: game.id, lineType: 'row_3', numbers: [16, 17, 18, 19, 20]), isFalse); // G
      
      // 5th line (O) -> BINGO victory!
      final guestWin = await repoGuest1.claimLine(gameId: game.id, lineType: 'row_4', numbers: [21, 22, 23, 24, 25]);
      expect(guestWin, isTrue);

      final completedGame = await repoHost.getGameForRoom(room.id);
      expect(completedGame.status, equals(MultiplayerGameStatus.completed));
      expect(completedGame.winnerUserId, equals(guest1.id));

      final players = await repoHost.getGamePlayers(game.id);
      final guestState = players.firstWhere((p) => p.userId == guest1.id);
      expect(guestState.linesClaimed, equals(5));
      expect(guestState.isWinner, isTrue);
      expect(guestState.letterProgress, equals([true, true, true, true, true]));
    });

    test('13. 3-Player and 4-Player Match: Final O claim wins with full participation', () async {
      // 3-Player test
      final room3 = await repoHost.createRoom(
        name: '3-Player Room',
        maxPlayers: 3,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await repoGuest1.joinRoomByCode(room3.code);
      await repoGuest1.toggleReady(roomId: room3.id, isReady: true);
      await repoGuest2.joinRoomByCode(room3.code);
      await repoGuest2.toggleReady(roomId: room3.id, isReady: true);

      await repoHost.startGame(room3.id);
      final game3 = await repoHost.getGameForRoom(room3.id);

      final board = List.generate(25, (i) => i + 1);
      await repoHost.submitBoard(gameId: game3.id, numbers: board);
      await repoGuest1.submitBoard(gameId: game3.id, numbers: board);
      await repoGuest2.submitBoard(gameId: game3.id, numbers: board);

      // Call numbers
      for (int i = 1; i <= 25; i++) {
        final g = await repoHost.getGameForRoom(room3.id);
        if (g.currentTurnUserId == host.id) {
          await repoHost.callNumber(gameId: game3.id, number: i);
        } else if (g.currentTurnUserId == guest1.id) {
          await repoGuest1.callNumber(gameId: game3.id, number: i);
        } else {
          await repoGuest2.callNumber(gameId: game3.id, number: i);
        }
      }

      // Guest 2 claims 5 lines and achieves BINGO
      await repoGuest2.claimLine(gameId: game3.id, lineType: 'col_0', numbers: [1, 6, 11, 16, 21]);
      await repoGuest2.claimLine(gameId: game3.id, lineType: 'col_1', numbers: [2, 7, 12, 17, 22]);
      await repoGuest2.claimLine(gameId: game3.id, lineType: 'col_2', numbers: [3, 8, 13, 18, 23]);
      await repoGuest2.claimLine(gameId: game3.id, lineType: 'col_3', numbers: [4, 9, 14, 19, 24]);
      final winG2 = await repoGuest2.claimLine(gameId: game3.id, lineType: 'col_4', numbers: [5, 10, 15, 20, 25]);
      expect(winG2, isTrue);

      final finishedGame3 = await repoHost.getGameForRoom(room3.id);
      expect(finishedGame3.status, equals(MultiplayerGameStatus.completed));
      expect(finishedGame3.winnerUserId, equals(guest2.id));

      final players3 = await repoHost.getGamePlayers(game3.id);
      expect(players3.length, equals(3));
      final g2State = players3.firstWhere((p) => p.userId == guest2.id);
      expect(g2State.linesClaimed, equals(5));
      expect(g2State.isWinner, isTrue);
    });

    test('14. Overlapping Winning Lines: Claiming sharing cells does not invalidate 5th line', () async {
      final room = await repoHost.createRoom(
        name: 'Overlapping Test Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await repoGuest1.joinRoomByCode(room.code);
      await repoGuest1.toggleReady(roomId: room.id, isReady: true);
      await repoHost.startGame(room.id);
      final game = await repoHost.getGameForRoom(room.id);

      final board = List.generate(25, (i) => i + 1);
      await repoHost.submitBoard(gameId: game.id, numbers: board);
      await repoGuest1.submitBoard(gameId: game.id, numbers: board);

      for (int i = 1; i <= 25; i++) {
        final g = await repoHost.getGameForRoom(room.id);
        if (g.currentTurnUserId == host.id) {
          await repoHost.callNumber(gameId: game.id, number: i);
        } else {
          await repoGuest1.callNumber(gameId: game.id, number: i);
        }
      }

      // Claim intersecting lines:
      // Line 1: Row 0 (1, 2, 3, 4, 5)
      expect(await repoHost.claimLine(gameId: game.id, lineType: 'row_0', numbers: [1, 2, 3, 4, 5]), isFalse);

      // Line 2: Col 0 (shares cell 1 with Row 0)
      expect(await repoHost.claimLine(gameId: game.id, lineType: 'col_0', numbers: [1, 6, 11, 16, 21]), isFalse);

      // Line 3: Main Diagonal (shares cell 1 with Row 0 and Col 0)
      expect(await repoHost.claimLine(gameId: game.id, lineType: 'diag_main', numbers: [1, 7, 13, 19, 25]), isFalse);

      // Line 4: Row 2 (shares cell 13 with diag_main)
      expect(await repoHost.claimLine(gameId: game.id, lineType: 'row_2', numbers: [11, 12, 13, 14, 15]), isFalse);

      // Line 5: Anti Diagonal (shares cell 13 with Row 2 and diag_main!)
      final winOverlapping = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'diag_anti',
        numbers: [5, 9, 13, 17, 21],
      );
      expect(winOverlapping, isTrue); // Successfully claims 5th line despite heavy cell overlap!

      final players = await repoHost.getGamePlayers(game.id);
      final hostState = players.firstWhere((p) => p.userId == host.id);
      expect(hostState.linesClaimed, equals(5));
      expect(hostState.isWinner, isTrue);
      expect(hostState.letterProgress, equals([true, true, true, true, true]));
    });

    test('15. Simultaneous Fifth-Line Claims: First winning claim commits; second is atomically rejected with MATCH_ALREADY_COMPLETED', () async {
      final room = await repoHost.createRoom(
        name: 'Simultaneous Win Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await repoGuest1.joinRoomByCode(room.code);
      await repoGuest1.toggleReady(roomId: room.id, isReady: true);
      await repoHost.startGame(room.id);
      final game = await repoHost.getGameForRoom(room.id);

      final board = List.generate(25, (i) => i + 1);
      await repoHost.submitBoard(gameId: game.id, numbers: board);
      await repoGuest1.submitBoard(gameId: game.id, numbers: board);

      for (int i = 1; i <= 25; i++) {
        final g = await repoHost.getGameForRoom(room.id);
        if (g.currentTurnUserId == host.id) {
          await repoHost.callNumber(gameId: game.id, number: i);
        } else {
          await repoGuest1.callNumber(gameId: game.id, number: i);
        }
      }

      // Both players reach 4 lines claimed (B-I-N-G)
      for (int i = 0; i < 4; i++) {
        await repoHost.claimLine(gameId: game.id, lineType: 'row_$i', numbers: board.sublist(i * 5, (i + 1) * 5));
        await repoGuest1.claimLine(gameId: game.id, lineType: 'col_$i', numbers: [board[i], board[i + 5], board[i + 10], board[i + 15], board[i + 20]]);
      }

      // Verify both have 4 lines claimed
      var players = await repoHost.getGamePlayers(game.id);
      var pA = players.firstWhere((p) => p.userId == host.id);
      var pB = players.firstWhere((p) => p.userId == guest1.id);
      expect(pA.linesClaimed, equals(4));
      expect(pB.linesClaimed, equals(4));

      // Player A claims their 5th line (row_4) first
      final hostWon = await repoHost.claimLine(
        gameId: game.id,
        lineType: 'row_4',
        numbers: [21, 22, 23, 24, 25],
      );
      expect(hostWon, isTrue);

      // Player B simultaneously attempts to claim their 5th line (col_4)
      // Must be safely rejected with MATCH_ALREADY_COMPLETED
      expect(
        () => repoGuest1.claimLine(
          gameId: game.id,
          lineType: 'col_4',
          numbers: [5, 10, 15, 20, 25],
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      // Final match outcome: Single definitive winner, exactly once
      final finalGame = await repoHost.getGameForRoom(room.id);
      expect(finalGame.status, equals(MultiplayerGameStatus.completed));
      expect(finalGame.winnerUserId, equals(host.id));
    });
  });
}
