import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/game_engine/ai_decision_engine.dart';
import '../../../core/game_engine/bingo_board.dart';
import '../../../core/game_engine/bingo_engine.dart';

enum GameWinner { none, player, computer, draw }

/// Immutable state snapshot of an active single-player match.
class SinglePlayerMatchState {
  final String gameId;
  final AiDifficulty difficulty;
  final BingoBoard playerBoard;
  final BingoBoard computerBoard;
  final List<int> calledNumbers;
  final Set<String> playerClaimedLineIds;
  final Set<String> computerClaimedLineIds;
  final bool isPlayerTurn;
  final bool isComputerThinking;
  final GameWinner winner;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? botActionToast;

  SinglePlayerMatchState({
    required this.gameId,
    required this.difficulty,
    required this.playerBoard,
    required this.computerBoard,
    required this.calledNumbers,
    required this.playerClaimedLineIds,
    required this.computerClaimedLineIds,
    this.isPlayerTurn = true,
    this.isComputerThinking = false,
    this.winner = GameWinner.none,
    required this.startedAt,
    this.completedAt,
    this.botActionToast,
  });

  /// Evaluates player's private board against called numbers and claimed lines.
  BingoEngine get playerEngine => BingoEngine(
        board: playerBoard,
        calledNumbers: calledNumbers.toSet(),
        claimedLineIds: playerClaimedLineIds,
      );

  /// Evaluates computer's private board against called numbers and claimed lines.
  BingoEngine get computerEngine => BingoEngine(
        board: computerBoard,
        calledNumbers: calledNumbers.toSet(),
        claimedLineIds: computerClaimedLineIds,
      );

  int? get lastCalledNumber =>
      calledNumbers.isNotEmpty ? calledNumbers.last : null;

  bool isNumberCalled(int number) => calledNumbers.contains(number);

  Duration get matchDuration {
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  SinglePlayerMatchState copyWith({
    String? gameId,
    AiDifficulty? difficulty,
    BingoBoard? playerBoard,
    BingoBoard? computerBoard,
    List<int>? calledNumbers,
    Set<String>? playerClaimedLineIds,
    Set<String>? computerClaimedLineIds,
    bool? isPlayerTurn,
    bool? isComputerThinking,
    GameWinner? winner,
    DateTime? startedAt,
    DateTime? completedAt,
    String? botActionToast,
  }) {
    return SinglePlayerMatchState(
      gameId: gameId ?? this.gameId,
      difficulty: difficulty ?? this.difficulty,
      playerBoard: playerBoard ?? this.playerBoard,
      computerBoard: computerBoard ?? this.computerBoard,
      calledNumbers: calledNumbers ?? this.calledNumbers,
      playerClaimedLineIds: playerClaimedLineIds ?? this.playerClaimedLineIds,
      computerClaimedLineIds:
          computerClaimedLineIds ?? this.computerClaimedLineIds,
      isPlayerTurn: isPlayerTurn ?? this.isPlayerTurn,
      isComputerThinking: isComputerThinking ?? this.isComputerThinking,
      winner: winner ?? this.winner,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      botActionToast: botActionToast,
    );
  }
}

/// Provider for selected AI difficulty during Single Player setup.
final selectedDifficultyProvider =
    StateProvider<AiDifficulty>((ref) => AiDifficulty.medium);

/// Provider holding the user's prepared board before match kickoff.
final preparedBoardProvider =
    StateProvider<BingoBoard>((ref) => BingoBoard.quickShuffle());

/// Riverpod StateNotifierProvider managing active single player gameplay.
final singlePlayerGameProvider =
    StateNotifierProvider<SinglePlayerGameNotifier, SinglePlayerMatchState?>((
      ref,
    ) {
      return SinglePlayerGameNotifier();
    });

class SinglePlayerGameNotifier extends StateNotifier<SinglePlayerMatchState?> {
  final Duration computerResponseDelay;

  SinglePlayerGameNotifier({
    this.computerResponseDelay = const Duration(milliseconds: 900),
  }) : super(null);

  Timer? _computerTurnTimer;
  Timer? _botClaimTimer;

  @override
  void dispose() {
    _computerTurnTimer?.cancel();
    _botClaimTimer?.cancel();
    super.dispose();
  }

  /// Initializes a new single-player match.
  void initMatch({
    required String gameId,
    required AiDifficulty difficulty,
    required BingoBoard playerBoard,
    BingoBoard? computerBoard,
  }) {
    _computerTurnTimer?.cancel();
    _botClaimTimer?.cancel();

    final botBoard = computerBoard ?? BingoBoard.quickShuffle();

    state = SinglePlayerMatchState(
      gameId: gameId,
      difficulty: difficulty,
      playerBoard: playerBoard,
      computerBoard: botBoard,
      calledNumbers: [],
      playerClaimedLineIds: {},
      computerClaimedLineIds: {},
      isPlayerTurn: true,
      isComputerThinking: false,
      winner: GameWinner.none,
      startedAt: DateTime.now(),
    );
  }

  /// Human player selects and calls an uncalled number.
  void callNumber(int number) {
    final current = state;
    if (current == null) return;
    if (current.winner != GameWinner.none) return;
    if (!current.isPlayerTurn || current.isComputerThinking) return;
    if (current.isNumberCalled(number)) return;

    _applyCall(number, byPlayer: true);
  }

  /// Manually claims a completed line for the player.
  void claimLine(String lineId) {
    final current = state;
    if (current == null) return;

    final updatedClaimed = current.playerEngine.claimLine(lineId);
    final hasBingo = updatedClaimed.length >= 5;

    state = current.copyWith(
      playerClaimedLineIds: updatedClaimed,
      winner: hasBingo ? GameWinner.player : current.winner,
      completedAt: hasBingo ? DateTime.now() : current.completedAt,
    );
  }

  /// Claims all currently eligible lines for the player.
  void claimAllLines() {
    final current = state;
    if (current == null) return;

    final updatedClaimed = current.playerEngine.claimAllCompletedLines();
    final hasBingo = updatedClaimed.length >= 5;

    state = current.copyWith(
      playerClaimedLineIds: updatedClaimed,
      winner: hasBingo ? GameWinner.player : current.winner,
      completedAt: hasBingo ? DateTime.now() : current.completedAt,
    );
  }

  /// Core number call execution, state mutation, and turn swapping.
  void _applyCall(int number, {required bool byPlayer}) {
    final current = state;
    if (current == null) return;

    final updatedCalls = [...current.calledNumbers, number];

    // Check if 25 numbers exhausted
    if (updatedCalls.length == 25) {
      final playerEngine = BingoEngine(
        board: current.playerBoard,
        calledNumbers: updatedCalls.toSet(),
        claimedLineIds: current.playerClaimedLineIds,
      );
      final botEngine = BingoEngine(
        board: current.computerBoard,
        calledNumbers: updatedCalls.toSet(),
        claimedLineIds: current.computerClaimedLineIds,
      );
      final playerLines = playerEngine.completedLines.length;
      final botLines = botEngine.completedLines.length;

      GameWinner winner = GameWinner.draw;
      if (playerLines >= 5 && botLines < 5) {
        winner = GameWinner.player;
      } else if (botLines >= 5 && playerLines < 5) {
        winner = GameWinner.computer;
      } else {
        winner = GameWinner.draw;
      }

      state = current.copyWith(
        calledNumbers: updatedCalls,
        winner: winner,
        completedAt: DateTime.now(),
        isComputerThinking: false,
      );
      return;
    }

    state = current.copyWith(
      calledNumbers: updatedCalls,
      isPlayerTurn: byPlayer ? false : true,
      isComputerThinking: byPlayer ? true : false,
      botActionToast: null,
    );

    // Let the bot evaluate lines and claim them one by one
    _evaluateAndClaimBotLinesSequentially(byPlayer: byPlayer);
  }

  /// Sequentially claims any completed lines for the bot one by one, updating state after each claim.
  void _evaluateAndClaimBotLinesSequentially({required bool byPlayer}) {
    final current = state;
    if (current == null || current.winner != GameWinner.none) return;

    final botEngine = BingoEngine(
      board: current.computerBoard,
      calledNumbers: current.calledNumbers.toSet(),
      claimedLineIds: current.computerClaimedLineIds,
    );
    final unclaimed = botEngine.unclaimedCompletedLines;

    if (unclaimed.isEmpty) {
      if (byPlayer) {
        _scheduleComputerTurn();
      } else {
        state = current.copyWith(
          isPlayerTurn: true,
          isComputerThinking: false,
        );
      }
      return;
    }

    // Claim strictly ONE line in this step
    final lineToClaim = unclaimed.first;
    final updatedBotClaims = {...current.computerClaimedLineIds, lineToClaim.id};
    final letterIndex = updatedBotClaims.length - 1;
    final letter = (letterIndex >= 0 && letterIndex < BingoEngine.lettersSequence.length)
        ? BingoEngine.lettersSequence[letterIndex]
        : 'O';

    final hasBingo = updatedBotClaims.length >= 5;
    final winner = hasBingo ? GameWinner.computer : GameWinner.none;
    final completedAt = hasBingo ? DateTime.now() : null;

    state = current.copyWith(
      computerClaimedLineIds: updatedBotClaims,
      winner: winner,
      completedAt: completedAt,
      botActionToast: '⚡ Bot struck and claimed Letter $letter!',
    );

    if (hasBingo) {
      return;
    }

    final remainingUnclaimed = botEngine.completedLines
        .where((l) => !updatedBotClaims.contains(l.id))
        .toList();

    if (remainingUnclaimed.isNotEmpty) {
      final delay = computerResponseDelay == Duration.zero
          ? Duration.zero
          : const Duration(milliseconds: 500);

      if (delay == Duration.zero) {
        _evaluateAndClaimBotLinesSequentially(byPlayer: byPlayer);
      } else {
        _botClaimTimer?.cancel();
        _botClaimTimer = Timer(delay, () {
          _evaluateAndClaimBotLinesSequentially(byPlayer: byPlayer);
        });
      }
    } else {
      if (byPlayer) {
        _scheduleComputerTurn();
      } else {
        state = state?.copyWith(
          isPlayerTurn: true,
          isComputerThinking: false,
        );
      }
    }
  }

  void _scheduleComputerTurn() {
    _computerTurnTimer?.cancel();
    if (computerResponseDelay == Duration.zero) {
      final current = state;
      if (current == null || current.winner != GameWinner.none) return;

      final botCall = AiDecisionEngine.selectNextCall(
        board: current.computerBoard,
        calledNumbers: current.calledNumbers.toSet(),
        difficulty: current.difficulty,
      );

      _applyCall(botCall, byPlayer: false);
      return;
    }

    _computerTurnTimer = Timer(computerResponseDelay, () {
      final current = state;
      if (current == null || current.winner != GameWinner.none) return;

      final botCall = AiDecisionEngine.selectNextCall(
        board: current.computerBoard,
        calledNumbers: current.calledNumbers.toSet(),
        difficulty: current.difficulty,
      );

      _applyCall(botCall, byPlayer: false);
    });
  }

  /// Restarts the match with fresh board states.
  void rematch() {
    final current = state;
    if (current == null) return;

    initMatch(
      gameId: 'sp_${DateTime.now().millisecondsSinceEpoch}',
      difficulty: current.difficulty,
      playerBoard: current.playerBoard,
    );
  }
}
