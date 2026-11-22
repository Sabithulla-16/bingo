import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/profile_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/quick_match.dart';

@immutable
class OpponentFoundState {
  final QuickMatch? match;
  final bool isLoading;
  final int remainingSeconds;
  final double progressFraction;
  final bool isTransitioning;
  final bool shouldNavigateToBoardPrep;
  final String? errorMessage;
  final String currentUserName;
  final String currentUserAvatarColor;
  final String opponentName;
  final String opponentAvatarColor;

  const OpponentFoundState({
    this.match,
    this.isLoading = true,
    this.remainingSeconds = 10,
    this.progressFraction = 1.0,
    this.isTransitioning = false,
    this.shouldNavigateToBoardPrep = false,
    this.errorMessage,
    this.currentUserName = 'Alex',
    this.currentUserAvatarColor = '#20243A',
    this.opponentName = 'Opponent',
    this.opponentAvatarColor = '#FC695C',
  });

  OpponentFoundState copyWith({
    QuickMatch? match,
    bool? isLoading,
    int? remainingSeconds,
    double? progressFraction,
    bool? isTransitioning,
    bool? shouldNavigateToBoardPrep,
    String? errorMessage,
    String? currentUserName,
    String? currentUserAvatarColor,
    String? opponentName,
    String? opponentAvatarColor,
  }) {
    return OpponentFoundState(
      match: match ?? this.match,
      isLoading: isLoading ?? this.isLoading,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      progressFraction: progressFraction ?? this.progressFraction,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      shouldNavigateToBoardPrep:
          shouldNavigateToBoardPrep ?? this.shouldNavigateToBoardPrep,
      errorMessage: errorMessage,
      currentUserName: currentUserName ?? this.currentUserName,
      currentUserAvatarColor:
          currentUserAvatarColor ?? this.currentUserAvatarColor,
      opponentName: opponentName ?? this.opponentName,
      opponentAvatarColor: opponentAvatarColor ?? this.opponentAvatarColor,
    );
  }
}

final opponentFoundProvider = StateNotifierProvider.autoDispose
    .family<OpponentFoundNotifier, OpponentFoundState, String>((
  ref,
  matchId,
) {
  final repository = ref.watch(multiplayerRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  return OpponentFoundNotifier(
    matchId: matchId,
    repository: repository,
    authRepo: authRepo,
    profileRepo: profileRepo,
  );
});

class OpponentFoundNotifier extends StateNotifier<OpponentFoundState> {
  final String matchId;
  final MultiplayerRepository repository;
  final AuthRepository authRepo;
  final ProfileRepository profileRepo;

  Timer? _tickTimer;
  StreamSubscription<QuickMatch?>? _matchSub;
  bool _hasTransitioned = false;

  OpponentFoundNotifier({
    required this.matchId,
    required this.repository,
    required this.authRepo,
    required this.profileRepo,
  }) : super(const OpponentFoundState()) {
    _init();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _matchSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final currentUid = authRepo.currentUserId;
    if (currentUid != null) {
      final p = await profileRepo.getProfile(currentUid);
      if (p != null && mounted) {
        state = state.copyWith(
          currentUserName: p.displayName,
          currentUserAvatarColor: p.avatarColorHex,
        );
      }
    }

    try {
      final qm = await repository.getQuickMatch(matchId);
      if (!mounted) return;

      if (qm != null) {
        _applyMatchUpdate(qm);
      }

      // Subscribe to realtime changes on this match
      _matchSub = repository.watchQuickMatch(matchId).listen((updatedMatch) {
        if (!mounted || updatedMatch == null) return;
        _applyMatchUpdate(updatedMatch);
      });

      _startAuthoritativeCountdown();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load match details',
      );
    }
  }

  void _applyMatchUpdate(QuickMatch qm) {
    final currentUid = authRepo.currentUserId;
    String oppName = 'Opponent';
    String oppColor = '#FC695C';

    if (qm.opponent != null) {
      oppName = qm.opponent!.displayName;
      oppColor = qm.opponent!.avatarColorHex;
    } else if (qm.player1Id == currentUid && qm.player2 != null) {
      oppName = qm.player2!.displayName;
      oppColor = qm.player2!.avatarColorHex;
    } else if (qm.player2Id == currentUid && qm.player1 != null) {
      oppName = qm.player1!.displayName;
      oppColor = qm.player1!.avatarColorHex;
    }

    final isBoardPrep = qm.status == QuickMatchStatus.boardPreparation ||
        qm.status == QuickMatchStatus.inProgress;

    state = state.copyWith(
      match: qm,
      isLoading: false,
      opponentName: oppName,
      opponentAvatarColor: oppColor,
      shouldNavigateToBoardPrep: isBoardPrep,
    );

    if (isBoardPrep) {
      _tickTimer?.cancel();
    }
  }

  void _startAuthoritativeCountdown() {
    _updateRemainingTime();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    final qm = state.match;
    if (qm == null || !mounted) return;

    if (qm.status == QuickMatchStatus.boardPreparation ||
        qm.status == QuickMatchStatus.inProgress) {
      state = state.copyWith(
        remainingSeconds: 0,
        progressFraction: 0.0,
        shouldNavigateToBoardPrep: true,
      );
      _tickTimer?.cancel();
      return;
    }

    final diffMs = qm.countdownDeadline.difference(DateTime.now()).inMilliseconds;
    final remainingSecs = max(0, (diffMs / 1000).ceil());
    final fraction = (diffMs / 10000.0).clamp(0.0, 1.0);

    state = state.copyWith(
      remainingSeconds: remainingSecs,
      progressFraction: fraction,
    );

    if (diffMs <= 0 && !_hasTransitioned) {
      _hasTransitioned = true;
      _tickTimer?.cancel();
      _transitionToBoardPrep();
    }
  }

  Future<void> _transitionToBoardPrep() async {
    state = state.copyWith(isTransitioning: true);
    try {
      final res = await repository.transitionToBoardPrep(matchId);
      if (!mounted) return;
      if (res['success'] == true) {
        state = state.copyWith(
          isTransitioning: false,
          shouldNavigateToBoardPrep: true,
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          isTransitioning: false,
          shouldNavigateToBoardPrep: true,
        );
      }
    }
  }
}
