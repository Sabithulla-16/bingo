import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../multiplayer/data/multiplayer_repository.dart';
import '../../multiplayer/data/multiplayer_repository_provider.dart';
import '../domain/room_statistics.dart';

enum RoomStatisticsTab { leaderboard, matchHistory }

class RoomStatisticsState {
  final String roomId;
  final String roomCode;
  final RoomStatisticsTab selectedTab;
  final RoomSessionOverview overview;
  final List<RoomPlayerStanding> standings;
  final List<RoomRoundRecord> history;
  final bool isLoading;
  final String? errorMessage;

  const RoomStatisticsState({
    required this.roomId,
    this.roomCode = '',
    this.selectedTab = RoomStatisticsTab.leaderboard,
    this.overview = const RoomSessionOverview(
      totalRounds: 0,
      activePlayers: 0,
      leaderName: 'None',
      leaderWins: 0,
    ),
    this.standings = const [],
    this.history = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  RoomStatisticsState copyWith({
    String? roomId,
    String? roomCode,
    RoomStatisticsTab? selectedTab,
    RoomSessionOverview? overview,
    List<RoomPlayerStanding>? standings,
    List<RoomRoundRecord>? history,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RoomStatisticsState(
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      selectedTab: selectedTab ?? this.selectedTab,
      overview: overview ?? this.overview,
      standings: standings ?? this.standings,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class RoomStatisticsNotifier extends StateNotifier<RoomStatisticsState> {
  final MultiplayerRepository _multiplayerRepository;
  final AuthRepository _authRepository;

  RoomStatisticsNotifier({
    required String roomId,
    required MultiplayerRepository multiplayerRepository,
    required AuthRepository authRepository,
  })  : _multiplayerRepository = multiplayerRepository,
        _authRepository = authRepository,
        super(RoomStatisticsState(roomId: roomId)) {
    loadStatistics();
  }

  Future<void> loadStatistics() async {
    try {
      final currentUid = _authRepository.currentUserId ?? '';
      final room = await _multiplayerRepository.getRoom(state.roomId);
      final rawLeaderboard = await _multiplayerRepository.getRoomLeaderboard(state.roomId);
      final rawHistory = await _multiplayerRepository.getRoomMatchHistory(state.roomId);

      final standings = rawLeaderboard
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
              wonRounds: (m['won_rounds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
            ),
          )
          .toList();

      final history = rawHistory
          .map((m) => RoomRoundRecord.fromJson(m, currentUserId: currentUid))
          .toList();

      final leader = standings.isNotEmpty ? standings.first : null;
      final overview = RoomSessionOverview(
        totalRounds: history.length,
        activePlayers: standings.length,
        leaderName: leader != null ? '${leader.displayName} 👑' : 'None',
        leaderWins: leader?.roundsWon ?? 0,
      );

      if (mounted) {
        state = state.copyWith(
          roomCode: room?.code ?? state.roomId.toUpperCase().padRight(6, '0').substring(0, 6),
          overview: overview,
          standings: standings,
          history: history,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  void switchTab(RoomStatisticsTab tab) {
    state = state.copyWith(selectedTab: tab);
  }
}

final roomStatisticsNotifierProvider = StateNotifierProvider.autoDispose
    .family<RoomStatisticsNotifier, RoomStatisticsState, String>((ref, roomId) {
  final multiRepo = ref.watch(multiplayerRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return RoomStatisticsNotifier(
    roomId: roomId,
    multiplayerRepository: multiRepo,
    authRepository: authRepo,
  );
});
