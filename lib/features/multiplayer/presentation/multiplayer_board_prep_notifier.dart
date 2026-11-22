import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_mapper.dart';
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
  final String? currentUserId;

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
    this.currentUserId,
  });

  bool get isHost {
    if (room != null &&
        currentUserId != null &&
        room!.hostId == currentUserId) {
      return true;
    }
    return currentUserState?.isHost ?? false;
  }

  MultiplayerPlayerState? get currentUserState {
    if (currentUserId != null) {
      final user = players.where((p) => p.userId == currentUserId).firstOrNull;
      if (user != null) return user;
    }
    return players.firstOrNull;
  }

  int get readyCount => players.where((p) => p.isBoardConfirmed).length;

  bool get allPlayersReady =>
      players.isNotEmpty && players.every((p) => p.isBoardConfirmed);

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
    String? currentUserId,
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
      currentUserId: currentUserId ?? this.currentUserId,
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

  StreamSubscription<Room>? _roomSub;
  StreamSubscription<MultiplayerGame>? _gameSub;
  StreamSubscription<List<MultiplayerPlayerState>>? _playersSub;
  Timer? _countdownTimer;
  Timer? _fallbackPollTimer;
  int _totalDurationSeconds = 45;

  MultiplayerBoardPrepNotifier({
    required this.roomId,
    required this.repository,
    required this.authRepo,
  }) : super(
         MultiplayerBoardPrepState(
           board: BingoBoard.quickShuffle(),
           isLoading: true,
           currentUserId: authRepo.currentUserId,
         ),
       ) {
    _init();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fallbackPollTimer?.cancel();
    _roomSub?.cancel();
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
        currentUserId: authRepo.currentUserId,
      );

      _updateCountdown();
      _countdownTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _updateCountdown(),
      );

      // 1. Listen to authoritative Room updates
      _roomSub = repository.watchRoom(roomId).listen((updatedRoom) {
        if (!mounted) return;
        state = state.copyWith(room: updatedRoom);
      });

      // 2. Listen to Game entity updates
      _gameSub = repository.watchGame(game.id).listen((updatedGame) {
        if (!mounted) return;
        state = state.copyWith(game: updatedGame);
      });

      // 3. Listen to player readiness updates
      _playersSub = repository.watchGamePlayers(game.id).listen((
        updatedPlayers,
      ) {
        if (!mounted) return;
        final currentUserId = authRepo.currentUserId;
        final userState = updatedPlayers
            .where((p) => p.userId == currentUserId)
            .firstOrNull;
        state = state.copyWith(
          players: updatedPlayers,
          isConfirmed: userState?.isBoardConfirmed ?? state.isConfirmed,
        );
      });

      // 4. Resilience Fallback Polling every 3 seconds (Part 4 requirement)
      _fallbackPollTimer = Timer.periodic(const Duration(seconds: 3), (
        _,
      ) async {
        if (!mounted) return;
        try {
          final refreshedRoom = await repository.getRoom(roomId);
          final refreshedGame = await repository.getGameForRoom(roomId);
          if (mounted) {
            state = state.copyWith(
              room: refreshedRoom ?? state.room,
              game: refreshedGame,
            );
          }
        } catch (_) {}
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

  void _updateCountdown() {
    final game = state.game;
    if (game == null) return;

    final now = DateTime.now();
    final remainingMs = game.prepDeadline.difference(now).inMilliseconds;
    final remainingSec = (remainingMs / 1000).ceil().clamp(0, 3600);
    final fraction = (remainingSec / _totalDurationSeconds).clamp(0.0, 1.0);

    final isExpired = remainingSec <= 0;
    final showExpiredModal =
        isExpired && !state.allPlayersReady && state.isHost;

    if (mounted) {
      state = state.copyWith(
        remainingSeconds: remainingSec,
        progressFraction: fraction,
        isExpiredModalOpen: showExpiredModal,
      );

      // Auto-trigger fallback timeout if non-host or expired for more than 3 seconds
      if (isExpired && !state.isHost && remainingMs < -3000) {
        handleTimeout(autoFill: true);
      }
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
      state = state.copyWith(board: newBoard, selectedCoordinate: () => null);
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

    // Optimistic lock
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

  Future<void> handleTimeout({bool autoFill = true}) async {
    if (state.game == null) return;
    try {
      await repository.handlePrepTimeout(
        gameId: state.game!.id,
        autoFill: autoFill,
      );
      state = state.copyWith(isExpiredModalOpen: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Timeout error: $e');
      }
    }
  }

  Future<void> removeUnreadyPlayers() async {
    if (state.game == null) return;
    try {
      await repository.removeUnreadyPlayers(
        roomId: roomId,
        gameId: state.game!.id,
      );
      state = state.copyWith(isExpiredModalOpen: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isExpiredModalOpen: false,
          errorMessage: 'Failed to remove players: $e',
        );
      }
    }
  }

  void dismissExpiredModal() {
    state = state.copyWith(isExpiredModalOpen: false);
  }
}
