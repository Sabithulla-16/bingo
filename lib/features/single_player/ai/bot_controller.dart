import 'dart:async';
import '../../../core/game_engine/ai_decision_engine.dart';
import 'bot_configuration.dart';
import 'bot_decision_engine.dart';
import 'bot_game_state.dart';

/// High-level controller managing the bot opponent lifecycle, thinking delay timers,
/// move cancellation, and safe state revalidation before submitting numbers.
class BotController {
  final BotDecisionEngine _decisionEngine;
  Timer? _thinkingTimer;
  bool _isDisposed = false;

  BotController({
    required AiDifficulty difficulty,
    BotConfiguration? configuration,
    int? randomSeed,
  }) : _decisionEngine = BotDecisionEngine(
         difficulty: difficulty,
         configuration: configuration,
         randomSeed: randomSeed,
       );

  BotConfiguration get configuration => _decisionEngine.configuration;

  /// Schedules a bot move with natural human-like thinking delay.
  /// If the match ends or [cancelPendingMove] is called before the timer completes,
  /// the pending decision is safely aborted.
  void scheduleMove({
    required BotGameState state,
    required void Function(int number) onMoveReady,
    Duration? customDelay,
  }) {
    cancelPendingMove();
    if (_isDisposed || !state.isMatchActive) return;

    final delay = customDelay ?? configuration.calculateThinkingDelay();

    if (delay == Duration.zero) {
      _executeMove(state, onMoveReady);
      return;
    }

    _thinkingTimer = Timer(delay, () {
      if (_isDisposed) return;
      _executeMove(state, onMoveReady);
    });
  }

  Future<void> _executeMove(
    BotGameState state,
    void Function(int number) onMoveReady,
  ) async {
    try {
      if (_isDisposed || !state.isMatchActive) return;

      final selectedNumber = await _decisionEngine.selectNextCall(state);

      if (!_isDisposed && state.isMatchActive) {
        onMoveReady(selectedNumber);
      }
    } catch (_) {
      // Safely ignore if match completed or invalid state
    }
  }

  /// Cancels any currently pending thinking timer or scheduled move.
  void cancelPendingMove() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
  }

  /// Disposes resources and cancels active timers.
  void dispose() {
    _isDisposed = true;
    cancelPendingMove();
  }
}
