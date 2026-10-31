import 'dart:math';
import 'bot_game_state.dart';
import 'bot_strategy.dart';

/// EASY AI: Simple uniform random selection strategy among uncalled numbers.
/// Never accesses the human player's board, never picks an already called number,
/// and validates available candidate space before dispatching.
class EasyBotStrategy implements BotStrategy {
  final Random _random;

  EasyBotStrategy({Random? random, int? seed})
    : _random = random ?? (seed != null ? Random(seed) : Random());

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

    final selectedIndex = _random.nextInt(candidates.length);
    return candidates[selectedIndex];
  }

  @override
  Future<int> selectNumber(BotGameState state) async => selectNumberSync(state);
}
