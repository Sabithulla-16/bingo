import 'dart:math';
import 'board_coordinate.dart';
import 'board_validator.dart';

/// Immutable representation of a 5x5 Bingo board holding numbers 1 through 25.
class BingoBoard {
  final List<int> numbers;

  BingoBoard(List<int> numbers)
    : assert(numbers.length == 25, 'BingoBoard must have exactly 25 numbers'),
      numbers = List<int>.unmodifiable(numbers);

  /// Creates a board with all 25 cells initialized to 0 (unassigned).
  factory BingoBoard.empty() {
    return BingoBoard(List<int>.filled(25, 0));
  }

  /// Creates a board from a 5x5 2D matrix.
  factory BingoBoard.fromMatrix(List<List<int>> matrix) {
    assert(matrix.length == 5, 'Matrix must have 5 rows');
    final flattened = <int>[];
    for (final row in matrix) {
      assert(row.length == 5, 'Each row must have 5 columns');
      flattened.addAll(row);
    }
    return BingoBoard(flattened);
  }

  /// Generates a cryptographically random permutation of numbers [1..25].
  factory BingoBoard.quickShuffle([Random? random]) {
    final rng = random ?? Random.secure();
    final list = List<int>.generate(25, (i) => i + 1);

    // Fisher-Yates shuffle
    for (int i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }

    return BingoBoard(list);
  }

  /// Returns the number located at (row, col).
  int getNumberAt(int row, int col) {
    assert(row >= 0 && row < 5, 'Row out of range (0..4)');
    assert(col >= 0 && col < 5, 'Col out of range (0..4)');
    return numbers[row * 5 + col];
  }

  /// Returns the number located at the given BoardCoordinate.
  int getNumberAtCoord(BoardCoordinate coord) {
    return getNumberAt(coord.row, coord.col);
  }

  /// Returns the number at linear cell index (0..24).
  int getNumberAtIndex(int index) {
    assert(index >= 0 && index < 25, 'Index out of range (0..24)');
    return numbers[index];
  }

  /// Finds the 2D coordinate where the given number is placed, or null if not placed.
  BoardCoordinate? findCoordinateOf(int number) {
    final idx = numbers.indexOf(number);
    if (idx == -1) return null;
    return BoardCoordinate.fromIndex(idx);
  }

  /// Returns a new BingoBoard with the number at (row, col) updated.
  BingoBoard setNumberAt(int row, int col, int number) {
    return setNumberAtIndex(row * 5 + col, number);
  }

  /// Returns a new BingoBoard with the number at linear index updated.
  BingoBoard setNumberAtIndex(int index, int number) {
    assert(index >= 0 && index < 25, 'Index out of range (0..24)');
    final updated = List<int>.from(numbers);
    updated[index] = number;
    return BingoBoard(updated);
  }

  /// Returns a new BingoBoard with numbers swapped at indexA and indexB.
  BingoBoard swapNumbers(int indexA, int indexB) {
    assert(indexA >= 0 && indexA < 25, 'indexA out of range');
    assert(indexB >= 0 && indexB < 25, 'indexB out of range');
    final updated = List<int>.from(numbers);
    final temp = updated[indexA];
    updated[indexA] = updated[indexB];
    updated[indexB] = temp;
    return BingoBoard(updated);
  }

  /// Returns a new BingoBoard with numbers swapped at coordA and coordB.
  BingoBoard swapCoordinates(BoardCoordinate coordA, BoardCoordinate coordB) {
    return swapNumbers(coordA.index, coordB.index);
  }

  /// Returns a mutable copy of the underlying numbers list.
  List<int> toList() => List<int>.from(numbers);

  /// True if all 25 cells are 0 (unassigned).
  bool get isUnassigned => numbers.every((n) => n == 0);

  /// Validates the board against all official rules.
  BoardValidationResult get validationResult =>
      BoardValidator.validate(numbers);

  /// True if the board contains all 25 numbers without duplicates or missing values.
  bool get isFilledAndValid => validationResult.isValid;

  /// Returns the set of numbers from 1 to 25 that are not yet assigned on this board.
  Set<int> get unassignedNumbers {
    final placed = numbers.where((n) => n >= 1 && n <= 25).toSet();
    final allExpected = List<int>.generate(25, (i) => i + 1).toSet();
    return allExpected.difference(placed);
  }

  /// 5x5 2D matrix representation.
  List<List<int>> get matrix {
    return List.generate(5, (r) => numbers.sublist(r * 5, (r + 1) * 5));
  }

  Map<String, dynamic> toJson() => {'numbers': numbers};

  factory BingoBoard.fromJson(Map<String, dynamic> json) {
    final raw = (json['numbers'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    return BingoBoard(raw);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BingoBoard) return false;
    if (numbers.length != other.numbers.length) return false;
    for (int i = 0; i < 25; i++) {
      if (numbers[i] != other.numbers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(numbers);

  @override
  String toString() {
    final buffer = StringBuffer('BingoBoard:\n');
    for (int r = 0; r < 5; r++) {
      final row = numbers.sublist(r * 5, (r + 1) * 5);
      buffer.writeln(row.map((n) => n.toString().padLeft(2, '0')).join(' '));
    }
    return buffer.toString();
  }
}
