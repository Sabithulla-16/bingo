import 'bot_game_state.dart';

/// Common strategy interface governing all AI difficulty levels.
/// Future AI implementations (including Neural Network / Reinforcement Learning)
/// must adhere to this interface without altering core game engine mechanics.
abstract interface class BotStrategy {
  /// Selects the next uncalled number to call asynchronously based on the bot's strategy.
  /// Throws [StateError] if all numbers are already called or if candidate list is empty.
  Future<int> selectNumber(BotGameState state);

  /// Synchronously evaluates and selects the next number for CPU-bound strategies.
  int selectNumberSync(BotGameState state);
}
