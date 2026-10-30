import 'board_coordinate.dart';

enum WinningLineType { horizontal, vertical, diagonal }

/// Represents one of the 12 possible winning lines on a 5x5 Bingo board.
class WinningLine {
  final String id;
  final WinningLineType type;
  final String name;
  final List<BoardCoordinate> coordinates;

  const WinningLine({
    required this.id,
    required this.type,
    required this.name,
    required this.coordinates,
  }) : assert(coordinates.length == 5, 'A winning line must have exactly 5 cells');

  /// Human-readable label for line awards (e.g. 'Row 1', 'Main Diagonal')
  String get description => name;

  /// Set of all 12 predefined winning lines on a 5x5 board.
  static final List<WinningLine> allLines = [
    // 5 Horizontal Rows
    WinningLine(
      id: 'row_0',
      type: WinningLineType.horizontal,
      name: 'Row 1',
      coordinates: const [
        BoardCoordinate(0, 0),
        BoardCoordinate(0, 1),
        BoardCoordinate(0, 2),
        BoardCoordinate(0, 3),
        BoardCoordinate(0, 4),
      ],
    ),
    WinningLine(
      id: 'row_1',
      type: WinningLineType.horizontal,
      name: 'Row 2',
      coordinates: const [
        BoardCoordinate(1, 0),
        BoardCoordinate(1, 1),
        BoardCoordinate(1, 2),
        BoardCoordinate(1, 3),
        BoardCoordinate(1, 4),
      ],
    ),
    WinningLine(
      id: 'row_2',
      type: WinningLineType.horizontal,
      name: 'Row 3',
      coordinates: const [
        BoardCoordinate(2, 0),
        BoardCoordinate(2, 1),
        BoardCoordinate(2, 2),
        BoardCoordinate(2, 3),
        BoardCoordinate(2, 4),
      ],
    ),
    WinningLine(
      id: 'row_3',
      type: WinningLineType.horizontal,
      name: 'Row 4',
      coordinates: const [
        BoardCoordinate(3, 0),
        BoardCoordinate(3, 1),
        BoardCoordinate(3, 2),
        BoardCoordinate(3, 3),
        BoardCoordinate(3, 4),
      ],
    ),
    WinningLine(
      id: 'row_4',
      type: WinningLineType.horizontal,
      name: 'Row 5',
      coordinates: const [
        BoardCoordinate(4, 0),
        BoardCoordinate(4, 1),
        BoardCoordinate(4, 2),
        BoardCoordinate(4, 3),
        BoardCoordinate(4, 4),
      ],
    ),

    // 5 Vertical Columns
    WinningLine(
      id: 'col_0',
      type: WinningLineType.vertical,
      name: 'Column 1',
      coordinates: const [
        BoardCoordinate(0, 0),
        BoardCoordinate(1, 0),
        BoardCoordinate(2, 0),
        BoardCoordinate(3, 0),
        BoardCoordinate(4, 0),
      ],
    ),
    WinningLine(
      id: 'col_1',
      type: WinningLineType.vertical,
      name: 'Column 2',
      coordinates: const [
        BoardCoordinate(0, 1),
        BoardCoordinate(1, 1),
        BoardCoordinate(2, 1),
        BoardCoordinate(3, 1),
        BoardCoordinate(4, 1),
      ],
    ),
    WinningLine(
      id: 'col_2',
      type: WinningLineType.vertical,
      name: 'Column 3',
      coordinates: const [
        BoardCoordinate(0, 2),
        BoardCoordinate(1, 2),
        BoardCoordinate(2, 2),
        BoardCoordinate(3, 2),
        BoardCoordinate(4, 2),
      ],
    ),
    WinningLine(
      id: 'col_3',
      type: WinningLineType.vertical,
      name: 'Column 4',
      coordinates: const [
        BoardCoordinate(0, 3),
        BoardCoordinate(1, 3),
        BoardCoordinate(2, 3),
        BoardCoordinate(3, 3),
        BoardCoordinate(4, 3),
      ],
    ),
    WinningLine(
      id: 'col_4',
      type: WinningLineType.vertical,
      name: 'Column 5',
      coordinates: const [
        BoardCoordinate(0, 4),
        BoardCoordinate(1, 4),
        BoardCoordinate(2, 4),
        BoardCoordinate(3, 4),
        BoardCoordinate(4, 4),
      ],
    ),

    // 2 Diagonals
    WinningLine(
      id: 'diag_main',
      type: WinningLineType.diagonal,
      name: 'Main Diagonal',
      coordinates: const [
        BoardCoordinate(0, 0),
        BoardCoordinate(1, 1),
        BoardCoordinate(2, 2),
        BoardCoordinate(3, 3),
        BoardCoordinate(4, 4),
      ],
    ),
    WinningLine(
      id: 'diag_anti',
      type: WinningLineType.diagonal,
      name: 'Anti Diagonal',
      coordinates: const [
        BoardCoordinate(0, 4),
        BoardCoordinate(1, 3),
        BoardCoordinate(2, 2),
        BoardCoordinate(3, 1),
        BoardCoordinate(4, 0),
      ],
    ),
  ];

  /// Checks if this line passes through the given board coordinate.
  bool containsCoordinate(BoardCoordinate coord) {
    return coordinates.contains(coord);
  }

  /// Checks if this line passes through the cell at linear index (0..24).
  bool containsIndex(int index) {
    return coordinates.any((c) => c.index == index);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinningLine &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name ($id)';
}
