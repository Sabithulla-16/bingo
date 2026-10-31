import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/board_coordinate.dart';
import 'package:bingo/core/game_engine/winning_line.dart';

void main() {
  group('WinningLine Tests', () {
    test('contains exactly 12 winning lines (5 rows, 5 cols, 2 diagonals)', () {
      expect(WinningLine.allLines.length, equals(12));

      final rows = WinningLine.allLines
          .where((l) => l.type == WinningLineType.horizontal)
          .toList();
      final cols = WinningLine.allLines
          .where((l) => l.type == WinningLineType.vertical)
          .toList();
      final diags = WinningLine.allLines
          .where((l) => l.type == WinningLineType.diagonal)
          .toList();

      expect(rows.length, equals(5));
      expect(cols.length, equals(5));
      expect(diags.length, equals(2));
    });

    test('every line contains exactly 5 unique coordinates', () {
      for (final line in WinningLine.allLines) {
        expect(line.coordinates.length, equals(5));
        expect(line.coordinates.toSet().length, equals(5));
      }
    });

    test('center cell (2, 2) intersects exactly 4 winning lines', () {
      const center = BoardCoordinate(2, 2);
      final intersecting = WinningLine.allLines
          .where((l) => l.containsCoordinate(center))
          .toList();

      expect(intersecting.length, equals(4));
      final ids = intersecting.map((l) => l.id).toSet();
      expect(ids, containsAll(['row_2', 'col_2', 'diag_main', 'diag_anti']));
    });

    test('corner cell (0, 0) intersects exactly 3 winning lines', () {
      const corner = BoardCoordinate(0, 0);
      final intersecting = WinningLine.allLines
          .where((l) => l.containsCoordinate(corner))
          .toList();

      expect(intersecting.length, equals(3));
      final ids = intersecting.map((l) => l.id).toSet();
      expect(ids, containsAll(['row_0', 'col_0', 'diag_main']));
    });

    test('containsIndex checks membership correctly', () {
      final row0 = WinningLine.allLines.firstWhere((l) => l.id == 'row_0');
      expect(row0.containsIndex(0), isTrue);
      expect(row0.containsIndex(4), isTrue);
      expect(row0.containsIndex(5), isFalse);
    });
  });
}
