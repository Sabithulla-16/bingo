import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/game_engine/bingo_board.dart';
import '../../../core/game_engine/board_coordinate.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/multiplayer_game.dart';
import '../domain/room.dart';

class MultiplayerBoardPrepState {
  final Room? room;
  final MultiplayerGame? game;
  final List<MultiplayerPlayerState> players;
  final BingoBoard board;
  final BoardCoordinate? selectedCoordinate;
  final bool isConfirmed;
  final bool isLoading;
  final int remainingSeconds;
  final double progressFraction;
  final bool isExpiredModalOpen;
  final String? errorMessage;

  const MultiplayerBoardPrepState({
    this.room,
    this.game,
    this.players = const [],
    required this.board,
    this.selectedCoordinate,
    this.isConfirmed = false,
    this.isLoading = false,
    this.remainingSeconds = 45,
    this.progressFraction = 1.0,
    this.isExpiredModalOpen = false,
    this.errorMessage,
  });

  bool get isHost {
    if (room == null || players.isEmpty) return false;
    final userState = currentUserState;
    return userState?.isHost ?? false;
  }

  MultiplayerPlayerState? get currentUserState {
    try {
      return players.firstWhere((p) => p.isBoardConfirmed == isConfirmed);
    } catch (_) {
      return players.firstOrNull;
    }
  }

  int get readyCount => players.where((p) => p.isBoardConfirmed).length;

  bool get allPlayersReady => players.isNotEmpty && players.every((p) => p.isBoardConfirmed);

  MultiplayerBoardPrepState copyWith({
    Room? room,
    MultiplayerGame? game,
    List<MultiplayerPlayerState>? players,
    BingoBoard? board,
    BoardCoordinate? Function()? selectedCoordinate,
    bool? isConfirmed,
    bool? isLoading,
    int? remainingSeconds,
    double? progressFraction,
    bool? isExpiredModalOpen,
    String? errorMessage,
  }) {
    return MultiplayerBoardPrepState(
      room: room ?? this.room,
      game: game ?? this.game,
      players: players ?? this.players,
      board: board ?? this.board,
      selectedCoordinate: selectedCoordinate != null
          ? selectedCoordinate()
          : this.selectedCoordinate,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isLoading: isLoading ?? this.isLoading,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      progressFraction: progressFraction ?? this.progressFraction,
      isExpiredModalOpen: isExpiredModalOpen ?? this.isExpiredModalOpen,
      errorMessage: errorMessage,
    );
  }
}

final multiplayerBoardPrepProvider = StateNotifierProvider.autoDispose
    .family<MultiplayerBoardPrepNotifier, MultiplayerBoardPrepState, String>((
  ref,
  roomId,
) {
  final repo = ref.watch(multiplayerRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return MultiplayerBoardPrepNotifier(
    roomId: roomId,
    repository: repo,
    authRepo: authRepo,
  );
});

class MultiplayerBoardPrepNotifier
    extends StateNotifier<MultiplayerBoardPrepState> {
  final String roomId;
  final MultiplayerRepository repository;
  final AuthRepository authRepo;

  StreamSubscription<MultiplayerGame>? _gameSub;
  StreamSubscription<List<MultiplayerPlayerState>>? _playersSub;
  Timer? _countdownTimer;
  int _totalDurationSeconds = 45;

  MultiplayerBoardPrepNotifier({
    required this.roomId,
    required this.repository,
    required this.authRepo,
  }) : super(MultiplayerBoardPrepState(
          board: BingoBoard.quickShuffle(),
          isLoading: true,
        )) {
    _init();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _gameSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final room = await repository.getRoom(roomId);
      final game = await repository.getGameForRoom(roomId);

      _totalDurationSeconds = room?.prepTimeSeconds ?? 45;

      state = state.copyWith(
        room: room,
        game: game,
        isLoading: false,
      );

      _updateCountdown();
      _countdownTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _updateCountdown(),
      );

      // Listen to game updates
      _gameSub = repository.watchGame(game.id).listen((updatedGame) {
        if (!mounted) return;
        state = state.copyWith(game: updatedGame);
      });

      // Listen to player readiness updates
      _playersSub = repository.watchGamePlayers(game.id).listen((updatedPlayers) {
        if (!mounted) return;
        final currentUserId = authRepo.currentUserId;
        final userState = updatedPlayers.where((p) => p.userId == currentUserId).firstOrNull;
        state = state.copyWith(
          players: updatedPlayers,
          isConfirmed: userState?.isBoardConfirmed ?? state.isConfirmed,
        );
      });
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  void _updateCountdown() {
    final game = state.game;
    if (game == null) return;

    final now = DateTime.now();
    final remainingMs = game.prepDeadline.difference(now).inMilliseconds;
    final remainingSec = (remainingMs / 1000).ceil().clamp(0, 3600);
    final fraction = (remainingSec / _totalDurationSeconds).clamp(0.0, 1.0);

    final isExpired = remainingSec <= 0;
    final showExpiredModal = isExpired && !state.isConfirmed && state.isHost;

    if (mounted) {
      state = state.copyWith(
        remainingSeconds: remainingSec,
        progressFraction: fraction,
        isExpiredModalOpen: showExpiredModal,
      );
    }
  }

  void onCellTapped(BoardCoordinate coord) {
    if (state.isConfirmed) return;

    final currentSelected = state.selectedCoordinate;
    if (currentSelected == null) {
      state = state.copyWith(selectedCoordinate: () => coord);
    } else if (currentSelected == coord) {
      state = state.copyWith(selectedCoordinate: () => null);
    } else {
      final newBoard = state.board.swapCoordinates(currentSelected, coord);
      state = state.copyWith(
        board: newBoard,
        selectedCoordinate: () => null,
      );
    }
  }

  void cancelSelection() {
    state = state.copyWith(selectedCoordinate: () => null);
  }

  void quickShuffle() {
    if (state.isConfirmed) return;
    state = state.copyWith(
      board: BingoBoard.quickShuffle(),
      selectedCoordinate: () => null,
    );
  }

  Future<void> confirmBoard() async {
    if (state.isConfirmed || state.game == null) return;

    state = state.copyWith(isConfirmed: true, selectedCoordinate: () => null);

    try {
      await repository.submitBoard(
        gameId: state.game!.id,
        numbers: state.board.toList(),
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isConfirmed: false,
          errorMessage: 'Failed to confirm board: $e',
        );
      }
    }
  }

  Future<void> extendTimer({int seconds = 30}) async {
    if (state.game == null) return;
    try {
      await repository.extendPrepTime(
        gameId: state.game!.id,
        extensionSeconds: seconds,
      );
      state = state.copyWith(isExpiredModalOpen: false);
    } catch (_) {}
  }

  void dismissExpiredModal() {
    state = state.copyWith(isExpiredModalOpen: false);
  }
}
