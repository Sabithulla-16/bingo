import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../authentication/domain/auth_state.dart';
import '../../profile/domain/profile_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/quick_match.dart';

enum QuickMatchScreenStatus {
  idle,
  searching,
  matched,
  error;
}

@immutable
class QuickMatchState {
  final QuickMatchScreenStatus status;
  final int elapsedSeconds;
  final String? matchId;
  final String? errorMessage;
  final String? currentUserId;
  final String currentUserDisplayName;
  final String currentUserAvatarColorHex;
  final bool isGuest;
  final String serverRegion;
  final String matchmakingStatusText;

  const QuickMatchState({
    this.status = QuickMatchScreenStatus.idle,
    this.elapsedSeconds = 0,
    this.matchId,
    this.errorMessage,
    this.currentUserId,
    this.currentUserDisplayName = 'YOU',
    this.currentUserAvatarColorHex = '#20243A',
    this.isGuest = false,
    this.serverRegion = 'Auto (Detecting...)',
    this.matchmakingStatusText = 'Connecting...',
  });

  bool get isIdle => status == QuickMatchScreenStatus.idle;
  bool get isSearching => status == QuickMatchScreenStatus.searching;
  bool get isMatched => status == QuickMatchScreenStatus.matched;
  bool get hasError => status == QuickMatchScreenStatus.error;

  String get elapsedTimerString {
    final mins = elapsedSeconds ~/ 60;
    final secs = elapsedSeconds % 60;
    final mStr = mins < 10 ? '0$mins' : '$mins';
    final sStr = secs < 10 ? '0$secs' : '$secs';
    return '$mStr:$sStr';
  }

  QuickMatchState copyWith({
    QuickMatchScreenStatus? status,
    int? elapsedSeconds,
    String? matchId,
    bool clearMatchId = false,
    String? errorMessage,
    String? currentUserId,
    String? currentUserDisplayName,
    String? currentUserAvatarColorHex,
    bool? isGuest,
    String? serverRegion,
    String? matchmakingStatusText,
  }) {
    return QuickMatchState(
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      matchId: clearMatchId ? null : (matchId ?? this.matchId),
      errorMessage: errorMessage,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserDisplayName:
          currentUserDisplayName ?? this.currentUserDisplayName,
      currentUserAvatarColorHex:
          currentUserAvatarColorHex ?? this.currentUserAvatarColorHex,
      isGuest: isGuest ?? this.isGuest,
      serverRegion: serverRegion ?? this.serverRegion,
      matchmakingStatusText:
          matchmakingStatusText ?? this.matchmakingStatusText,
    );
  }
}

final quickMatchProvider =
    StateNotifierProvider.autoDispose<QuickMatchNotifier, QuickMatchState>((
  ref,
) {
  final repository = ref.watch(multiplayerRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final authState = ref.watch(authStateProvider);

  return QuickMatchNotifier(
    repository: repository,
    authRepo: authRepo,
    profileRepo: profileRepo,
    authState: authState,
  );
});

class QuickMatchNotifier extends StateNotifier<QuickMatchState> {
  final MultiplayerRepository repository;
  final AuthRepository authRepo;
  final ProfileRepository profileRepo;
  final AppAuthState authState;

  Timer? _elapsedTimer;
  StreamSubscription<MatchmakingQueueEntry?>? _queueSubscription;
  DateTime _currentSearchStartTime = DateTime.now();

  QuickMatchNotifier({
    required this.repository,
    required this.authRepo,
    required this.profileRepo,
    required this.authState,
  }) : super(const QuickMatchState()) {
    _initialize();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _queueSubscription?.cancel();
    if (state.isSearching) {
      repository.cancelMatchmaking();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final isGuest = authState is AuthGuest;
    final userId = authRepo.currentUserId;

    if (isGuest || userId == null) {
      state = state.copyWith(
        isGuest: true,
        currentUserDisplayName: 'Guest Player',
        currentUserAvatarColorHex: '#20243A',
      );
      return;
    }

    final profile = await profileRepo.getProfile(userId);
    final displayName = profile?.displayName ?? 'Alex';
    final avatarColor = profile?.avatarColorHex ?? '#20243A';

    state = state.copyWith(
      isGuest: false,
      currentUserId: userId,
      currentUserDisplayName: displayName,
      currentUserAvatarColorHex: avatarColor,
    );

    // Check for genuinely active match on startup (session restore)
    try {
      final activeMatch = await repository.getActiveQuickMatch();
      if (activeMatch != null &&
          activeMatch.status != QuickMatchStatus.completed &&
          activeMatch.status != QuickMatchStatus.forfeited &&
          activeMatch.status != QuickMatchStatus.cancelled &&
          mounted) {
        final now = DateTime.now();
        final isCountdownValid = activeMatch.status == QuickMatchStatus.countdown &&
            activeMatch.countdownDeadline.add(const Duration(seconds: 25)).isAfter(now);
        final isPrepOrPlay = activeMatch.status == QuickMatchStatus.boardPreparation ||
            activeMatch.status == QuickMatchStatus.inProgress;
        if (isCountdownValid || isPrepOrPlay) {
          state = state.copyWith(
            status: QuickMatchScreenStatus.matched,
            matchId: activeMatch.id,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> startSearching() async {
    if (state.isGuest) return;
    if (state.isSearching || state.isMatched) return;
    final userId = authRepo.currentUserId;
    if (userId == null) return;

    _currentSearchStartTime = DateTime.now();

    state = state.copyWith(
      status: QuickMatchScreenStatus.searching,
      clearMatchId: true,
      elapsedSeconds: 0,
      errorMessage: null,
      matchmakingStatusText: 'Connecting...',
    );

    // Start local elapsed timer
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      state = state.copyWith(
        elapsedSeconds: state.elapsedSeconds + 1,
        matchmakingStatusText:
            state.elapsedSeconds > 3 ? 'Searching for players...' : 'Connecting...',
      );
    });

    // Subscribe to realtime queue changes for this user
    _queueSubscription?.cancel();
    _queueSubscription = repository.watchMatchmakingQueue(userId).listen(
      (entry) {
        if (!mounted || entry == null) return;
        if (entry.status == MatchmakingQueueStatus.matched &&
            entry.matchId != null) {
          final eventTime = entry.matchedAt ?? entry.queuedAt;
          if (eventTime.isBefore(
            _currentSearchStartTime.subtract(const Duration(seconds: 5)),
          )) {
            // Reject stale historical event from previous match session
            return;
          }
          _elapsedTimer?.cancel();
          state = state.copyWith(
            status: QuickMatchScreenStatus.matched,
            matchId: entry.matchId,
          );
        }
      },
      onError: (err) {
        // Ignored; authoritative enterMatchmaking RPC handles state
      },
    );

    try {
      final result = await repository.enterMatchmaking();
      if (!mounted) return;

      if (result['success'] == true) {
        final matchStatus = result['status'] as String?;
        if (matchStatus == 'MATCHED') {
          _elapsedTimer?.cancel();
          final matchId = result['match_id'] as String?;
          state = state.copyWith(
            status: QuickMatchScreenStatus.matched,
            matchId: matchId,
          );
        } else {
          state = state.copyWith(
            status: QuickMatchScreenStatus.searching,
            serverRegion: 'Auto',
          );
        }
      } else {
        _elapsedTimer?.cancel();
        state = state.copyWith(
          status: QuickMatchScreenStatus.error,
          errorMessage: result['error'] as String? ?? 'Failed to enter queue',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _elapsedTimer?.cancel();
      state = state.copyWith(
        status: QuickMatchScreenStatus.error,
        errorMessage: 'Network error connecting to matchmaking',
      );
    }
  }

  Future<void> cancelSearching() async {
    _elapsedTimer?.cancel();
    _queueSubscription?.cancel();

    try {
      final res = await repository.cancelMatchmaking();
      if (!mounted) return;

      if (res['reason'] == 'ALREADY_MATCHED' && state.isSearching) {
        // Race condition: Match committed just before cancel
        final matchId = res['match_id'] as String?;
        if (matchId != null && matchId.isNotEmpty) {
          state = state.copyWith(
            status: QuickMatchScreenStatus.matched,
            matchId: matchId,
          );
          return;
        }
      }

      state = state.copyWith(
        status: QuickMatchScreenStatus.idle,
        clearMatchId: true,
        elapsedSeconds: 0,
        errorMessage: null,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: QuickMatchScreenStatus.idle,
        clearMatchId: true,
        elapsedSeconds: 0,
      );
    }
  }
}
