import '../../../core/game_engine/winning_line.dart';
import 'bot_configuration.dart';
import 'bot_game_state.dart';

/// Detailed breakdown of the heuristic evaluation for a single candidate number.
class CandidateEvaluation {
  final int number;
  final double totalScore;
  final int immediateCompletions;
  final double lineProgress;
  final double multipleLinePotential;
  final double futurePotential;
  final double winningProgress;

  const CandidateEvaluation({
    required this.number,
    required this.totalScore,
    required this.immediateCompletions,
    required this.lineProgress,
    required this.multipleLinePotential,
    required this.futurePotential,
    required this.winningProgress,
  });

  @override
  String toString() {
    return 'CandidateEvaluation(number: $number, score: ${totalScore.toStringAsFixed(1)}, '
        'completions: $immediateCompletions, progress: ${lineProgress.toStringAsFixed(1)}, '
        'multi: ${multipleLinePotential.toStringAsFixed(1)})';
  }
}

/// Evaluates potential moves on the bot's private board using configurable
/// weighted scoring across all 12 winning lines.
class BotEvaluator {
  final BotConfiguration config;

  const BotEvaluator(this.config);

  /// Evaluates all available uncalled numbers and returns their evaluations sorted
  /// in descending order of total score.
  List<CandidateEvaluation> evaluateAllCandidates(BotGameState state) {
    final uncalled = state.uncalledNumbers;
    if (uncalled.isEmpty) return const [];

    final evaluations = uncalled
        .map((n) => evaluateCandidate(state, n))
        .toList();

    evaluations.sort((a, b) {
      final cmp = b.totalScore.compareTo(a.totalScore);
      if (cmp != 0) return cmp;
      return a.number.compareTo(b.number); // Deterministic tie-break order
    });

    return evaluations;
  }

  /// Calculates the heuristic score for a single candidate number [candidate].
  ///
  /// Score(n) = (ImmediateCompletions × W1)
  ///          + (LineProgress × W2)
  ///          + (MultipleLinePotential × W3)
  ///          + (FuturePotential × W4)
  ///          + (WinningProgress × W5)
  CandidateEvaluation evaluateCandidate(BotGameState state, int candidate) {
    final board = state.botBoard;
    final called = state.calledNumbers;
    final claimedLineIds = state.botClaimedLineIds;

    int immediateCompletions = 0;
    double lineProgress = 0.0;
    int promisingLinesCount = 0;
    double futurePotential = 0.0;

    for (final line in WinningLine.allLines) {
      // If this line is already claimed, skip it (overlapping lines invariant:
      // other intersecting lines that are NOT yet claimed remain fully eligible).
      if (claimedLineIds.contains(line.id)) {
        continue;
      }

      // Check if this line contains the candidate number on the bot's board
      final lineNumbers = line.coordinates
          .map((c) => board.getNumberAt(c.row, c.col))
          .toList();

      if (!lineNumbers.contains(candidate)) {
        continue;
      }

      // Count how many cells in this line are already called
      final currentlyCalledCount = lineNumbers
          .where((n) => called.contains(n))
          .length;

      // With this candidate called, the line will have (currentlyCalledCount + 1) cells called
      if (currentlyCalledCount == 4) {
        // Immediate line completion!
        immediateCompletions++;
        promisingLinesCount++;
        lineProgress += 1.0;
        futurePotential += 1.0;
      } else if (currentlyCalledCount == 3) {
        // Advances line to 4/5 marked cells (1 move from completion)
        lineProgress += 0.5;
        promisingLinesCount++;
        futurePotential += 0.75;
      } else if (currentlyCalledCount == 2) {
        // Advances line to 3/5 marked cells
        lineProgress += 0.25;
        promisingLinesCount++;
        futurePotential += 0.5;
      } else if (currentlyCalledCount == 1) {
        lineProgress += 0.1;
        futurePotential += 0.25;
      } else {
        lineProgress += 0.05;
        futurePotential += 0.1;
      }
    }

    // Multiple-line potential: bonus for intersection numbers advancing 2, 3, or 4 lines simultaneously
    final multipleLinePotential = promisingLinesCount > 1
        ? (promisingLinesCount - 1).toDouble()
        : 0.0;

    // Winning progress: bonus if completing this line clinches match victory (5 lines)
    double winningProgress = 0.0;
    if (immediateCompletions > 0) {
      final newTotalClaims = state.botClaimedLinesCount + immediateCompletions;
      if (newTotalClaims >= 5) {
        winningProgress = 3.0; // Clinches instant victory!
      } else {
        winningProgress = (newTotalClaims / 5.0).clamp(0.0, 1.0);
      }
    }

    final totalScore =
        (immediateCompletions * config.immediateCompletionWeight) +
        (lineProgress * config.lineProgressWeight) +
        (multipleLinePotential * config.multipleLinePotentialWeight) +
        (futurePotential * config.futurePotentialWeight) +
        (winningProgress * config.winningProgressWeight);

    return CandidateEvaluation(
      number: candidate,
      totalScore: totalScore,
      immediateCompletions: immediateCompletions,
      lineProgress: lineProgress,
      multipleLinePotential: multipleLinePotential,
      futurePotential: futurePotential,
      winningProgress: winningProgress,
    );
  }
}
