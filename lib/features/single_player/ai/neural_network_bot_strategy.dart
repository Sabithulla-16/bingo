import 'bot_configuration.dart';
import 'bot_game_state.dart';
import 'bot_strategy.dart';
import 'hard_bot_strategy.dart';

/// Neural Network State Vector Representation for future Reinforcement Learning.
/// Encodes the 2D Bingo board state and public history into a flat normalized feature vector.
class NeuralNetworkStateTensor {
  /// 63-dimensional feature vector:
  /// - [0..24]:   Bot 5×5 board cell numbers (normalized n / 25.0)
  /// - [25..49]:  Called number binary flags (1.0 = called, 0.0 = uncalled)
  /// - [50..61]:  12 Winning lines completion flags on bot board (1.0 = complete)
  /// - [62]:      Opponent public letter progress (0.0 to 1.0)
  final List<double> features;

  /// 25-dimensional binary action mask (1.0 = legal uncalled number, 0.0 = illegal)
  final List<double> actionMask;

  const NeuralNetworkStateTensor({
    required this.features,
    required this.actionMask,
  });

  /// Encodes [state] into a normalized tensor ready for neural network inference.
  factory NeuralNetworkStateTensor.fromGameState(BotGameState state) {
    final features = List<double>.filled(63, 0.0);
    final actionMask = List<double>.filled(25, 0.0);

    // 1. Board cell values normalized 1..25 -> 0.04..1.0
    for (int i = 0; i < 25; i++) {
      features[i] = state.botBoard.numbers[i] / 25.0;
    }

    // 2. Called status for numbers 1..25
    for (int n = 1; n <= 25; n++) {
      final isCalled = state.calledNumbers.contains(n);
      features[24 + n] = isCalled ? 1.0 : 0.0;
      // Action mask: only uncalled numbers on the bot board are legal actions
      if (!isCalled && state.botBoard.numbers.contains(n)) {
        actionMask[n - 1] = 1.0;
      }
    }

    // 3. 12 winning lines completion flags
    final completedLineIds = state.engine.completedLines
        .map((l) => l.id)
        .toSet();
    const lineIds = [
      'row_0',
      'row_1',
      'row_2',
      'row_3',
      'row_4',
      'col_0',
      'col_1',
      'col_2',
      'col_3',
      'col_4',
      'diag_main',
      'diag_anti',
    ];
    for (int i = 0; i < lineIds.length; i++) {
      features[50 + i] = completedLineIds.contains(lineIds[i]) ? 1.0 : 0.0;
    }

    // 4. Opponent letter progress
    features[62] = (state.opponentLetterCount / 5.0).clamp(0.0, 1.0);

    return NeuralNetworkStateTensor(features: features, actionMask: actionMask);
  }
}

/// EXPERT AI (Extension Point): Prepared architecture for a trained Neural Network
/// utilizing Reinforcement Learning (RL) and self-play policy inference.
///
/// REWARD SPECIFICATION FOR TRAINING:
/// - Terminal Win: +1.0
/// - Terminal Loss: -1.0
/// - Terminal Draw: 0.0
/// - Line Completion: +0.2 per line
/// - Step Penalty (efficiency incentive): -0.01 per turn
///
/// In this milestone, this strategy serves as a production-grade extension point.
/// When trained model weights are provided, inference is injected via [modelEvaluator].
/// If model weights are not yet loaded, it seamlessly delegates to [HardBotStrategy].
class NeuralNetworkBotStrategy implements BotStrategy {
  final BotConfiguration config;
  final HardBotStrategy _fallbackStrategy;

  /// Optional external inference delegate (e.g. TFLite / ONNX runtime).
  final Future<List<double>> Function(NeuralNetworkStateTensor tensor)?
  modelEvaluator;

  NeuralNetworkBotStrategy({
    BotConfiguration? config,
    this.modelEvaluator,
    int? seed,
  }) : config = config ?? BotConfiguration.hard(randomSeed: seed),
       _fallbackStrategy = HardBotStrategy(
         config: config ?? BotConfiguration.hard(randomSeed: seed),
         seed: seed,
       );

  @override
  int selectNumberSync(BotGameState state) {
    return _fallbackStrategy.selectNumberSync(state);
  }

  @override
  Future<int> selectNumber(BotGameState state) async {
    // If a trained neural network evaluator is supplied, perform inference:
    if (modelEvaluator != null) {
      final tensor = NeuralNetworkStateTensor.fromGameState(state);
      final policyProbabilities = await modelEvaluator!(tensor);

      int bestNumber = -1;
      double maxProbability = -double.infinity;

      for (int i = 0; i < 25; i++) {
        final number = i + 1;
        // Check legal action mask
        if (tensor.actionMask[i] > 0.5) {
          final prob = policyProbabilities[i];
          if (prob > maxProbability) {
            maxProbability = prob;
            bestNumber = number;
          }
        }
      }

      if (bestNumber != -1) {
        return bestNumber;
      }
    }

    // Fallback to HardBotStrategy when model weights are not loaded
    return _fallbackStrategy.selectNumber(state);
  }
}
