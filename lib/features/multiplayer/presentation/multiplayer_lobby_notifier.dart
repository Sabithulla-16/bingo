import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/room.dart';

class MultiplayerLobbyState {
  final Room? room;
  final List<RoomPlayer> players;
  final String? currentUserId;
  final bool isLoading;
  final String? errorMessage;

  const MultiplayerLobbyState({
    this.room,
    this.players = const [],
    this.currentUserId,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isHost {
    if (room == null || currentUserId == null) return false;
    return room!.hostId == currentUserId;
  }

  RoomPlayer? get currentUserPlayer {
    try {
      return players.firstWhere((p) => p.userId == currentUserId);
    } catch (_) {
      return null;
    }
  }

  bool get isCurrentUserReady => currentUserPlayer?.isReady ?? false;

  /// Game can start when at least 2 players are seated and ALL players are ready.
  bool get allPlayersReady {
    if (players.length < 2) return false;
    return players.every((p) => p.isReady);
  }

  bool get canStartGame => isHost && allPlayersReady;

  MultiplayerLobbyState copyWith({
    Room? room,
    List<RoomPlayer>? players,
    String? currentUserId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MultiplayerLobbyState(
      room: room ?? this.room,
      players: players ?? this.players,
      currentUserId: currentUserId ?? this.currentUserId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final multiplayerLobbyProvider = StateNotifierProvider.autoDispose
    .family<MultiplayerLobbyNotifier, MultiplayerLobbyState, String>((
  ref,
  roomId,
) {
  final repo = ref.watch(multiplayerRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return MultiplayerLobbyNotifier(
    roomId: roomId,
    repository: repo,
    authRepo: authRepo,
  );
});

class MultiplayerLobbyNotifier extends StateNotifier<MultiplayerLobbyState> {
  final String roomId;
  final MultiplayerRepository repository;
  final AuthRepository authRepo;

  StreamSubscription<Room>? _roomSub;
  StreamSubscription<List<RoomPlayer>>? _playersSub;

  MultiplayerLobbyNotifier({
    required this.roomId,
    required this.repository,
    required this.authRepo,
  }) : super(const MultiplayerLobbyState(isLoading: true)) {
    _init();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final currentUserId = authRepo.currentUserId;

      final room = await repository.getRoom(roomId);
      final players = await repository.getRoomPlayers(roomId);

      state = state.copyWith(
        room: room,
        players: players,
        currentUserId: currentUserId,
        isLoading: false,
      );

      // Listen to room stream
      _roomSub = repository.watchRoom(roomId).listen((updatedRoom) {
        if (mounted) {
          state = state.copyWith(room: updatedRoom);
        }
      });

      // Listen to players stream
      _playersSub = repository.watchRoomPlayers(roomId).listen((updatedPlayers) {
        if (mounted) {
          state = state.copyWith(players: updatedPlayers);
        }
      });
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> toggleReady() async {
    final current = state.currentUserPlayer;
    if (current == null) return;

    try {
      final nextReady = !current.isReady;
      await repository.toggleReady(
        roomId: roomId,
        isReady: nextReady,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> kickPlayer(String userId) async {
    if (!state.isHost) return;

    try {
      await repository.kickPlayer(
        roomId: roomId,
        userId: userId,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> startGame() async {
    if (!state.canStartGame) return;

    try {
      await repository.startGame(roomId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> leaveRoom() async {
    try {
      await repository.leaveRoom(roomId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
