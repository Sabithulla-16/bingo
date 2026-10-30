import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';

void main() {
  group('SinglePlayerGameNotifier Unit Tests', () {
    late SinglePlayerGameNotifier notifier;
    late BingoBoard playerBoard;
    late BingoBoard botBoard;

    setUp(() {
      notifier = SinglePlayerGameNotifier();
      // Sequential 1..25 boards for deterministic tests
      playerBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));
      botBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initMatch sets up initial turn, boards, and empty history', () {
      notifier.initMatch(
        gameId: 'test_game',
        difficulty: AiDifficulty.easy,
        playerBoard: playerBoard,
        computerBoard: botBoard,
      );

      final state = notifier.state;
      expect(state, isNotNull);
      expect(state!.isPlayerTurn, isTrue);
      expect(state.isComputerThinking, isFalse);
      expect(state.calledNumbers, isEmpty);
      expect(state.playerClaimedLineIds, isEmpty);
      expect(state.computerClaimedLineIds, isEmpty);
      expect(state.winner, equals(GameWinner.none));
    });

    test('callNumber appends to called numbers and schedules computer response', () async {
      notifier.initMatch(
        gameId: 'test_game',
        difficulty: AiDifficulty.easy,
        playerBoard: playerBoard,
        computerBoard: botBoard,
      );

      // Player calls 1
      notifier.callNumber(1);

      expect(notifier.state!.calledNumbers, contains(1));
      expect(notifier.state!.isPlayerTurn, isFalse);
      expect(notifier.state!.isComputerThinking, isTrue);

      // Wait for computer turn timer (900ms)
      await Future.delayed(const Duration(milliseconds: 1000));

      expect(notifier.state!.isPlayerTurn, isTrue);
      expect(notifier.state!.isComputerThinking, isFalse);
      expect(notifier.state!.calledNumbers.length, equals(2)); // Player call + Bot call
    });

    test('claimLine awards letters and triggers GameWinner.player at 5 lines', () {
      notifier.initMatch(
        gameId: 'test_game',
        difficulty: AiDifficulty.easy,
        playerBoard: playerBoard,
        computerBoard: botBoard,
      );

      // Call Row 0: 1, 2, 3, 4, 5
      for (final n in [1, 2, 3, 4, 5]) {
        notifier.state = notifier.state!.copyWith(
          calledNumbers: [...notifier.state!.calledNumbers, n],
        );
      }

      expect(notifier.state!.playerEngine.unclaimedCompletedLines.map((l) => l.id), contains('row_0'));

      // Claim row_0
      notifier.claimLine('row_0');
      expect(notifier.state!.playerClaimedLineIds, contains('row_0'));
      expect(notifier.state!.playerEngine.claimedLetters, equals(['B']));
      expect(notifier.state!.winner, equals(GameWinner.none));

      // Manually simulate 4 more line claims to test 5-line BINGO victory
      notifier.state = notifier.state!.copyWith(
        playerClaimedLineIds: {'row_0', 'row_1', 'row_2', 'row_3'},
      );

      // Call Row 4: 21, 22, 23, 24, 25
      notifier.state = notifier.state!.copyWith(
        calledNumbers: [...notifier.state!.calledNumbers, 21, 22, 23, 24, 25],
      );

      notifier.claimLine('row_4');

      expect(notifier.state!.playerClaimedLineIds.length, equals(5));
      expect(notifier.state!.playerEngine.claimedLetters, equals(['B', 'I', 'N', 'G', 'O']));
      expect(notifier.state!.winner, equals(GameWinner.player));
    });

    test('draw condition triggers when both players achieve 5 lines simultaneously', () {
      notifier.initMatch(
        gameId: 'test_game',
        difficulty: AiDifficulty.easy,
        playerBoard: playerBoard,
        computerBoard: botBoard,
      );

      // Fill with 24 numbers, player already has 4 lines
      final first24 = List<int>.generate(24, (i) => i + 1);
      notifier.state = notifier.state!.copyWith(
        calledNumbers: first24,
        playerClaimedLineIds: {'row_0', 'row_1', 'row_2', 'row_3'},
      );

      // Number 25 will complete 5th line for both
      notifier.callNumber(25);
      expect(notifier.state!.winner, equals(GameWinner.draw));
    });
  });
}
