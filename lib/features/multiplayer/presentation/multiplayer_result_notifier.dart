import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_mapper.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../room_statistics/domain/room_statistics.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/multiplayer_game.dart';
import '../domain/room.dart';

class MultiplayerResultState {
  final String roomId;
  final String gameId;
  final int roundNumber;
  final String roomName;
  final String roomCode;
  final RoomStatus roomStatus;
  final String? winnerId;
  final String winnerName;
  final int totalCalls;
  final bool isYouWinner;
  final bool isForfeit;
  final bool isHost;
  final String currentUserId;
  final List<RoundPlayerOutcome> playerResults;
  final List<RoomPlayerStanding> leaderboard;
  final List<RoomRoundRecord> recentMatches;
  final bool isLoading;
  final bool isStartingNextRound;
  final String? errorMessage;

  const MultiplayerResultState({
    required this.roomId,
    this.gameId = '',
    this.roundNumber = 1,
    this.roomName = 'BINGO ROOM',
    this.roomCode = '',
    this.roomStatus = RoomStatus.completed,
    this.winnerId,
    this.winnerName = 'Winner',
    this.totalCalls = 0,
    this.isYouWinner = false,
    this.isForfeit = false,
    this.isHost = false,
    this.currentUserId = '',
    this.playerResults = const [],
    this.leaderboard = const [],
    this.recentMatches = const [],
    this.isLoading = true,
    this.isStartingNextRound = false,
    this.errorMessage,
  });

  MultiplayerResultState copyWith({
    String? roomId,
    String? gameId,
    int? roundNumber,
    String? roomName,
    String? roomCode,
    RoomStatus? roomStatus,
    String? winnerId,
    String? winnerName,
    int? totalCalls,
    bool? isYouWinner,
    bool? isForfeit,
    bool? isHost,
    String? currentUserId,
    List<RoundPlayerOutcome>? playerResults,
    List<RoomPlayerStanding>? leaderboard,
    List<RoomRoundRecord>? recentMatches,
    bool? isLoading,
    bool? isStartingNextRound,
    String? errorMessage,
  }) {
    return MultiplayerResultState(
      roomId: roomId ?? this.roomId,
      gameId: gameId ?? this.gameId,
      roundNumber: roundNumber ?? this.roundNumber,
      roomName: roomName ?? this.roomName,
      roomCode: roomCode ?? this.roomCode,
      roomStatus: roomStatus ?? this.roomStatus,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      totalCalls: totalCalls ?? this.totalCalls,
      isYouWinner: isYouWinner ?? this.isYouWinner,
      isForfeit: isForfeit ?? this.isForfeit,
      isHost: isHost ?? this.isHost,
      currentUserId: currentUserId ?? this.currentUserId,
      playerResults: playerResults ?? this.playerResults,
      leaderboard: leaderboard ?? this.leaderboard,
      recentMatches: recentMatches ?? this.recentMatches,
      isLoading: isLoading ?? this.isLoading,
      isStartingNextRound: isStartingNextRound ?? this.isStartingNextRound,
      errorMessage: errorMessage,
    );
  }
}

class MultiplayerResultNotifier extends StateNotifier<MultiplayerResultState> {
  final MultiplayerRepository _multiplayerRepository;
  final AuthRepository _authRepository;
  StreamSubscription<MultiplayerGame>? _gameSub;
  StreamSubscription<Room>? _roomSub;

  MultiplayerResultNotifier({
    required String roomId,
    required MultiplayerRepository multiplayerRepository,
    required AuthRepository authRepository,
  }) : _multiplayerRepository = multiplayerRepository,
       _authRepository = authRepository,
       super(MultiplayerResultState(roomId: roomId)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final currentUid = _authRepository.currentUserId ?? '';
      final game = await _multiplayerRepository.getGameForRoom(state.roomId);
      final room = await _multiplayerRepository.getRoom(state.roomId);
      final isHost = room?.hostId == currentUid;

      // Watch game for status changes (e.g. host starts next round)
      _gameSub?.cancel();
      _gameSub = _multiplayerRepository.watchGame(game.id).listen((
        updatedGame,
      ) {
        if (mounted) {
          state = state.copyWith(
            roundNumber: updatedGame.roundNumber,
            winnerId: updatedGame.winnerId,
          );
        }
      });

      // Watch room for transitions (e.g. host starts next round -> preparing, or returns to lobby -> waiting)
      _roomSub?.cancel();
      _roomSub = _multiplayerRepository.watchRoom(state.roomId).listen((
        updatedRoom,
      ) {
        if (mounted) {
          state = state.copyWith(
            roomStatus: updatedRoom.status,
            roomName: updatedRoom.name,
            roomCode: updatedRoom.code,
          );
        }
      });

      // Fetch actual game player states for genuine score and letters
      final gamePlayers = await _multiplayerRepository.getGamePlayers(game.id);

      // Build genuine player results across all historical game participants
      final List<RoundPlayerOutcome> outcomes = [];
      String winnerDisplayName = 'Winner';
      bool isYouWinner = false;

      for (final p in gamePlayers) {
        final actualLines = p.linesClaimed;
        final isThisWinner = p.isWinner ||
            actualLines >= 5 ||
            (game.winnerUserId != null && game.winnerUserId == p.userId);

        if (isThisWinner) {
          winnerDisplayName = p.displayName;
          if (p.userId == currentUid) isYouWinner = true;
        }

        final letters = ['B', 'I', 'N', 'G', 'O'].take(actualLines).toList();

        outcomes.add(
          RoundPlayerOutcome(
            userId: p.userId,
            displayName: p.displayName,
            avatarColorHex: p.avatarColorHex,
            isWinner: isThisWinner,
            isHost: p.isHost,
            isYou: p.userId == currentUid,
            isForfeited: p.isForfeited,
            linesClaimedCount: actualLines,
            claimedLetters: letters,
          ),
        );
      }

      // Fetch existing history to check if match was already recorded by RPC
      final existingHistory = await _multiplayerRepository.getRoomMatchHistory(
        state.roomId,
      );
      final alreadyRecorded =
          existingHistory.any((m) => m['game_id'] == game.id);

      if (!alreadyRecorded) {
        await _multiplayerRepository.finishRound(
          gameId: game.id,
          roomId: state.roomId,
          winnerId: game.winnerUserId ??
              (outcomes.where((o) => o.isWinner).firstOrNull?.userId),
          winnerName: winnerDisplayName,
          totalCalls: game.calledNumbers.length,
          playerOutcomes: outcomes.map((o) => o.toJson()).toList(),
          roundNumber: game.roundNumber,
        );
      }

      final rawLeaderboard = await _multiplayerRepository.getRoomLeaderboard(
        state.roomId,
      );
      final leaderboard = rawLeaderboard
          .map(
            (m) => RoomPlayerStanding(
              userId: m['user_id'] as String? ?? '',
              displayName: m['display_name'] as String? ?? 'Player',
              avatarColorHex: m['avatar_color_hex'] as String? ?? '#FC695C',
              isHost: m['is_host'] as bool? ?? false,
              isYou: m['is_you'] as bool? ?? false,
              rank: m['rank'] as int? ?? 1,
              roundsPlayed: m['rounds_played'] as int? ?? 0,
              roundsWon: m['rounds_won'] as int? ?? 0,
              draws: m['draws'] as int? ?? 0,
              losses: m['losses'] as int? ?? 0,
              winRate: m['win_rate'] as double? ?? 0.0,
              currentStreak: m['current_streak'] as int? ?? 0,
              bestStreak: m['best_streak'] as int? ?? 0,
              lastResult: m['last_result'] as String? ?? '',
              wonRounds:
                  (m['won_rounds'] as List<dynamic>?)
                      ?.map((e) => e as int)
                      .toList() ??
                  [],
            ),
          )
          .toList();

      final rawHistory = await _multiplayerRepository.getRoomMatchHistory(
        state.roomId,
      );
      final recentMatches = rawHistory
          .map((m) => RoomRoundRecord.fromJson(m, currentUserId: currentUid))
          .toList();

      final currentMatchHistory = rawHistory
              .where((m) => m['game_id'] == game.id)
              .firstOrNull ??
          rawHistory.firstOrNull;
      final isForfeit = currentMatchHistory?['is_forfeit'] == true ||
          currentMatchHistory?['finish_reason'] == 'forfeit' ||
          gamePlayers.any((p) => p.isForfeited);

      if (mounted) {
        state = state.copyWith(
          gameId: game.id,
          roundNumber: game.roundNumber,
          roomName: room?.name ?? 'FRIDAY BINGO CLUB',
          roomCode:
              room?.code ??
              state.roomId.toUpperCase().padRight(6, '0').substring(0, 6),
          roomStatus: room?.status ?? RoomStatus.completed,
          winnerId: game.winnerUserId,
          winnerName: winnerDisplayName,
          totalCalls: game.calledNumbers.isNotEmpty
              ? game.calledNumbers.length
              : 18,
          isYouWinner: isYouWinner,
          isForfeit: isForfeit,
          isHost: isHost,
          currentUserId: currentUid,
          playerResults: outcomes,
          leaderboard: leaderboard,
          recentMatches: recentMatches,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: ErrorMapper.map(e).message,
        );
      }
    }
  }

  Future<void> startNextRound() async {
    if (state.isStartingNextRound) return;
    state = state.copyWith(isStartingNextRound: true);
    try {
      await _multiplayerRepository.startNextRound(
        gameId: state.gameId,
        roomId: state.roomId,
        hostId: state.currentUserId,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isStartingNextRound: false,
          errorMessage: ErrorMapper.map(e).message,
        );
      }
    }
  }

  Future<void> returnToLobby() async {
    try {
      await _multiplayerRepository.returnToLobby(
        roomId: state.roomId,
        hostId: state.currentUserId,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: ErrorMapper.map(e).message);
      }
    }
  }

  Future<void> leaveRoom() async {
    try {
      await _multiplayerRepository.leaveRoom(state.roomId);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: ErrorMapper.map(e).message);
      }
    }
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }
}

final multiplayerResultNotifierProvider = StateNotifierProvider.autoDispose
    .family<MultiplayerResultNotifier, MultiplayerResultState, String>((
      ref,
      roomId,
    ) {
      final multiRepo = ref.watch(multiplayerRepositoryProvider);
      final authRepo = ref.watch(authRepositoryProvider);
      return MultiplayerResultNotifier(
        roomId: roomId,
        multiplayerRepository: multiRepo,
        authRepository: authRepo,
      );
    });
