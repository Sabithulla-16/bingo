import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/core/game_engine/board_coordinate.dart';

void main() {
  group('BingoBoard Tests', () {
    test(
      'quickShuffle produces a 100% valid bijection permutation of 1..25',
      () {
        final board = BingoBoard.quickShuffle();

        expect(board.numbers.length, equals(25));
        expect(board.isFilledAndValid, isTrue);
        expect(board.unassignedNumbers, isEmpty);

        // Verify bijection invariant: each number in 1..25 appears exactly once
        final setOfNumbers = board.numbers.toSet();
        expect(setOfNumbers.length, equals(25));
        for (int i = 1; i <= 25; i++) {
          expect(setOfNumbers.contains(i), isTrue);
        }
      },
    );

    test('empty board contains 25 zeroes and 25 unassigned numbers', () {
      final board = BingoBoard.empty();

      expect(board.numbers.length, equals(25));
      expect(board.numbers.every((n) => n == 0), isTrue);
      expect(board.isFilledAndValid, isFalse);
      expect(board.unassignedNumbers.length, equals(25));
    });

    test('getNumberAt and getNumberAtIndex access coordinates accurately', () {
      final numbers = List<int>.generate(25, (i) => i + 1);
      final board = BingoBoard(numbers);

      expect(board.getNumberAt(0, 0), equals(1));
      expect(board.getNumberAt(0, 4), equals(5));
      expect(board.getNumberAt(2, 2), equals(13)); // Center
      expect(board.getNumberAt(4, 4), equals(25));

      expect(board.getNumberAtIndex(0), equals(1));
      expect(board.getNumberAtIndex(12), equals(13));
      expect(board.getNumberAtIndex(24), equals(25));
    });

    test('findCoordinateOf locates number coordinates', () {
      final numbers = List<int>.generate(25, (i) => i + 1);
      final board = BingoBoard(numbers);

      expect(board.findCoordinateOf(1), equals(const BoardCoordinate(0, 0)));
      expect(board.findCoordinateOf(13), equals(const BoardCoordinate(2, 2)));
      expect(board.findCoordinateOf(25), equals(const BoardCoordinate(4, 4)));
      expect(board.findCoordinateOf(99), isNull);
    });

    test('setNumberAt and swapNumbers return new immutable copies', () {
      final board = BingoBoard.empty();
      final updated = board.setNumberAt(0, 0, 7);

      expect(board.getNumberAt(0, 0), equals(0)); // Original unmodified
      expect(updated.getNumberAt(0, 0), equals(7));

      final swapped = updated.swapNumbers(0, 1);
      expect(swapped.getNumberAtIndex(0), equals(0));
      expect(swapped.getNumberAtIndex(1), equals(7));
    });

    test('JSON serialization & deserialization preserves board state', () {
      final board = BingoBoard.quickShuffle();
      final json = board.toJson();
      final restored = BingoBoard.fromJson(json);

      expect(restored, equals(board));
      expect(restored.numbers, equals(board.numbers));
    });
  });
}
