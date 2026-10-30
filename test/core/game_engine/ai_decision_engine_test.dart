import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';

void main() {
  group('AiDecisionEngine Tests', () {
    late BingoBoard board;

    setUp(() {
      // 1..25 row-major
      board = BingoBoard(List<int>.generate(25, (i) => i + 1));
    });

    test('getUncalledNumbers returns all numbers not in called set', () {
      final uncalled = AiDecisionEngine.getUncalledNumbers(board, {1, 2, 3});
      expect(uncalled.length, equals(22));
      expect(uncalled.contains(1), isFalse);
      expect(uncalled.contains(4), isTrue);
    });

    test('Easy AI always picks an uncalled number', () {
      final called = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
      for (int i = 0; i < 20; i++) {
        final pick = AiDecisionEngine.selectNextCall(
          board: board,
          calledNumbers: called,
          difficulty: AiDifficulty.easy,
        );
        expect(called.contains(pick), isFalse);
        expect(pick, inInclusiveRange(11, 25));
      }
    });

    test('Hard AI prioritizes completing a 4-marked line over arbitrary cells', () {
      // Row 0 has 1, 2, 3, 4 marked (only 5 is missing)
      final called = {1, 2, 3, 4, 11, 16, 21};

      final pick = AiDecisionEngine.selectNextCall(
        board: board,
        calledNumbers: called,
        difficulty: AiDifficulty.hard,
      );

      // Hard AI must pick 5 because it immediately completes Row 0!
      expect(pick, equals(5));
    });

    test('Hard AI prioritizes center cell (13) when multiple diagonal/row/col lines are open', () {
      // Center cell 13 intersects 4 lines (Row 2, Col 2, Diag Main, Diag Anti)
      final called = <int>{};

      final pick = AiDecisionEngine.selectNextCall(
        board: board,
        calledNumbers: called,
        difficulty: AiDifficulty.hard,
      );

      // Center cell 13 has the highest intersection density on an open board
      expect(pick, equals(13));
    });

    test('throws StateError when all numbers are already called', () {
      final all25 = List<int>.generate(25, (i) => i + 1).toSet();

      expect(
        () => AiDecisionEngine.selectNextCall(
          board: board,
          calledNumbers: all25,
          difficulty: AiDifficulty.easy,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
