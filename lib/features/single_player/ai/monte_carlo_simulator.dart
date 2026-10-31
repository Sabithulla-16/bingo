import 'dart:math';
import '../../../core/game_engine/bingo_engine.dart';
import 'bot_configuration.dart';
import 'bot_evaluator.dart';
import 'bot_game_state.dart';

/// Summary evaluation from a Monte Carlo lookahead rollout.
class MonteCarloEvaluation {
  final int number;
  final double baseHeuristicScore;
  final double expectedRolloutValue;
  final double combinedScore;
  final int completedLinesInRollouts;

  const MonteCarloEvaluation({
    required this.number,
    required this.baseHeuristicScore,
    required this.expectedRolloutValue,
    required this.combinedScore,
    required this.completedLinesInRollouts,
  });

  @override
  String toString() {
    return 'MCEval(num: $number, combined: ${combinedScore.toStringAsFixed(1)}, '
        'base: ${baseHeuristicScore.toStringAsFixed(1)}, rollout: ${expectedRolloutValue.toStringAsFixed(1)})';
  }
}

/// Monte Carlo lookahead simulator that models stochastic future turn sequences
/// and evaluates expected strategic values for candidate moves.
class MonteCarloSimulator {
  final BotConfiguration config;
  final BotEvaluator _evaluator;
  final Random _random;

  MonteCarloSimulator(this.config, [Random? random])
    : _evaluator = BotEvaluator(config),
      _random =
          random ??
          (config.randomSeed != null ? Random(config.randomSeed) : Random());

  /// Runs Monte Carlo lookahead rollouts for all candidate moves in [state]
  /// and returns the evaluations sorted by highest [combinedScore].
  List<MonteCarloEvaluation> evaluateCandidates(BotGameState state) {
    final candidates = state.uncalledNumbers.toList();
    if (candidates.isEmpty) return const [];

    final baseEvaluations = _evaluator.evaluateAllCandidates(state);
    final baseScores = {
      for (final e in baseEvaluations) e.number: e.totalScore,
    };

    // If only 1 candidate remains, return immediately
    if (candidates.length == 1) {
      final num = candidates.first;
      return [
        MonteCarloEvaluation(
          number: num,
          baseHeuristicScore: baseScores[num] ?? 0.0,
          expectedRolloutValue: 0.0,
          combinedScore: baseScores[num] ?? 0.0,
          completedLinesInRollouts: 0,
        ),
      ];
    }

    // Optimization: if any candidate immediately achieves match victory (5 lines),
    // prioritize it directly without wasting rollout cycles.
    final winningCandidates = baseEvaluations
        .where(
          (e) =>
              e.immediateCompletions > 0 &&
              (state.botClaimedLinesCount + e.immediateCompletions) >= 5,
        )
        .toList();

    if (winningCandidates.isNotEmpty) {
      final winner = winningCandidates.first;
      return [
        MonteCarloEvaluation(
          number: winner.number,
          baseHeuristicScore: winner.totalScore,
          expectedRolloutValue: 1000.0,
          combinedScore: winner.totalScore + 1000.0,
          completedLinesInRollouts: 5,
        ),
      ];
    }

    // Run bounded rollouts for each candidate
    final results = <MonteCarloEvaluation>[];

    for (final candidate in candidates) {
      final baseScore = baseScores[candidate] ?? 0.0;
      double totalRolloutScore = 0.0;
      int totalLinesCompleted = 0;

      for (int sim = 0; sim < config.simulationCount; sim++) {
        final rolloutResult = _simulateRollout(state, candidate);
        totalRolloutScore += rolloutResult.score;
        totalLinesCompleted += rolloutResult.linesCompleted;
      }

      final avgRolloutValue = totalRolloutScore / config.simulationCount;

      // Opponent awareness: if opponent is near win (4 letters),
      // penalize moves with zero immediate completions to avoid giving opponent time.
      double urgencyMultiplier = 1.0;
      if (state.isOpponentNearWin) {
        final eval = baseEvaluations.firstWhere((e) => e.number == candidate);
        if (eval.immediateCompletions == 0) {
          urgencyMultiplier =
              0.7; // 30% penalty for idle moves during opponent match point
        }
      }

      final combinedScore =
          (baseScore * 0.4 + avgRolloutValue * 0.6) * urgencyMultiplier;

      results.add(
        MonteCarloEvaluation(
          number: candidate,
          baseHeuristicScore: baseScore,
          expectedRolloutValue: avgRolloutValue,
          combinedScore: combinedScore,
          completedLinesInRollouts: totalLinesCompleted,
        ),
      );
    }

    // Sort descending by combined score, with deterministic tie-breaking
    results.sort((a, b) {
      final cmp = b.combinedScore.compareTo(a.combinedScore);
      if (cmp != 0) return cmp;
      return a.number.compareTo(b.number);
    });

    return results;
  }

  /// Simulates a single lookahead rollout starting with [candidateMove].
  ({double score, int linesCompleted}) _simulateRollout(
    BotGameState state,
    int candidateMove,
  ) {
    final simCalled = Set<int>.from(state.calledNumbers)..add(candidateMove);
    final available = state.uncalledNumbers
        .where((n) => n != candidateMove)
        .toList();

    // Rollout future turns up to maxSimulationDepth
    final rolloutDepth = min(config.maxSimulationDepth, available.length);
    for (int d = 0; d < rolloutDepth; d++) {
      if (available.isEmpty) break;
      final idx = _random.nextInt(available.length);
      final picked = available.removeAt(idx);
      simCalled.add(picked);
    }

    // Evaluate simulated board state on bot's private board
    final simEngine = BingoEngine(
      board: state.botBoard,
      calledNumbers: simCalled,
      claimedLineIds: state.botClaimedLineIds,
    );

    final completedCount = simEngine.completedLines.length;
    final totalEligibleLines = completedCount;

    double rolloutScore = 0.0;
    if (totalEligibleLines >= 5) {
      rolloutScore += 500.0; // Achieves BINGO in rollout!
    } else {
      rolloutScore += totalEligibleLines * 50.0;
    }

    return (score: rolloutScore, linesCompleted: totalEligibleLines);
  }
}
