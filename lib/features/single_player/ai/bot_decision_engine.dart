import '../../../core/game_engine/ai_decision_engine.dart';
import 'bot_configuration.dart';
import 'bot_game_state.dart';
import 'bot_strategy.dart';
import 'easy_bot_strategy.dart';
import 'hard_bot_strategy.dart';
import 'medium_bot_strategy.dart';

/// Central decision engine managing strategy resolution and move selection.
/// Coordinates between Easy, Medium, and Hard strategies, and validates state.
class BotDecisionEngine {
  final BotConfiguration configuration;
  final BotStrategy _strategy;

  BotDecisionEngine({
    required AiDifficulty difficulty,
    BotConfiguration? configuration,
    int? randomSeed,
  }) : configuration =
           configuration ?? _defaultConfigFor(difficulty, randomSeed),
       _strategy = _createStrategy(
         difficulty,
         configuration ?? _defaultConfigFor(difficulty, randomSeed),
         randomSeed,
       );

  /// Synchronously selects the next number according to the active strategy.
  int selectNextCallSync(BotGameState state) {
    if (!state.isMatchActive) {
      throw StateError('Cannot make bot move: match is no longer active.');
    }

    final candidate = _strategy.selectNumberSync(state);

    // Validate that the returned number is legal (on bot's board and uncalled)
    if (state.calledNumbers.contains(candidate)) {
      throw StateError(
        'Bot strategy selected invalid move: number $candidate has already been called.',
      );
    }
    if (!state.botBoard.numbers.contains(candidate)) {
      throw StateError(
        'Bot strategy selected invalid move: number $candidate does not exist on bot board.',
      );
    }

    return candidate;
  }

  /// Selects the next number according to the active strategy.
  Future<int> selectNextCall(BotGameState state) async {
    if (!state.isMatchActive) {
      throw StateError('Cannot make bot move: match is no longer active.');
    }

    final candidate = await _strategy.selectNumber(state);

    // Validate that the returned number is legal (on bot's board and uncalled)
    if (state.calledNumbers.contains(candidate)) {
      throw StateError(
        'Bot strategy selected invalid move: number $candidate has already been called.',
      );
    }
    if (!state.botBoard.numbers.contains(candidate)) {
      throw StateError(
        'Bot strategy selected invalid move: number $candidate does not exist on bot board.',
      );
    }

    return candidate;
  }

  static BotConfiguration _defaultConfigFor(
    AiDifficulty difficulty,
    int? randomSeed,
  ) {
    switch (difficulty) {
      case AiDifficulty.easy:
        return BotConfiguration.easy(randomSeed: randomSeed);
      case AiDifficulty.medium:
        return BotConfiguration.medium(randomSeed: randomSeed);
      case AiDifficulty.hard:
        return BotConfiguration.hard(randomSeed: randomSeed);
    }
  }

  static BotStrategy _createStrategy(
    AiDifficulty difficulty,
    BotConfiguration config,
    int? randomSeed,
  ) {
    switch (difficulty) {
      case AiDifficulty.easy:
        return EasyBotStrategy(seed: randomSeed);
      case AiDifficulty.medium:
        return MediumBotStrategy(config: config, seed: randomSeed);
      case AiDifficulty.hard:
        return HardBotStrategy(config: config, seed: randomSeed);
    }
  }
}
