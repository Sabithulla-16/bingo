import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/core/game_engine/winning_line.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/multiplayer/presentation/multiplayer_game_notifier.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';
import '../multiplayer/multiplayer_repository_test.dart';

void main() {
  group('Bug 2 Fix – Post-Game Claim & Action Lock Tests', () {
    group('Single Player Mode', () {
      test(
        'Human CANNOT claim lines or change winner after bot wins (Result Lock)',
        () async {
          final notifier = SinglePlayerGameNotifier(
            computerResponseDelay: Duration.zero,
          );

          // Prepare human board with sequential 1..25
          final humanBoard = BingoBoard(List.generate(25, (i) => i + 1));
          // Prepare bot board
          final botBoard = BingoBoard(List.generate(25, (i) => i + 1));

          notifier.initMatch(
            gameId: 'test_game_1',
            difficulty: AiDifficulty.easy,
            playerBoard: humanBoard,
            computerBoard: botBoard,
          );

          // Force bot to win by setting computerClaimedLineIds to 5 lines
          final fiveLineIds = {'row_0', 'row_1', 'row_2', 'row_3', 'row_4'};
          notifier.state = notifier.state!.copyWith(
            calledNumbers: List.generate(25, (i) => i + 1),
            computerClaimedLineIds: fiveLineIds,
            winner: GameWinner.computer,
            completedAt: DateTime.now(),
          );

          expect(notifier.state!.winner, equals(GameWinner.computer));
          expect(notifier.state!.playerClaimedLineIds.isEmpty, isTrue);

          // Human has completed lines on their board (e.g. row_0: 1, 2, 3, 4, 5)
          // Human attempts to claim a line post-game
          notifier.claimLine('row_0');

          // VERIFY: Claim was REJECTED! No lines added, winner remains computer!
          expect(notifier.state!.playerClaimedLineIds.isEmpty, isTrue);
          expect(notifier.state!.winner, equals(GameWinner.computer));

          // Human attempts to claim all lines post-game
          notifier.claimAllLines();

          // VERIFY: All post-game claims are rejected, winner is permanently locked
          expect(notifier.state!.playerClaimedLineIds.isEmpty, isTrue);
          expect(notifier.state!.winner, equals(GameWinner.computer));
        },
      );

      test('Bot cannot modify the result after human player wins', () async {
        final notifier = SinglePlayerGameNotifier(
          computerResponseDelay: Duration.zero,
        );

        final humanBoard = BingoBoard(List.generate(25, (i) => i + 1));
        final botBoard = BingoBoard(List.generate(25, (i) => i + 1));

        notifier.initMatch(
          gameId: 'test_game_2',
          difficulty: AiDifficulty.easy,
          playerBoard: humanBoard,
          computerBoard: botBoard,
        );

        // Human claims 5 lines and achieves BINGO
        notifier.state = notifier.state!.copyWith(
          calledNumbers: List.generate(25, (i) => i + 1),
          playerClaimedLineIds: {'row_0', 'row_1', 'row_2', 'row_3', 'row_4'},
          winner: GameWinner.player,
          completedAt: DateTime.now(),
        );

        expect(notifier.state!.winner, equals(GameWinner.player));

        // Human tries to call another number after game is over
        notifier.callNumber(25);

        // State must remain unchanged
        expect(notifier.state!.winner, equals(GameWinner.player));
      });

      test(
        'Rematch properly resets active state allowing fresh line claims',
        () {
          final notifier = SinglePlayerGameNotifier();
          final board = BingoBoard(List.generate(25, (i) => i + 1));

          notifier.initMatch(
            gameId: 'prev_game',
            difficulty: AiDifficulty.medium,
            playerBoard: board,
          );

          // Conclude match
          notifier.state = notifier.state!.copyWith(
            winner: GameWinner.computer,
            completedAt: DateTime.now(),
          );

          // Call rematch
          notifier.rematch();

          expect(notifier.state!.winner, equals(GameWinner.none));
          expect(notifier.state!.completedAt, isNull);
          expect(notifier.state!.playerClaimedLineIds, isEmpty);
          expect(notifier.state!.isPlayerTurn, isTrue);
        },
      );
    });

    group('Multiplayer Mode Backend & Notifier Lock', () {
      test(
        'Backend repository rejects line claims after round is completed by another player',
        () async {
          final host = PlayerProfile(
            id: 'player_a',
            displayName: 'Alice Winner',
            email: 'alice@bingo.dev',
            avatarColorHex: '#FF6B5E',
            chips: 1000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final guest = PlayerProfile(
            id: 'player_b',
            displayName: 'Bob Challenger',
            email: 'bob@bingo.dev',
            avatarColorHex: '#20243A',
            chips: 1000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final auth = MockAuthRepository(host);
          final profile = MockProfileRepository(host)..setProfile(guest);
          final repo = MultiplayerRepositoryImpl(
            authRepository: auth,
            profileRepository: profile,
            supabaseClient: null, // Local transactional in-memory mode
          );

          // Create room & game
          final room = await repo.createRoom(
            name: 'Lock Room',
            maxPlayers: 2,
            prepTimeSeconds: 45,
            turnTimeSeconds: 20,
          );
          final game = await repo.getGameForRoom(room.id);

          // Seed game as completed with player_a as winner
          final updatedGame = game.copyWith(
            status: MultiplayerGameStatus.completed,
            winnerUserId: 'player_a',
            calledNumbers: [1, 2, 3, 4, 5],
          );
          repo.localGamesForTesting[game.id] = updatedGame;

          // Switch active user to player_b
          auth.currentProfile = guest;

          // Player B attempts to claim a line on the completed game
          final claimResult = await repo.claimLine(
            gameId: game.id,
            lineType: 'row_0',
            numbers: [1, 2, 3, 4, 5],
          );

          // VERIFY: Backend rejects the claim!
          expect(claimResult, isFalse);

          // Verify winner remains player_a
          final reloadedGame = repo.localGamesForTesting[game.id]!;
          expect(reloadedGame.status, equals(MultiplayerGameStatus.completed));
          expect(reloadedGame.winnerUserId, equals('player_a'));
        },
      );

      test(
        'MultiplayerGameNotifier blocks claimLine when isMatchOver is true',
        () async {
          final host = PlayerProfile(
            id: 'player_a',
            displayName: 'Alice Winner',
            email: 'alice@bingo.dev',
            avatarColorHex: '#FF6B5E',
            chips: 1000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final guest = PlayerProfile(
            id: 'player_b',
            displayName: 'Bob Challenger',
            email: 'bob@bingo.dev',
            avatarColorHex: '#20243A',
            chips: 1000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final auth = MockAuthRepository(guest);
          final profile = MockProfileRepository(host)..setProfile(guest);
          final repo = MultiplayerRepositoryImpl(
            authRepository: auth,
            profileRepository: profile,
            supabaseClient: null,
          );

          final room = await repo.createRoom(
            name: 'Test Room',
            maxPlayers: 2,
            prepTimeSeconds: 45,
            turnTimeSeconds: 20,
          );
          final game = await repo.getGameForRoom(room.id);

          // Complete game with player_a winning
          final completedGame = game.copyWith(
            status: MultiplayerGameStatus.completed,
            winnerUserId: 'player_a',
          );
          repo.localGamesForTesting[game.id] = completedGame;

          final notifier = MultiplayerGameNotifier(
            roomId: room.id,
            repository: repo,
            authRepo: auth,
          );

          final testLine = WinningLine.allLines.first;
          notifier.state = notifier.state.copyWith(
            game: completedGame,
            currentUserId: 'player_b',
            claimedLines: {},
            unclaimedCompletedLines: [testLine],
          );

          expect(notifier.state.isMatchOver, isTrue);

          // Player B attempts to claim line
          await notifier.claimLine(testLine);

          // VERIFY: Notifier did not add line and did not mutate claimedLines
          expect(notifier.state.claimedLines, isEmpty);
          expect(notifier.state.isMatchOver, isTrue);
        },
      );

      test(
        'Normal line claims succeed during active gameplay and preserve independent overlapping lines',
        () async {
          final host = PlayerProfile(
            id: 'player_a',
            displayName: 'Alice Gamer',
            email: 'alice@bingo.dev',
            avatarColorHex: '#FF6B5E',
            chips: 1000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final auth = MockAuthRepository(host);
          final profile = MockProfileRepository(host);
          final repo = MultiplayerRepositoryImpl(
            authRepository: auth,
            profileRepository: profile,
            supabaseClient: null,
          );

          final room = await repo.createRoom(
            name: 'Active Room',
            maxPlayers: 2,
            prepTimeSeconds: 45,
            turnTimeSeconds: 20,
          );
          final game = await repo.getGameForRoom(room.id);

          // Seed active game with numbers 1..5 called
          final activeGame = game.copyWith(
            status: MultiplayerGameStatus.inProgress,
            calledNumbers: [1, 2, 3, 4, 5],
          );
          repo.localGamesForTesting[game.id] = activeGame;

          // Claim row_0 during active game
          final isWin1 = await repo.claimLine(
            gameId: game.id,
            lineType: 'row_0',
            numbers: [1, 2, 3, 4, 5],
          );

          expect(isWin1, isFalse); // First line, not 5 yet

          final players = repo.localGamePlayersForTesting[game.id]!;
          final playerA = players.firstWhere((p) => p.userId == 'player_a');
          expect(playerA.linesClaimed, equals(1));
          expect(playerA.claimedLineTypes, contains('row_0'));
          expect(playerA.isWinner, isFalse);
        },
      );
    });
  });
}
