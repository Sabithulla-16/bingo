import 'dart:math';
import 'bot_configuration.dart';
import 'bot_game_state.dart';
import 'bot_strategy.dart';
import 'monte_carlo_simulator.dart';

/// HARD AI: Advanced strategy combining heuristic evaluation with Monte Carlo Lookahead.
/// Simulates future turn trajectories, factors in opponent public letter count,
/// and selects moves maximizing the probability of achieving 5 line claims first.
class HardBotStrategy implements BotStrategy {
  final BotConfiguration config;
  final MonteCarloSimulator _simulator;
  final Random _random;

  HardBotStrategy({BotConfiguration? config, Random? random, int? seed})
    : config = config ?? BotConfiguration.hard(randomSeed: seed),
      _simulator = MonteCarloSimulator(
        config ?? BotConfiguration.hard(randomSeed: seed),
        random,
      ),
      _random = random ?? (seed != null ? Random(seed) : Random());

  @override
  int selectNumberSync(BotGameState state) {
    final candidates = state.uncalledNumbers.toList();
    if (candidates.isEmpty) {
      throw StateError(
        'Cannot select number: all board numbers are already called.',
      );
    }

    if (candidates.length == 1) {
      return candidates.first;
    }

    final evaluations = _simulator.evaluateCandidates(state);
    if (evaluations.isEmpty) {
      return candidates.first;
    }

    final highestScore = evaluations.first.combinedScore;

    // Filter candidates sharing the top score (for fair tie breaking)
    final topCandidates = evaluations
        .where((e) => (e.combinedScore - highestScore).abs() < 0.001)
        .map((e) => e.number)
        .toList();

    if (topCandidates.length == 1) {
      return topCandidates.first;
    }

    final selectedIndex = _random.nextInt(topCandidates.length);
    return topCandidates[selectedIndex];
  }

  @override
  Future<int> selectNumber(BotGameState state) async => selectNumberSync(state);
}
