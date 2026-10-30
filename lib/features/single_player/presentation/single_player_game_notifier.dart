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

  @override
  void dispose() {
    _computerTurnTimer?.cancel();
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

    final playerEngine = BingoEngine(
      board: current.playerBoard,
      calledNumbers: updatedCalls.toSet(),
      claimedLineIds: current.playerClaimedLineIds,
    );

    // Evaluate computer board: computer auto-claims its completed lines immediately
    final botEngine = BingoEngine(
      board: current.computerBoard,
      calledNumbers: updatedCalls.toSet(),
      claimedLineIds: current.computerClaimedLineIds,
    );
    final updatedBotClaims = botEngine.claimAllCompletedLines();

    // Check winner conditions
    GameWinner winner = current.winner;
    DateTime? completedAt = current.completedAt;

    if (updatedBotClaims.length >= 5 && playerEngine.completedLines.length >= 5) {
      winner = GameWinner.draw;
      completedAt = DateTime.now();
    } else if (updatedBotClaims.length >= 5) {
      winner = GameWinner.computer;
      completedAt = DateTime.now();
    } else if (updatedCalls.length == 25) {
      // 25 numbers called - draw if neither player achieved 5 lines before
      winner = GameWinner.draw;
      completedAt = DateTime.now();
    }

    if (winner != GameWinner.none) {
      state = current.copyWith(
        calledNumbers: updatedCalls,
        computerClaimedLineIds: updatedBotClaims,
        winner: winner,
        completedAt: completedAt,
        isComputerThinking: false,
      );
      return;
    }

    if (byPlayer) {
      // Swap turn to computer with simulated thinking delay
      state = current.copyWith(
        calledNumbers: updatedCalls,
        computerClaimedLineIds: updatedBotClaims,
        isPlayerTurn: false,
        isComputerThinking: true,
      );

      _scheduleComputerTurn();
    } else {
      // Return turn to player
      state = current.copyWith(
        calledNumbers: updatedCalls,
        computerClaimedLineIds: updatedBotClaims,
        isPlayerTurn: true,
        isComputerThinking: false,
      );
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
