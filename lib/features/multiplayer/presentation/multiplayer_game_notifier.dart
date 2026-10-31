import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/game_engine/bingo_board.dart';
import '../../../core/game_engine/bingo_engine.dart';
import '../../../core/game_engine/board_coordinate.dart';
import '../../../core/game_engine/winning_line.dart';
import '../../../core/widgets/bingo_cell.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/multiplayer_game.dart';
import '../domain/room.dart';

class MultiplayerGameState {
  final Room? room;
  final MultiplayerGame? game;
  final List<MultiplayerPlayerState> players;
  final String? currentUserId;
  final BingoBoard userBoard;
  final Set<WinningLine> claimedLines;
  final List<WinningLine> unclaimedCompletedLines;
  final bool isLoading;
  final bool isCalling;
  final bool isClaiming;
  final int remainingTurnSeconds;
  final String? toastNotification;
  final String? errorMessage;

  const MultiplayerGameState({
    this.room,
    this.game,
    this.players = const [],
    this.currentUserId,
    required this.userBoard,
    this.claimedLines = const {},
    this.unclaimedCompletedLines = const [],
    this.isLoading = false,
    this.isCalling = false,
    this.isClaiming = false,
    this.remainingTurnSeconds = 20,
    this.toastNotification,
    this.errorMessage,
  });

  bool get isMyTurn {
    if (game == null || currentUserId == null) return false;
    return game!.currentTurnUserId == currentUserId &&
        game!.status == MultiplayerGameStatus.inProgress;
  }

  MultiplayerPlayerState? get currentUserState {
    try {
      return players.firstWhere((p) => p.userId == currentUserId);
    } catch (_) {
      return null;
    }
  }

  int get myLinesClaimedCount => claimedLines.length;

  bool get hasWon => myLinesClaimedCount >= 5;

  List<bool> get letterProgress {
    return [
      myLinesClaimedCount >= 1,
      myLinesClaimedCount >= 2,
      myLinesClaimedCount >= 3,
      myLinesClaimedCount >= 4,
      myLinesClaimedCount >= 5,
    ];
  }

  String get nextAwardLetter {
    const letters = ['B', 'I', 'N', 'G', 'O'];
    if (myLinesClaimedCount < letters.length) {
      return letters[myLinesClaimedCount];
    }
    return 'BINGO!';
  }

  BingoCellState cellStateFor(int number, BoardCoordinate coord) {
    if (game == null) return BingoCellState.available;
    final isCalled = game!.isNumberCalled(number);

    if (!isCalled) return BingoCellState.available;

    // Check if cell is part of an already-claimed line
    final isPartOfClaimed = claimedLines.any(
      (l) => l.containsCoordinate(coord),
    );
    if (isPartOfClaimed) return BingoCellState.claimed;

    // Check if cell is part of a completed but unclaimed line
    final isPartOfUnclaimed = unclaimedCompletedLines.any(
      (l) => l.containsCoordinate(coord),
    );
    if (isPartOfUnclaimed) return BingoCellState.completedUnclaimed;

    return BingoCellState.called;
  }

  MultiplayerGameState copyWith({
    Room? room,
    MultiplayerGame? game,
    List<MultiplayerPlayerState>? players,
    String? currentUserId,
    BingoBoard? userBoard,
    Set<WinningLine>? claimedLines,
    List<WinningLine>? unclaimedCompletedLines,
    bool? isLoading,
    bool? isCalling,
    bool? isClaiming,
    int? remainingTurnSeconds,
    String? toastNotification,
    String? errorMessage,
  }) {
    return MultiplayerGameState(
      room: room ?? this.room,
      game: game ?? this.game,
      players: players ?? this.players,
      currentUserId: currentUserId ?? this.currentUserId,
      userBoard: userBoard ?? this.userBoard,
      claimedLines: claimedLines ?? this.claimedLines,
      unclaimedCompletedLines:
          unclaimedCompletedLines ?? this.unclaimedCompletedLines,
      isLoading: isLoading ?? this.isLoading,
      isCalling: isCalling ?? this.isCalling,
      isClaiming: isClaiming ?? this.isClaiming,
      remainingTurnSeconds: remainingTurnSeconds ?? this.remainingTurnSeconds,
      toastNotification: toastNotification,
      errorMessage: errorMessage,
    );
  }
}

final multiplayerGameProvider = StateNotifierProvider.autoDispose
    .family<MultiplayerGameNotifier, MultiplayerGameState, String>((
      ref,
      roomId,
    ) {
      final repo = ref.watch(multiplayerRepositoryProvider);
      final authRepo = ref.watch(authRepositoryProvider);

      return MultiplayerGameNotifier(
        roomId: roomId,
        repository: repo,
        authRepo: authRepo,
      );
    });

class MultiplayerGameNotifier extends StateNotifier<MultiplayerGameState> {
  final String roomId;
  final MultiplayerRepository repository;
  final AuthRepository authRepo;

  StreamSubscription<MultiplayerGame>? _gameSub;
  StreamSubscription<List<MultiplayerPlayerState>>? _playersSub;
  Timer? _turnCountdownTimer;

  MultiplayerGameNotifier({
    required this.roomId,
    required this.repository,
    required this.authRepo,
    BingoBoard? initialBoard,
  }) : super(
         MultiplayerGameState(
           userBoard: initialBoard ?? BingoBoard.quickShuffle(),
           isLoading: true,
         ),
       ) {
    _init();
  }

  @override
  void dispose() {
    _turnCountdownTimer?.cancel();
    _gameSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final currentUserId = authRepo.currentUserId;
      final room = await repository.getRoom(roomId);
      final game = await repository.getGameForRoom(roomId);

      state = state.copyWith(
        room: room,
        game: game,
        currentUserId: currentUserId,
        isLoading: false,
      );

      _updateTurnCountdown();
      _turnCountdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateTurnCountdown(),
      );

      _gameSub = repository.watchGame(game.id).listen((updatedGame) {
        if (!mounted) return;
        _onGameUpdated(updatedGame);
      });

      _playersSub = repository.watchGamePlayers(game.id).listen((
        updatedPlayers,
      ) {
        if (!mounted) return;
        _onPlayersUpdated(updatedPlayers);
      });
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: ErrorMapper.map(e).message,
        );
      }
    }
  }

  void _onGameUpdated(MultiplayerGame updatedGame) {
    final engine = BingoEngine(
      board: state.userBoard,
      calledNumbers: updatedGame.calledNumbers.toSet(),
      claimedLineIds: state.claimedLines.map((l) => l.id).toSet(),
    );

    final unclaimed = engine.unclaimedCompletedLines;

    state = state.copyWith(
      game: updatedGame,
      unclaimedCompletedLines: unclaimed,
    );
  }

  void _onPlayersUpdated(List<MultiplayerPlayerState> updatedPlayers) {
    final currentUserId = state.currentUserId;
    final userState = updatedPlayers
        .where((p) => p.userId == currentUserId)
        .firstOrNull;

    // Only notify if another player just newly claimed a line
    String? toast;
    for (final p in updatedPlayers) {
      if (p.userId != currentUserId) {
        final prevP = state.players
            .where((x) => x.userId == p.userId)
            .firstOrNull;
        if (p.linesClaimed > (prevP?.linesClaimed ?? 0)) {
          final letterIndex = (p.linesClaimed - 1).clamp(0, 4);
          final letter = ['B', 'I', 'N', 'G', 'O'][letterIndex];
          toast = '${p.displayName} claimed a line! (Letter $letter)';
        }
      }
    }

    BingoBoard updatedBoard = state.userBoard;
    if (userState != null && userState.boardNumbers.length == 25) {
      updatedBoard = BingoBoard(userState.boardNumbers);
    }

    // Recompute private unclaimed completed lines for this player's own board only
    final calledSet = state.game?.calledNumbers.toSet() ?? {};
    final engine = BingoEngine(
      board: updatedBoard,
      calledNumbers: calledSet,
      claimedLineIds: state.claimedLines.map((l) => l.id).toSet(),
    );
    final unclaimed = engine.unclaimedCompletedLines;

    state = state.copyWith(
      userBoard: updatedBoard,
      players: updatedPlayers,
      unclaimedCompletedLines: unclaimed,
      toastNotification: toast,
    );
  }

  void _updateTurnCountdown() {
    final game = state.game;
    if (game == null || game.turnDeadline == null) return;

    final now = DateTime.now();
    final remainingMs = game.turnDeadline!.difference(now).inMilliseconds;
    final remainingSec = (remainingMs / 1000).ceil().clamp(0, 3600);

    if (mounted) {
      state = state.copyWith(remainingTurnSeconds: remainingSec);
    }
  }

  Future<void> callNumber(int number) async {
    if (!state.isMyTurn || state.isCalling || state.game == null) return;
    if (state.game!.isNumberCalled(number)) return;

    state = state.copyWith(isCalling: true);

    try {
      await repository.callNumber(gameId: state.game!.id, number: number);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: ErrorMapper.map(e).message);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isCalling: false);
      }
    }
  }

  Future<void> claimLine(WinningLine line) async {
    if (state.isClaiming || state.game == null) return;
    if (state.claimedLines.contains(line)) return;

    state = state.copyWith(isClaiming: true);

    try {
      final lineNumbers = line.coordinates
          .map((c) => state.userBoard.getNumberAt(c.row, c.col))
          .toList();
      final hasWon = await repository.claimLine(
        gameId: state.game!.id,
        lineType: line.name,
        numbers: lineNumbers,
      );

      final updatedClaimed = Set<WinningLine>.from(state.claimedLines)
        ..add(line);
      final updatedUnclaimed = List<WinningLine>.from(
        state.unclaimedCompletedLines,
      )..remove(line);

      if (mounted) {
        state = state.copyWith(
          claimedLines: updatedClaimed,
          unclaimedCompletedLines: updatedUnclaimed,
          toastNotification: hasWon
              ? 'BINGO! YOU WON THE MATCH!'
              : 'Line Claimed! Letter ${state.nextAwardLetter}',
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: ErrorMapper.map(e).message);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isClaiming: false);
      }
    }
  }
}
