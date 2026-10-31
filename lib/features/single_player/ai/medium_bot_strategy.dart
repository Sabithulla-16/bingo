import 'dart:math';
import 'bot_configuration.dart';
import 'bot_evaluator.dart';
import 'bot_game_state.dart';
import 'bot_strategy.dart';

/// MEDIUM AI: Mathematical strategy AI using weighted heuristic scoring across all 12 lines.
/// Prefers immediate line completions, advances multi-marked lines, rewards intersecting cells,
/// and breaks equal score ties fairly.
class MediumBotStrategy implements BotStrategy {
  final BotConfiguration config;
  final BotEvaluator _evaluator;
  final Random _random;

  MediumBotStrategy({BotConfiguration? config, Random? random, int? seed})
    : config = config ?? BotConfiguration.medium(randomSeed: seed),
      _evaluator = BotEvaluator(
        config ?? BotConfiguration.medium(randomSeed: seed),
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

    final evaluations = _evaluator.evaluateAllCandidates(state);
    if (evaluations.isEmpty) {
      return candidates.first;
    }

    final highestScore = evaluations.first.totalScore;

    // Collect all candidates sharing the highest score (for fair tie breaking)
    final topCandidates = evaluations
        .where((e) => (e.totalScore - highestScore).abs() < 0.001)
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
