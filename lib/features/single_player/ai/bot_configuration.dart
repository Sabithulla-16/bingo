import 'dart:math';

/// Configuration parameters for AI bot evaluation, weights, Monte Carlo lookahead,
/// and natural human-like thinking delays.
class BotConfiguration {
  // Thinking delay ranges (in milliseconds)
  final int minThinkingDelayMs;
  final int maxThinkingDelayMs;

  // Heuristic Weights
  final double immediateCompletionWeight; // W1: completing a line
  final double
  lineProgressWeight; // W2: advancing lines with several marked cells
  final double
  multipleLinePotentialWeight; // W3: intersection cells advancing multiple lines
  final double
  futurePotentialWeight; // W4: remaining open cells in promising lines
  final double winningProgressWeight; // W5: bot's current BINGO letters count

  // Monte Carlo Lookahead Parameters
  final int simulationCount;
  final int maxSimulationDepth;
  final int? randomSeed;

  const BotConfiguration({
    this.minThinkingDelayMs = 1000,
    this.maxThinkingDelayMs = 2000,
    this.immediateCompletionWeight = 100.0,
    this.lineProgressWeight = 20.0,
    this.multipleLinePotentialWeight = 15.0,
    this.futurePotentialWeight = 5.0,
    this.winningProgressWeight = 30.0,
    this.simulationCount = 30,
    this.maxSimulationDepth = 4,
    this.randomSeed,
  });

  /// Factory preset for EASY difficulty (pure random, relaxed pace).
  factory BotConfiguration.easy({int? randomSeed, bool zeroDelay = false}) {
    return BotConfiguration(
      minThinkingDelayMs: zeroDelay ? 0 : 1500,
      maxThinkingDelayMs: zeroDelay ? 0 : 3000,
      randomSeed: randomSeed,
    );
  }

  /// Factory preset for MEDIUM difficulty (mathematical heuristic scoring).
  factory BotConfiguration.medium({int? randomSeed, bool zeroDelay = false}) {
    return BotConfiguration(
      minThinkingDelayMs: zeroDelay ? 0 : 1000,
      maxThinkingDelayMs: zeroDelay ? 0 : 2000,
      immediateCompletionWeight: 100.0,
      lineProgressWeight: 20.0,
      multipleLinePotentialWeight: 15.0,
      futurePotentialWeight: 5.0,
      winningProgressWeight: 30.0,
      randomSeed: randomSeed,
    );
  }

  /// Factory preset for HARD difficulty (heuristic + Monte Carlo lookahead).
  factory BotConfiguration.hard({
    int? randomSeed,
    bool zeroDelay = false,
    int simulationCount = 30,
    int maxDepth = 4,
  }) {
    return BotConfiguration(
      minThinkingDelayMs: zeroDelay ? 0 : 500,
      maxThinkingDelayMs: zeroDelay ? 0 : 1500,
      immediateCompletionWeight: 120.0,
      lineProgressWeight: 25.0,
      multipleLinePotentialWeight: 20.0,
      futurePotentialWeight: 8.0,
      winningProgressWeight: 35.0,
      simulationCount: simulationCount,
      maxSimulationDepth: maxDepth,
      randomSeed: randomSeed,
    );
  }

  /// Calculates a random thinking delay within the configured [minThinkingDelayMs] and [maxThinkingDelayMs].
  Duration calculateThinkingDelay([Random? random]) {
    if (minThinkingDelayMs <= 0 && maxThinkingDelayMs <= 0) {
      return Duration.zero;
    }
    final rng = random ?? (randomSeed != null ? Random(randomSeed) : Random());
    final range = maxThinkingDelayMs - minThinkingDelayMs;
    final delayMs = range > 0
        ? minThinkingDelayMs + rng.nextInt(range + 1)
        : minThinkingDelayMs;
    return Duration(milliseconds: delayMs);
  }

  BotConfiguration copyWith({
    int? minThinkingDelayMs,
    int? maxThinkingDelayMs,
    double? immediateCompletionWeight,
    double? lineProgressWeight,
    double? multipleLinePotentialWeight,
    double? futurePotentialWeight,
    double? winningProgressWeight,
    int? simulationCount,
    int? maxSimulationDepth,
    int? randomSeed,
  }) {
    return BotConfiguration(
      minThinkingDelayMs: minThinkingDelayMs ?? this.minThinkingDelayMs,
      maxThinkingDelayMs: maxThinkingDelayMs ?? this.maxThinkingDelayMs,
      immediateCompletionWeight:
          immediateCompletionWeight ?? this.immediateCompletionWeight,
      lineProgressWeight: lineProgressWeight ?? this.lineProgressWeight,
      multipleLinePotentialWeight:
          multipleLinePotentialWeight ?? this.multipleLinePotentialWeight,
      futurePotentialWeight:
          futurePotentialWeight ?? this.futurePotentialWeight,
      winningProgressWeight:
          winningProgressWeight ?? this.winningProgressWeight,
      simulationCount: simulationCount ?? this.simulationCount,
      maxSimulationDepth: maxSimulationDepth ?? this.maxSimulationDepth,
      randomSeed: randomSeed ?? this.randomSeed,
    );
  }
}
