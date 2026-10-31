import '../../../core/game_engine/bingo_board.dart';
import '../../../core/game_engine/bingo_engine.dart';

/// Immutable representation of the game environment accessible to the AI.
/// Strictly exposes only the bot's private board, public call history,
/// and publicly observable opponent score/letter progress.
/// Opponent's private board layout and hidden positions are NEVER exposed.
class BotGameState {
  /// The bot's own private 5×5 board.
  final BingoBoard botBoard;

  /// Public history of numbers already called this match.
  final Set<int> calledNumbers;

  /// Line IDs already claimed by the bot.
  final Set<String> botClaimedLineIds;

  /// Publicly visible count of BINGO letters achieved by opponent (0..5).
  final int opponentLetterCount;

  /// Whether the match is actively in progress.
  final bool isMatchActive;

  const BotGameState({
    required this.botBoard,
    required this.calledNumbers,
    required this.botClaimedLineIds,
    this.opponentLetterCount = 0,
    this.isMatchActive = true,
  });

  /// Set of candidate numbers on the bot's board that have not yet been called.
  Set<int> get uncalledNumbers =>
      botBoard.numbers.where((n) => !calledNumbers.contains(n)).toSet();

  /// Total lines successfully claimed by the bot so far.
  int get botClaimedLinesCount => botClaimedLineIds.length;

  /// Number of additional lines the bot needs to claim to achieve B-I-N-G-O.
  int get remainingLinesToWin => (5 - botClaimedLinesCount).clamp(0, 5);

  /// Whether the opponent is threatening a win (e.g. 4 letters claimed: B-I-N-G).
  bool get isOpponentNearWin => opponentLetterCount >= 4;

  /// Instantiates a BingoEngine bound strictly to the bot's private board and state.
  BingoEngine get engine => BingoEngine(
    board: botBoard,
    calledNumbers: calledNumbers,
    claimedLineIds: botClaimedLineIds,
  );

  BotGameState copyWith({
    BingoBoard? botBoard,
    Set<int>? calledNumbers,
    Set<String>? botClaimedLineIds,
    int? opponentLetterCount,
    bool? isMatchActive,
  }) {
    return BotGameState(
      botBoard: botBoard ?? this.botBoard,
      calledNumbers: calledNumbers ?? this.calledNumbers,
      botClaimedLineIds: botClaimedLineIds ?? this.botClaimedLineIds,
      opponentLetterCount: opponentLetterCount ?? this.opponentLetterCount,
      isMatchActive: isMatchActive ?? this.isMatchActive,
    );
  }
}
