import 'dart:math';
import 'bingo_board.dart';
import 'winning_line.dart';

enum AiDifficulty { easy, medium, hard }

/// Heuristic decision engine driving the computer AI opponent across Easy, Medium, and Hard.
class AiDecisionEngine {
  const AiDecisionEngine._();

  /// Returns the set of numbers on the board that have not yet been called.
  static Set<int> getUncalledNumbers(BingoBoard board, Set<int> calledNumbers) {
    return board.numbers.where((n) => !calledNumbers.contains(n)).toSet();
  }

  /// Selects the next number to call based on the configured AI difficulty.
  static int selectNextCall({
    required BingoBoard board,
    required Set<int> calledNumbers,
    required AiDifficulty difficulty,
    Random? random,
  }) {
    final uncalled = getUncalledNumbers(board, calledNumbers);
    if (uncalled.isEmpty) {
      throw StateError('All numbers on the board have already been called.');
    }

    if (uncalled.length == 1) {
      return uncalled.first;
    }

    switch (difficulty) {
      case AiDifficulty.easy:
        return _selectEasy(uncalled, random);
      case AiDifficulty.medium:
        return _selectMedium(board, calledNumbers, uncalled, random);
      case AiDifficulty.hard:
        return _selectHard(board, calledNumbers, uncalled);
    }
  }

  /// EASY AI: Uniformly random selection among uncalled numbers.
  static int _selectEasy(Set<int> uncalled, Random? random) {
    final rng = random ?? Random();
    final list = uncalled.toList();
    return list[rng.nextInt(list.length)];
  }

  /// MEDIUM AI: Biases towards numbers that advance lines with 3 or 4 marked cells.
  static int _selectMedium(
    BingoBoard board,
    Set<int> calledNumbers,
    Set<int> uncalled,
    Random? random,
  ) {
    final rng = random ?? Random();

    // Check lines that have 4 marked cells (1 call away from complete)
    final nearCompleteCandidates = <int>{};
    final moderateCandidates = <int>{};

    for (final line in WinningLine.allLines) {
      final lineNumbers = line.coordinates
          .map((c) => board.getNumberAt(c.row, c.col))
          .toList();
      final lineCalled = lineNumbers.where(calledNumbers.contains).length;

      if (lineCalled == 4) {
        final remaining = lineNumbers.firstWhere(
          (n) => !calledNumbers.contains(n),
        );
        nearCompleteCandidates.add(remaining);
      } else if (lineCalled == 3) {
        final remaining = lineNumbers.where((n) => !calledNumbers.contains(n));
        moderateCandidates.addAll(remaining);
      }
    }

    // 80% chance to pick from 4-marked lines if available
    if (nearCompleteCandidates.isNotEmpty && rng.nextDouble() < 0.85) {
      final list = nearCompleteCandidates.toList();
      return list[rng.nextInt(list.length)];
    }

    // 60% chance to pick from 3-marked lines if available
    if (moderateCandidates.isNotEmpty && rng.nextDouble() < 0.65) {
      final list = moderateCandidates.toList();
      return list[rng.nextInt(list.length)];
    }

    return _selectEasy(uncalled, rng);
  }

  /// HARD AI: Heuristic weighting scoring each uncalled number by intersection density
  /// and line advancement potential across all 12 lines.
  static int _selectHard(
    BingoBoard board,
    Set<int> calledNumbers,
    Set<int> uncalled,
  ) {
    int bestNumber = uncalled.first;
    double highestScore = -1.0;

    for (final candidate in uncalled) {
      double score = 0.0;

      for (final line in WinningLine.allLines) {
        final lineNumbers = line.coordinates
            .map((c) => board.getNumberAt(c.row, c.col))
            .toList();

        // Only evaluate lines that contain this candidate number
        if (lineNumbers.contains(candidate)) {
          final currentlyCalled = lineNumbers
              .where(calledNumbers.contains)
              .length;

          // Exponential weighting based on how close this line is to completion
          switch (currentlyCalled) {
            case 4:
              score += 100.0; // Immediate line completion
              break;
            case 3:
              score += 25.0; // Sets up 4-line
              break;
            case 2:
              score += 8.0;
              break;
            case 1:
              score += 3.0;
              break;
            case 0:
              score += 1.0;
              break;
          }

          // Bonus if it's a diagonal (diagonal intersection cell (2,2) intersects 4 lines!)
          if (line.type == WinningLineType.diagonal) {
            score += 2.0;
          }
        }
      }

      if (score > highestScore) {
        highestScore = score;
        bestNumber = candidate;
      }
    }

    return bestNumber;
  }
}
