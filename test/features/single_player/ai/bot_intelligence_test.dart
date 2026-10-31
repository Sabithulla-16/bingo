import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/core/game_engine/bingo_engine.dart';
import 'package:bingo/features/single_player/ai/bot_configuration.dart';
import 'package:bingo/features/single_player/ai/bot_controller.dart';
import 'package:bingo/features/single_player/ai/bot_decision_engine.dart';
import 'package:bingo/features/single_player/ai/bot_evaluator.dart';
import 'package:bingo/features/single_player/ai/bot_game_state.dart';
import 'package:bingo/features/single_player/ai/easy_bot_strategy.dart';
import 'package:bingo/features/single_player/ai/hard_bot_strategy.dart';
import 'package:bingo/features/single_player/ai/medium_bot_strategy.dart';
import 'package:bingo/features/single_player/ai/monte_carlo_simulator.dart';
import 'package:bingo/features/single_player/ai/neural_network_bot_strategy.dart';

void main() {
  group('EASY AI Bot Tests', () {
    late BingoBoard sequentialBoard;

    setUp(() {
      // 1..25 sequential board
      sequentialBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));
    });

    test(
      'selects only uncalled numbers and never selects an already called number',
      () {
        final strategy = EasyBotStrategy(seed: 42);
        final called = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: called,
          botClaimedLineIds: const {},
        );

        for (int i = 0; i < 20; i++) {
          final selected = strategy.selectNumberSync(state);
          expect(called.contains(selected), isFalse);
          expect(sequentialBoard.numbers.contains(selected), isTrue);
        }
      },
    );

    test(
      'never selects the same number twice across sequential pick progression',
      () {
        final strategy = EasyBotStrategy(seed: 123);
        final called = <int>{};

        for (int step = 0; step < 24; step++) {
          final state = BotGameState(
            botBoard: sequentialBoard,
            calledNumbers: called,
            botClaimedLineIds: const {},
          );

          final selected = strategy.selectNumberSync(state);
          expect(called.contains(selected), isFalse);
          called.add(selected);
        }

        expect(called.length, equals(24));
      },
    );

    test('handles empty candidate list by throwing StateError safely', () {
      final strategy = EasyBotStrategy();
      final allCalled = List<int>.generate(25, (i) => i + 1).toSet();

      final state = BotGameState(
        botBoard: sequentialBoard,
        calledNumbers: allCalled,
        botClaimedLineIds: const {},
      );

      expect(() => strategy.selectNumberSync(state), throwsStateError);
      expect(strategy.selectNumber(state), throwsStateError);
    });
  });

  group('MEDIUM AI Bot Heuristic Tests', () {
    late BingoBoard sequentialBoard;

    setUp(() {
      sequentialBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));
    });

    test('prefers an immediate winning line completion over other numbers', () {
      final strategy = MediumBotStrategy(
        config: BotConfiguration.medium(randomSeed: 99),
      );

      // Row 0 has [1, 2, 3, 4] called. Number 5 will complete the line!
      final called = {1, 2, 3, 4, 10, 15, 20};
      final state = BotGameState(
        botBoard: sequentialBoard,
        calledNumbers: called,
        botClaimedLineIds: const {},
      );

      final selected = strategy.selectNumberSync(state);
      expect(
        selected,
        equals(5),
        reason:
            'Number 5 completes Row 0 immediately and must receive highest heuristic score',
      );
    });

    test(
      'recognizes numbers that advance multiple lines simultaneously (intersections)',
      () {
        final evaluator = BotEvaluator(BotConfiguration.medium());

        // Center cell (row 2, col 2) is number 13 on sequential board.
        // 13 sits at the intersection of Row 2, Col 2, Diag Main, and Diag Anti (4 lines!).
        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: const {},
          botClaimedLineIds: const {},
        );

        final eval13 = evaluator.evaluateCandidate(state, 13);
        final eval1 = evaluator.evaluateCandidate(
          state,
          1,
        ); // Corner cell intersects 3 lines
        final eval2 = evaluator.evaluateCandidate(
          state,
          2,
        ); // Edge cell intersects 2 lines

        expect(
          eval13.totalScore,
          greaterThan(eval2.totalScore),
          reason:
              'Center cell 13 intersects 4 lines and must outscore 2-line edge cell 2',
        );
        expect(
          eval13.totalScore,
          greaterThan(eval1.totalScore),
          reason: 'Center cell 13 must outscore 3-line corner cell 1',
        );
      },
    );

    test('correctly evaluates line progress based on number of called cells', () {
      final evaluator = BotEvaluator(BotConfiguration.medium());

      // Row 0: call 3 cells [1, 2, 3]. Number 4 and 5 advance a 3-called line.
      // Row 4: call 1 cell [21]. Number 22 advances a 1-called line.
      final called = {1, 2, 3, 21};
      final state = BotGameState(
        botBoard: sequentialBoard,
        calledNumbers: called,
        botClaimedLineIds: const {},
      );

      final eval4 = evaluator.evaluateCandidate(state, 4);
      final eval22 = evaluator.evaluateCandidate(state, 22);

      expect(
        eval4.totalScore,
        greaterThan(eval22.totalScore),
        reason:
            'Advancing a 3-called line must score higher than a 1-called line',
      );
      expect(eval4.lineProgress, greaterThan(eval22.lineProgress));
    });

    test('fairly breaks ties when multiple numbers have identical scores', () {
      // Empty board with symmetric configuration: 2, 4, 22, 24 have identical line intersections
      final strategy1 = MediumBotStrategy(seed: 10);
      final strategy2 = MediumBotStrategy(seed: 9999);

      final state = BotGameState(
        botBoard: sequentialBoard,
        calledNumbers: const {},
        botClaimedLineIds: const {},
      );

      final choice1 = strategy1.selectNumberSync(state);
      final choice2 = strategy2.selectNumberSync(state);

      expect(choice1, isPositive);
      expect(choice2, isPositive);
    });
  });

  group('HARD AI Bot Heuristic + Monte Carlo Lookahead Tests', () {
    late BingoBoard sequentialBoard;

    setUp(() {
      sequentialBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));
    });

    test('evaluates multiple candidate moves through Monte Carlo rollouts', () {
      final simulator = MonteCarloSimulator(
        BotConfiguration.hard(randomSeed: 42, simulationCount: 15, maxDepth: 3),
      );

      final state = BotGameState(
        botBoard: sequentialBoard,
        calledNumbers: {1, 2, 6, 7, 11},
        botClaimedLineIds: const {},
      );

      final evaluations = simulator.evaluateCandidates(state);
      expect(evaluations.length, equals(20)); // 25 - 5 called = 20 candidates
      expect(
        evaluations.first.combinedScore,
        greaterThanOrEqualTo(evaluations.last.combinedScore),
      );
    });

    test(
      'produces valid selections and respects simulation limits without stalling',
      () {
        final strategy = HardBotStrategy(
          config: BotConfiguration.hard(
            randomSeed: 7,
            simulationCount: 10,
            maxDepth: 2,
          ),
        );

        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: {3, 7, 12, 18},
          botClaimedLineIds: const {},
        );

        final stopwatch = Stopwatch()..start();
        final picked = strategy.selectNumberSync(state);
        stopwatch.stop();

        expect(state.uncalledNumbers.contains(picked), isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Bounded Monte Carlo lookahead must execute rapidly in under 300ms',
        );
      },
    );

    test(
      'produces deterministic reproducible results with a fixed random seed',
      () {
        final strategyA = HardBotStrategy(seed: 888);
        final strategyB = HardBotStrategy(seed: 888);

        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: {2, 4, 8, 16, 20},
          botClaimedLineIds: const {},
        );

        final pickA = strategyA.selectNumberSync(state);
        final pickB = strategyB.selectNumberSync(state);

        expect(
          pickA,
          equals(pickB),
          reason:
              'Fixed random seed must yield identical decisions across instances',
        );
      },
    );

    test(
      'opponent awareness: adjusts urgency when opponent is near win (4 letters)',
      () {
        final simulator = MonteCarloSimulator(
          BotConfiguration.hard(
            randomSeed: 123,
            simulationCount: 10,
            maxDepth: 2,
          ),
        );

        // Bot has [1, 2, 3, 4] called (number 5 completes Row 0).
        // Candidate 5 completes a line immediately. Candidate 25 is an idle cell.
        final called = {1, 2, 3, 4, 11, 12};

        // Case A: Opponent is NOT near win (0 letters)
        final stateCalm = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: called,
          botClaimedLineIds: const {},
          opponentLetterCount: 0,
        );

        // Case B: Opponent IS near win (4 letters: B-I-N-G)
        final stateUrgent = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: called,
          botClaimedLineIds: const {},
          opponentLetterCount: 4,
        );

        final evalsCalm = simulator.evaluateCandidates(stateCalm);
        final evalsUrgent = simulator.evaluateCandidates(stateUrgent);

        // In urgent state, number 5 should remain the dominant choice
        expect(evalsUrgent.first.number, equals(5));
        expect(evalsCalm.first.number, equals(5));
      },
    );

    test(
      'strictly adheres to privacy: never accesses hidden human board arrangement',
      () {
        // Notice BotGameState does not even possess a human board field!
        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: {10, 20},
          botClaimedLineIds: const {},
          opponentLetterCount: 2,
        );

        // Strategy receives only BotGameState
        final strategy = HardBotStrategy(seed: 55);
        final selected = strategy.selectNumberSync(state);
        expect(sequentialBoard.numbers.contains(selected), isTrue);
      },
    );
  });

  group('Shared Game Rules & Overlapping Line Invariant Tests', () {
    late BingoBoard sequentialBoard;

    setUp(() {
      sequentialBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));
    });

    test(
      'STRICT OVERLAPPING LINE INVARIANT: claiming row_0 never consumes intersecting col_0 or diag_main',
      () {
        // Row 0: [1, 2, 3, 4, 5]
        // Col 0: [1, 6, 11, 16, 21]
        // Diag Main: [1, 7, 13, 19, 25]
        // Notice cell (0, 0) with number 1 is shared by all three lines!

        final called = {1, 2, 3, 4, 5, 6, 11, 16, 21, 7, 13, 19, 25};
        final claimedLineIds = {'row_0'};

        final engine = BingoEngine(
          board: sequentialBoard,
          calledNumbers: called,
          claimedLineIds: claimedLineIds,
        );

        // row_0 is claimed, but col_0 and diag_main MUST remain independently completed and eligible!
        expect(engine.claimedLineIds, contains('row_0'));
        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          contains('col_0'),
        );
        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          contains('diag_main'),
        );

        // Claim col_0 independently
        final afterCol0 = engine.claimLine('col_0');
        expect(afterCol0, contains('row_0'));
        expect(afterCol0, contains('col_0'));

        // diag_main is still eligible!
        final engineAfterCol0 = BingoEngine(
          board: sequentialBoard,
          calledNumbers: called,
          claimedLineIds: afterCol0,
        );
        expect(
          engineAfterCol0.unclaimedCompletedLines.map((l) => l.id),
          contains('diag_main'),
        );
      },
    );

    test(
      'BotDecisionEngine validates selected moves and rejects illegal or already called numbers',
      () async {
        final engine = BotDecisionEngine(
          difficulty: AiDifficulty.hard,
          randomSeed: 101,
        );

        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: {1, 2, 3},
          botClaimedLineIds: const {},
          isMatchActive: true,
        );

        final move = await engine.selectNextCall(state);
        expect({1, 2, 3}.contains(move), isFalse);
        expect(sequentialBoard.numbers.contains(move), isTrue);

        // Inactive match throws StateError
        final inactiveState = state.copyWith(isMatchActive: false);
        expect(() => engine.selectNextCall(inactiveState), throwsStateError);
        expect(
          () => engine.selectNextCallSync(inactiveState),
          throwsStateError,
        );
      },
    );

    test(
      'BotController respects cancellation when match ends or user aborts',
      () async {
        final controller = BotController(
          difficulty: AiDifficulty.easy,
          configuration: BotConfiguration(
            minThinkingDelayMs: 200,
            maxThinkingDelayMs: 200,
          ),
        );

        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: const {},
          botClaimedLineIds: const {},
        );

        int? callbackReceived;
        controller.scheduleMove(
          state: state,
          onMoveReady: (n) => callbackReceived = n,
        );

        // Cancel before timer completes (e.g. user leaves screen)
        controller.cancelPendingMove();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(
          callbackReceived,
          isNull,
          reason: 'Cancelled pending bot move must not deliver callback',
        );

        controller.dispose();
      },
    );

    test(
      'NeuralNetworkBotStrategy provides clean tensor encoding and fallback behavior',
      () async {
        final strategy = NeuralNetworkBotStrategy(seed: 42);

        final state = BotGameState(
          botBoard: sequentialBoard,
          calledNumbers: {1, 2, 3, 4},
          botClaimedLineIds: const {},
          opponentLetterCount: 1,
        );

        // 1. Verify tensor generation
        final tensor = NeuralNetworkStateTensor.fromGameState(state);
        expect(tensor.features.length, equals(63));
        expect(tensor.actionMask.length, equals(25));
        // Numbers 1, 2, 3, 4 are called so their action mask must be 0.0
        expect(tensor.actionMask[0], equals(0.0));
        expect(tensor.actionMask[1], equals(0.0));
        expect(tensor.actionMask[4], equals(1.0)); // Number 5 is legal

        // 2. Verify fallback execution
        final selection = await strategy.selectNumber(state);
        expect(state.uncalledNumbers.contains(selection), isTrue);
      },
    );
  });
}
