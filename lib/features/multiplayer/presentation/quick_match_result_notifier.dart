import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/profile_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/quick_match_rematch.dart';

class QuickMatchResultState {
  final bool isLoading;
  final String? errorMessage;
  final QuickMatchResultData? resultData;
  final QuickMatchRematchRequest? pendingRematch;
  final bool isSendingRematch;
  final bool isRespondingRematch;
  final String? rematchNotice;
  final String? newMatchIdToNavigate;
  final int rematchSecondsRemaining;

  const QuickMatchResultState({
    this.isLoading = true,
    this.errorMessage,
    this.resultData,
    this.pendingRematch,
    this.isSendingRematch = false,
    this.isRespondingRematch = false,
    this.rematchNotice,
    this.newMatchIdToNavigate,
    this.rematchSecondsRemaining = 0,
  });

  bool get hasActivePendingRequest =>
      pendingRematch != null &&
      pendingRematch!.isPending &&
      !pendingRematch!.isExpired;

  bool isRequester(String currentUserId) =>
      pendingRematch?.isRequester(currentUserId) ?? false;

  QuickMatchResultState copyWith({
    bool? isLoading,
    String? errorMessage,
    QuickMatchResultData? resultData,
    QuickMatchRematchRequest? pendingRematch,
    bool clearPendingRematch = false,
    bool? isSendingRematch,
    bool? isRespondingRematch,
    String? rematchNotice,
    String? newMatchIdToNavigate,
    int? rematchSecondsRemaining,
  }) {
    return QuickMatchResultState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      resultData: resultData ?? this.resultData,
      pendingRematch: clearPendingRematch
          ? null
          : (pendingRematch ?? this.pendingRematch),
      isSendingRematch: isSendingRematch ?? this.isSendingRematch,
      isRespondingRematch: isRespondingRematch ?? this.isRespondingRematch,
      rematchNotice: rematchNotice,
      newMatchIdToNavigate: newMatchIdToNavigate ?? this.newMatchIdToNavigate,
      rematchSecondsRemaining:
          rematchSecondsRemaining ?? this.rematchSecondsRemaining,
    );
  }
}

final quickMatchResultProvider = StateNotifierProvider.autoDispose
    .family<QuickMatchResultNotifier, QuickMatchResultState, String>(
  (ref, matchId) {
    final repository = ref.watch(multiplayerRepositoryProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final profileRepo = ref.watch(profileRepositoryProvider);

    return QuickMatchResultNotifier(
      matchId: matchId,
      repository: repository,
      authRepo: authRepo,
      profileRepo: profileRepo,
    );
  },
);

class QuickMatchResultNotifier extends StateNotifier<QuickMatchResultState> {
  final String matchId;
  final MultiplayerRepository repository;
  final AuthRepository authRepo;
  final ProfileRepository profileRepo;

  StreamSubscription<QuickMatchRematchRequest?>? _rematchSub;
  StreamSubscription<QuickMatchRematchRequest?>? _userRematchSub;
  Timer? _countdownTimer;

  QuickMatchResultNotifier({
    required this.matchId,
    required this.repository,
    required this.authRepo,
    required this.profileRepo,
  }) : super(const QuickMatchResultState()) {
    _init();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rematchSub?.cancel();
    _userRematchSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final data = await repository.getQuickMatchResult(matchId);
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        resultData: data,
      );

      // Check for existing pending rematch request
      final existingReq =
          await repository.getPendingRematchRequest(matchId: matchId);
      if (existingReq != null && mounted) {
        _handleRematchUpdate(existingReq);
      }

      // Subscribe to user incoming rematch requests
      final currentUid = authRepo.currentUserId;
      if (currentUid != null) {
        _userRematchSub?.cancel();
        _userRematchSub =
            repository.watchUserRematchRequests(currentUid).listen((req) {
          if (!mounted || req == null) return;
          if (req.previousMatchId == matchId) {
            _handleRematchUpdate(req);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load match results: $e',
      );
    }
  }

  void _handleRematchUpdate(QuickMatchRematchRequest req) {
    if (!mounted) return;

    if (req.isAccepted && req.newMatchId != null) {
      _countdownTimer?.cancel();
      state = state.copyWith(
        pendingRematch: req,
        newMatchIdToNavigate: req.newMatchId,
        rematchNotice: 'Rematch accepted! Launching new match...',
      );
      return;
    }

    if (req.isDeclined) {
      _countdownTimer?.cancel();
      state = state.copyWith(
        clearPendingRematch: true,
        rematchNotice: 'Rematch was declined by opponent.',
        rematchSecondsRemaining: 0,
      );
      return;
    }

    if (req.isCancelled) {
      _countdownTimer?.cancel();
      state = state.copyWith(
        clearPendingRematch: true,
        rematchNotice: 'Rematch request was cancelled.',
        rematchSecondsRemaining: 0,
      );
      return;
    }

    if (req.isExpired) {
      _countdownTimer?.cancel();
      state = state.copyWith(
        clearPendingRematch: true,
        rematchNotice: 'Rematch request expired.',
        rematchSecondsRemaining: 0,
      );
      return;
    }

    if (req.isPending) {
      state = state.copyWith(
        pendingRematch: req,
        rematchSecondsRemaining: req.secondsRemaining,
      );

      _startRematchCountdown();

      // Subscribe to this specific request
      _rematchSub?.cancel();
      _rematchSub = repository.watchRematchRequest(req.id).listen((updated) {
        if (updated != null && mounted) {
          _handleRematchUpdate(updated);
        }
      });
    }
  }

  void _startRematchCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = state.rematchSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(
          clearPendingRematch: true,
          rematchSecondsRemaining: 0,
          rematchNotice: 'Rematch request timed out.',
        );
      } else {
        state = state.copyWith(rematchSecondsRemaining: remaining);
      }
    });
  }

  Future<void> sendRematchRequest() async {
    if (state.hasActivePendingRequest || state.isSendingRematch) return;

    state = state.copyWith(
      isSendingRematch: true,
      rematchNotice: null,
    );

    try {
      final res = await repository.requestQuickMatchRematch(matchId);
      if (!mounted) return;

      state = state.copyWith(isSendingRematch: false);

      if (res['success'] == true) {
        final req = QuickMatchRematchRequest.fromJson(
          res,
          currentUserId: authRepo.currentUserId,
        );
        _handleRematchUpdate(req);
      } else {
        state = state.copyWith(
          rematchNotice: res['error']?.toString() ?? 'Failed to send rematch request',
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isSendingRematch: false,
        rematchNotice: 'Error sending rematch: $e',
      );
    }
  }

  Future<void> acceptRematch() async {
    final req = state.pendingRematch;
    if (req == null || !req.isPending || state.isRespondingRematch) return;

    state = state.copyWith(isRespondingRematch: true);

    try {
      final res = await repository.respondQuickMatchRematch(req.id, true);
      if (!mounted) return;

      state = state.copyWith(isRespondingRematch: false);

      if (res['success'] == true && res['status'] == 'ACCEPTED') {
        final newMatchId = res['new_match_id'] as String?;
        state = state.copyWith(
          newMatchIdToNavigate: newMatchId,
          rematchNotice: 'Rematch accepted! Launching new match...',
        );
      } else {
        state = state.copyWith(
          rematchNotice: res['error']?.toString() ?? 'Failed to accept rematch',
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isRespondingRematch: false,
        rematchNotice: 'Error accepting rematch: $e',
      );
    }
  }

  Future<void> declineRematch() async {
    final req = state.pendingRematch;
    if (req == null || state.isRespondingRematch) return;

    state = state.copyWith(isRespondingRematch: true);

    try {
      await repository.respondQuickMatchRematch(req.id, false);
      if (!mounted) return;

      _countdownTimer?.cancel();
      state = state.copyWith(
        isRespondingRematch: false,
        clearPendingRematch: true,
        rematchNotice: 'Rematch declined.',
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isRespondingRematch: false,
        clearPendingRematch: true,
      );
    }
  }

  Future<void> cancelRematch() async {
    final req = state.pendingRematch;
    if (req == null) return;

    try {
      await repository.cancelQuickMatchRematch(req.id);
      if (!mounted) return;

      _countdownTimer?.cancel();
      state = state.copyWith(
        clearPendingRematch: true,
        rematchNotice: 'Rematch request cancelled.',
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(clearPendingRematch: true);
    }
  }

  Future<void> cleanUpOnLeaveHome() async {
    final req = state.pendingRematch;
    if (req != null && req.isPending) {
      try {
        await repository.cancelQuickMatchRematch(req.id);
      } catch (_) {}
    }
    _countdownTimer?.cancel();
    _rematchSub?.cancel();
    _userRematchSub?.cancel();
  }
}
