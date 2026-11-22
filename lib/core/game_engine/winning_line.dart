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
  }) : assert(
         coordinates.length == 5,
         'A winning line must have exactly 5 cells',
       );

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

  /// Resolves a WinningLine by either its ID (e.g. 'row_0') or Name (e.g. 'Row 1', 'ROW_0'), case-insensitively.
  static WinningLine? findLine(String identifier) {
    final lower = identifier.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // 1. Direct ID match (e.g. 'row_0', 'col_2', 'diag_main')
    for (final line in allLines) {
      if (line.id.toLowerCase() == lower) return line;
    }

    // 2. Unambiguous exact lookup table for 0-indexed and standard aliases:
    const aliasMap = {
      // Horizontal Rows 0..4
      'row 0': 'row_0',
      'row0': 'row_0',
      'row_0': 'row_0',

      'row 1': 'row_1',
      'row1': 'row_1',
      'row_1': 'row_1',

      'row 2': 'row_2',
      'row2': 'row_2',
      'row_2': 'row_2',

      'row 3': 'row_3',
      'row3': 'row_3',
      'row_3': 'row_3',

      'row 4': 'row_4',
      'row4': 'row_4',
      'row_4': 'row_4',

      'row 5': 'row_4',
      'row5': 'row_4',

      // Vertical Columns 0..4
      'column 0': 'col_0',
      'col 0': 'col_0',
      'col0': 'col_0',
      'col_0': 'col_0',

      'column 1': 'col_1',
      'col 1': 'col_1',
      'col1': 'col_1',
      'col_1': 'col_1',

      'column 2': 'col_2',
      'col 2': 'col_2',
      'col2': 'col_2',
      'col_2': 'col_2',

      'column 3': 'col_3',
      'col 3': 'col_3',
      'col3': 'col_3',
      'col_3': 'col_3',

      'column 4': 'col_4',
      'col 4': 'col_4',
      'col4': 'col_4',
      'col_4': 'col_4',

      'column 5': 'col_4',
      'col 5': 'col_4',

      // Diagonals
      'main diagonal': 'diag_main',
      'main': 'diag_main',
      'diag_main': 'diag_main',
      'diagmain': 'diag_main',
      'diag1': 'diag_main',
      'd1': 'diag_main',

      'anti diagonal': 'diag_anti',
      'anti': 'diag_anti',
      'diag_anti': 'diag_anti',
      'diaganti': 'diag_anti',
      'diag2': 'diag_anti',
      'd2': 'diag_anti',
    };

    final mappedId = aliasMap[lower];
    if (mappedId != null) {
      return allLines.firstWhere((l) => l.id == mappedId);
    }

    // 3. Fallback direct Name match
    for (final line in allLines) {
      if (line.name.toLowerCase() == lower) return line;
    }

    return null;
  }

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
