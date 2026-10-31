import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/board_coordinate.dart';

void main() {
  group('BoardCoordinate Tests', () {
    test(
      'creates coordinate with row and col and computes correct linear index',
      () {
        const coord = BoardCoordinate(2, 3);
        expect(coord.row, equals(2));
        expect(coord.col, equals(3));
        expect(coord.index, equals(13)); // 2 * 5 + 3 = 13
      },
    );

    test('fromIndex converts 0 through 24 accurately', () {
      expect(BoardCoordinate.fromIndex(0), equals(const BoardCoordinate(0, 0)));
      expect(BoardCoordinate.fromIndex(4), equals(const BoardCoordinate(0, 4)));
      expect(BoardCoordinate.fromIndex(5), equals(const BoardCoordinate(1, 0)));
      expect(
        BoardCoordinate.fromIndex(12),
        equals(const BoardCoordinate(2, 2)),
      ); // Center cell
      expect(
        BoardCoordinate.fromIndex(24),
        equals(const BoardCoordinate(4, 4)),
      ); // Bottom right
    });

    test('equality and hash code check', () {
      const c1 = BoardCoordinate(3, 4);
      const c2 = BoardCoordinate(3, 4);
      const c3 = BoardCoordinate(4, 3);

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1, isNot(equals(c3)));
    });

    test('throws on out-of-range rows, cols, or indices', () {
      expect(() => BoardCoordinate(-1, 0), throwsA(isA<AssertionError>()));
      expect(() => BoardCoordinate(0, 5), throwsA(isA<AssertionError>()));
      expect(
        () => BoardCoordinate.fromIndex(25),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BoardCoordinate.fromIndex(-1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
