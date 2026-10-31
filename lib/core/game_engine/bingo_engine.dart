import 'dart:math';
import '../widgets/bingo_cell.dart';
import 'bingo_board.dart';
import 'board_coordinate.dart';
import 'winning_line.dart';

/// Pure Dart game engine evaluating line completions, letter claims,
/// and cell visual states while strictly preserving the Overlapping Line Invariant.
class BingoEngine {
  final BingoBoard board;
  final Set<int> calledNumbers;
  final Set<String> claimedLineIds;

  static const List<String> lettersSequence = ['B', 'I', 'N', 'G', 'O'];

  const BingoEngine({
    required this.board,
    required this.calledNumbers,
    required this.claimedLineIds,
  });

  /// Evaluates whether the number at the given coordinate has been called.
  bool isCellCalled(BoardCoordinate coord) {
    final num = board.getNumberAt(coord.row, coord.col);
    return calledNumbers.contains(num);
  }

  /// Evaluates whether the number at the given linear index (0..24) has been called.
  bool isIndexCalled(int index) {
    final num = board.getNumberAtIndex(index);
    return calledNumbers.contains(num);
  }

  /// Evaluates whether all 5 numbers in a winning line have been called.
  ///
  /// CRITICAL OVERLAPPING LINE RULE:
  /// Line completion is evaluated SOLELY on whether all 5 cell numbers are in
  /// [calledNumbers]. Claiming another line that shares a cell NEVER invalidates
  /// or disables this line.
  bool isLineComplete(WinningLine line) {
    for (final coord in line.coordinates) {
      if (!isCellCalled(coord)) {
        return false;
      }
    }
    return true;
  }

  /// Returns all of the 12 winning lines that are currently complete.
  List<WinningLine> get completedLines {
    return WinningLine.allLines.where(isLineComplete).toList();
  }

  /// Returns the completed winning lines that the player has not yet claimed.
  List<WinningLine> get unclaimedCompletedLines {
    return completedLines
        .where((line) => !claimedLineIds.contains(line.id))
        .toList();
  }

  /// True if there is at least one completed line awaiting manual claim.
  bool get hasUnclaimedLines => unclaimedCompletedLines.isNotEmpty;

  /// Total number of distinct winning lines successfully claimed by the player.
  int get claimedLinesCount => claimedLineIds.length;

  /// Returns the earned B-I-N-G-O letters according to the number of claimed lines.
  /// 1 line -> ['B']
  /// 2 lines -> ['B', 'I']
  /// 3 lines -> ['B', 'I', 'N']
  /// 4 lines -> ['B', 'I', 'N', 'G']
  /// 5+ lines -> ['B', 'I', 'N', 'G', 'O']
  List<String> get claimedLetters {
    final count = min(claimedLinesCount, 5);
    return lettersSequence.sublist(0, count);
  }

  /// True if the player has claimed at least 5 lines (achieved B-I-N-G-O).
  bool get hasBingo => claimedLinesCount >= 5;

  /// True if all 25 numbers have been called without achieving BINGO (match draw).
  bool get isDraw => calledNumbers.length == 25 && !hasBingo;

  /// Determines the presentation state for a cell at the given coordinate.
  BingoCellState cellVisualState(BoardCoordinate coord) {
    // 1. Is this cell part of any line that has been explicitly claimed?
    for (final lineId in claimedLineIds) {
      final line = WinningLine.allLines.firstWhere((l) => l.id == lineId);
      if (line.containsCoordinate(coord)) {
        return BingoCellState.claimed;
      }
    }

    // 2. Is this cell part of a completed line awaiting claim?
    for (final line in unclaimedCompletedLines) {
      if (line.containsCoordinate(coord)) {
        return BingoCellState.completedUnclaimed;
      }
    }

    // 3. Has this cell's number been called?
    if (isCellCalled(coord)) {
      return BingoCellState.called;
    }

    // 4. Otherwise available
    return BingoCellState.available;
  }

  /// Determines the presentation state for a cell at linear index (0..24).
  BingoCellState cellVisualStateByIndex(int index) {
    return cellVisualState(BoardCoordinate.fromIndex(index));
  }

  /// Attempts to claim a completed line by its unique ID.
  /// Returns an updated Set of claimed line IDs.
  ///
  /// Throws [StateError] if the line is not complete or already claimed.
  Set<String> claimLine(String lineId) {
    if (claimedLineIds.contains(lineId)) {
      throw StateError('Line $lineId is already claimed.');
    }

    final line = WinningLine.allLines.firstWhere(
      (l) => l.id == lineId,
      orElse: () => throw ArgumentError('Unknown line ID: $lineId'),
    );

    if (!isLineComplete(line)) {
      throw StateError(
        'Line $lineId is not yet complete and cannot be claimed.',
      );
    }

    return {...claimedLineIds, lineId};
  }

  /// Claims all currently completed lines and returns the updated set of claimed line IDs.
  Set<String> claimAllCompletedLines() {
    final updated = Set<String>.from(claimedLineIds);
    for (final line in unclaimedCompletedLines) {
      updated.add(line.id);
    }
    return updated;
  }
}
