/// Immutable 2D coordinate on a 5x5 Bingo board.
class BoardCoordinate {
  final int row;
  final int col;

  const BoardCoordinate(this.row, this.col)
    : assert(row >= 0 && row < 5, 'Row must be between 0 and 4'),
      assert(col >= 0 && col < 5, 'Col must be between 0 and 4');

  /// Converts a linear index (0..24) into a 2D coordinate (row, col).
  factory BoardCoordinate.fromIndex(int index) {
    assert(index >= 0 && index < 25, 'Index must be between 0 and 24');
    return BoardCoordinate(index ~/ 5, index % 5);
  }

  /// Linear index in row-major order: row * 5 + col (0..24).
  int get index => row * 5 + col;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardCoordinate &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '($row, $col)';
}
