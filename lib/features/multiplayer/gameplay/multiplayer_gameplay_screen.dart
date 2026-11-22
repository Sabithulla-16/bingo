import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/game_engine/board_coordinate.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/theme/board_theme_config.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/bingo_cell.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../store/data/store_repository.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/multiplayer_game.dart';
import '../domain/room.dart';
import '../presentation/multiplayer_game_notifier.dart';

/// Multiplayer Gameplay Screen (Stitch Screen 13: `99e26fda63c3428a82b9702145ca87f5`)
class MultiplayerGameplayScreen extends ConsumerStatefulWidget {
  final String roomId;

  const MultiplayerGameplayScreen({super.key, required this.roomId});

  @override
  ConsumerState<MultiplayerGameplayScreen> createState() =>
      _MultiplayerGameplayScreenState();
}

class _MultiplayerGameplayScreenState
    extends ConsumerState<MultiplayerGameplayScreen> {
  String? _navigatedGameId;
  bool _isForfeiting = false;
  bool _hasNavigatedHome = false;
  bool get _hasNavigated => _navigatedGameId != null || _hasNavigatedHome;

  void _navigateToHomeOnForfeit() {
    if (_hasNavigatedHome || !mounted) return;
    _hasNavigatedHome = true;
    _navigatedGameId = 'forfeited';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.home);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You forfeited the match and left the room.'),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _navigateToResult([String? gameId]) {
    if (_hasNavigatedHome) return;
    final activeId = gameId ??
        ref.read(multiplayerGameProvider(widget.roomId)).game?.id ??
        'default';
    if (_navigatedGameId == activeId || !mounted) return;
    _navigatedGameId = activeId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_hasNavigatedHome) {
        try {
          final room = ref.read(multiplayerGameProvider(widget.roomId)).room;
          final isQuickMatch = room?.isQuickMatch == true;
          if (isQuickMatch) {
            final repo = ref.read(multiplayerRepositoryProvider);
            final qm = await repo.getQuickMatchByRoomId(widget.roomId);
            if (qm != null && mounted) {
              context.go(AppRoutes.quickMatchResultPath(qm.id));
              return;
            }
          }
          if (mounted) {
            context.go(AppRoutes.multiplayerResultPath(widget.roomId));
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomId = widget.roomId;
    final state = ref.watch(multiplayerGameProvider(roomId));
    final notifier = ref.read(multiplayerGameProvider(roomId).notifier);
    final customization = ref.watch(playerCustomizationProvider);

    // Auto-navigate to result screen upon match conclusion and trigger audio feedback
    ref.listen<MultiplayerGameState>(multiplayerGameProvider(roomId), (
      prev,
      next,
    ) {
      final currentUid = next.currentUserId;
      final isCurrentUserForfeited = _isForfeiting ||
          next.isCurrentPlayerForfeited ||
          (currentUid != null &&
              next.players.any((p) => p.userId == currentUid && p.isForfeited));

      if (isCurrentUserForfeited) {
        final isQm = next.room?.isQuickMatch == true;
        if (isQm) {
          _navigateToResult(next.game?.id);
        } else {
          _navigateToHomeOnForfeit();
        }
        return;
      }

      // 1. Critical BINGO Victory Trigger: Play upgraded BINGO victory sound whenever
      // ANY multiplayer participant achieves 5 lines or the authoritative game completes.
      final wasCompleted =
          prev?.game?.status == MultiplayerGameStatus.completed;
      final isCompleted = next.game?.status == MultiplayerGameStatus.completed;
      final hadWinner = prev?.game?.winnerUserId != null;
      final hasWinner = next.game?.winnerUserId != null;
      final anyPlayerWon =
          next.players.any((p) => p.linesClaimed >= 5 || p.isWinner) ||
          next.hasWon;
      final prevAnyPlayerWon =
          (prev?.players.any((p) => p.linesClaimed >= 5 || p.isWinner) ??
              false) ||
          (prev?.hasWon ?? false);

      if ((isCompleted && !wasCompleted) ||
          (hasWinner && !hadWinner) ||
          (anyPlayerWon && !prevAnyPlayerWon)) {
        ref.read(feedbackServiceProvider).victoryBingo();
      }

      // 2. Line Strike Sound: Whenever local player or another participant claims a line
      final prevMyLines = prev?.claimedLines.length ?? 0;
      final nextMyLines = next.claimedLines.length;
      final prevOtherLines =
          prev?.players
              .where((p) => p.userId != next.currentUserId)
              .fold<int>(0, (sum, p) => sum + p.linesClaimed) ??
          0;
      final nextOtherLines = next.players
          .where((p) => p.userId != next.currentUserId)
          .fold<int>(0, (sum, p) => sum + p.linesClaimed);

      if ((nextMyLines > prevMyLines || nextOtherLines > prevOtherLines) &&
          !isCompleted &&
          !anyPlayerWon) {
        ref.read(feedbackServiceProvider).claimLine();
      }

      // 3. Number Call Sound: Whenever a new number is successfully called (by any player)
      final prevCalls = prev?.game?.calledNumbers.length ?? 0;
      final nextCalls = next.game?.calledNumbers.length ?? 0;
      if (nextCalls > prevCalls) {
        ref.read(feedbackServiceProvider).callNumber();
      }

      // Automatic navigation to Multiplayer Result screen for active winner / participants
      if (next.isMatchOver ||
          next.room?.status == RoomStatus.completed ||
          (isCompleted && !wasCompleted) ||
          (hasWinner && !hadWinner) ||
          (anyPlayerWon && !prevAnyPlayerWon)) {
        if (!isCurrentUserForfeited && !_isForfeiting && !_hasNavigatedHome) {
          _navigateToResult(next.game?.id);
        }
      }
    });

    // Handle immediate redirect if screen was opened for an already concluded match
    if (state.isMatchOver && !state.isLoading && _navigatedGameId == null) {
      final isCurrentUserForfeited = _isForfeiting ||
          state.isCurrentPlayerForfeited ||
          (state.currentUserId != null &&
              state.players.any(
                (p) => p.userId == state.currentUserId && p.isForfeited,
              ));
      if (isCurrentUserForfeited) {
        _navigateToHomeOnForfeit();
      } else {
        _navigateToResult(state.game?.id);
      }
    }

    final roomName = state.room?.name ?? 'Bingo Room';
    final roomCode = state.room?.code ?? '......';
    final currentTurnUserId = state.game?.currentTurnUserId;
    final currentTurnPlayer = state.players
        .where((p) => p.userId == currentTurnUserId)
        .firstOrNull;

    return ResponsiveScaffold(
      backgroundColor: AppColors.background,
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCoral),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(context, roomCode),
                  const SizedBox(height: 10),

                  // Error Banner (e.g. connection issue or game error)
                  if (state.errorMessage != null) ...[
                    AppErrorBanner(
                      message: state.errorMessage!,
                      isDismissible: true,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Toast Notification Banner (Live opponent action event)
                  if (state.toastNotification != null) ...[
                    _buildToastBanner(state.toastNotification!),
                    const SizedBox(height: 10),
                  ],

                  // Match Status Strip
                  _buildMatchStatusStrip(roomName, state),
                  const SizedBox(height: 12),

                  // Multiplayer Presence Rail (Horizontal compact player cards)
                  _buildPresenceRail(state, customization),
                  const SizedBox(height: 14),

                  // Turn Indicator Banner
                  _buildTurnBanner(state, currentTurnPlayer),
                  const SizedBox(height: 14),

                  // Private 5x5 Bingo Board (Center Stage)
                  _buildPrivateBoard(
                    context,
                    ref,
                    state,
                    notifier,
                    customization,
                  ),
                  const SizedBox(height: 14),

                  // Line Claiming Interface (Consistent Stitch design layout for all players)
                  if (!state.isMatchOver) ...[
                    _buildLineClaimCard(ref, state, notifier),
                    const SizedBox(height: 14),
                  ],

                  // Called Numbers History Rail
                  _buildCalledNumbersRail(context, state),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, String roomCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryCoral,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'B',
                style: AppTypography.labelLg.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'BINGO',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryCoral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    roomCode,
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primaryNavy,
              ),
              onPressed: () =>
                  context.push(AppRoutes.roomStatisticsPath(widget.roomId)),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.primaryNavy,
              ),
              onPressed: () => _confirmExit(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToastBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadii.roundedFull,
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Just now',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchStatusStrip(String roomName, MultiplayerGameState state) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  roomName.toUpperCase(),
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFDAD6),
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE MATCH',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF690005),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.lightLavender,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  'R${state.game?.roundNumber ?? 1}',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceRail(MultiplayerGameState state, dynamic customization) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Players In Room (${state.players.length})',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Private Boards',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: state.players.map((player) {
            final isYou = player.userId == state.currentUserId;
            final isTurn = !player.isForfeited &&
                player.userId == state.game?.currentTurnUserId;
            final letters = ['B', 'I', 'N', 'G', 'O'];
            final playerCount = state.players.length;
            final isCompact = playerCount >= 4;

            return Expanded(
              child: Opacity(
                opacity: player.isForfeited ? 0.55 : 1.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 4 : 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedMd,
                    border: player.isForfeited
                        ? Border.all(
                            color: AppColors.structuralBorder.withAlpha(120),
                            width: 1,
                          )
                        : isYou
                            ? Border.all(
                                color: AppColors.primaryCoral,
                                width: 1.5,
                              )
                            : isTurn
                                ? Border.all(
                                    color: AppColors.primaryNavy,
                                    width: 1.2,
                                  )
                                : Border.all(
                                    color: AppColors.structuralBorder,
                                    width: 1,
                                  ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadowColor,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PlayerAvatar(
                                displayName: player.displayName,
                                size: isCompact ? 20 : 24,
                                avatarId: isYou ? customization.avatarId : null,
                                hasGoldenFrame: isYou
                                    ? customization.hasGoldenFrame
                                    : false,
                                backgroundColor: Color(
                                  int.parse(
                                    player.avatarColorHex.replaceFirst(
                                      '#',
                                      '0xFF',
                                    ),
                                  ),
                                ),
                              ),
                              if (!player.isForfeited)
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.readyGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isYou ? 'You' : player.displayName,
                                  style: AppTypography.labelSm.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isCompact ? 10 : 11,
                                    color: player.isForfeited
                                        ? AppColors.textSecondary
                                        : AppColors.primaryNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  children: [
                                    if (player.isForfeited)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.errorRed.withAlpha(200),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'FORFEITED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      )
                                    else ...[
                                      Text(
                                        player.isHost ? 'HOST' : 'GUEST',
                                        style: AppTypography.labelSm.copyWith(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w800,
                                          color: player.isHost
                                              ? AppColors.primaryCoral
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                      if (isTurn)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2.5,
                                            vertical: 0.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryNavy,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: const Text(
                                            'TURN',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 6.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lines',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: isCompact ? 9 : 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${player.linesClaimed}/5',
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: player.linesClaimed > 0
                                ? AppColors.primaryCoral
                                : AppColors.textSecondary,
                            fontSize: isCompact ? 9 : 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Mini BINGO Progress Badges (Expanded so they flex cleanly to any width)
                    Row(
                      children: List.generate(5, (idx) {
                        final isEarned = player.linesClaimed > idx;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            height: isCompact ? 12 : 14,
                            decoration: BoxDecoration(
                              color: isEarned
                                  ? AppColors.primaryCoral
                                  : AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              letters[idx],
                              style: AppTypography.labelSm.copyWith(
                                fontSize: isCompact ? 7.0 : 8.5,
                                fontWeight: FontWeight.w800,
                                color: isEarned
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        ),
      ],
    );
  }

  Widget _buildTurnBanner(
    MultiplayerGameState state,
    MultiplayerPlayerState? currentTurnPlayer,
  ) {
    final isMyTurn = state.isMyTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: AppRadii.roundedLg,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isMyTurn
                        ? AppColors.primaryCoral
                        : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMyTurn
                            ? 'YOUR TURN (${state.remainingTurnSeconds}s)'
                            : "${currentTurnPlayer?.displayName.toUpperCase() ?? 'PLAYER'}'S TURN (${state.remainingTurnSeconds}s)",
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isMyTurn
                            ? 'Tap any uncalled number on your card to call it'
                            : 'Waiting for player to call a number...',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.lightLavender,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isMyTurn ? Icons.touch_app_rounded : Icons.hourglass_empty_rounded,
            color: isMyTurn ? AppColors.primaryCoral : AppColors.textSecondary,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateBoard(
    BuildContext context,
    WidgetRef ref,
    MultiplayerGameState state,
    MultiplayerGameNotifier notifier,
    dynamic customization,
  ) {
    // The Stitch Velvet Daub design is the common source of truth for multiplayer gameplay.
    // All participants (host and guests) share the canonical crisp white board appearance.
    final theme = BoardThemeConfig.classic();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.roundedXl,
        border: Border.all(color: AppColors.structuralBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your Board',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: Text(
                      '5×5 Standard',
                      style: AppTypography.labelSm.copyWith(fontSize: 9),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.readyGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Ready',
                    style: AppTypography.labelSm.copyWith(fontSize: 10),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryCoral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Claimed',
                    style: AppTypography.labelSm.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final coord = BoardCoordinate.fromIndex(index);
              final number = state.userBoard.getNumberAtCoord(coord);
              final cellState = state.cellStateFor(number, coord);
              final canCall =
                  state.isMyTurn &&
                  cellState == BingoCellState.available &&
                  !state.isMatchOver &&
                  !_hasNavigated;

              return BingoCell(
                number: number,
                state: cellState,
                isInteractive: canCall,
                themeConfig: theme,
                numberStyleId: customization.numberStyleId as int? ?? 5,
                onTap: canCall
                    ? () {
                        notifier.callNumber(number);
                      }
                    : () => ref.read(feedbackServiceProvider).lightTap(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLineClaimCard(
    WidgetRef ref,
    MultiplayerGameState state,
    MultiplayerGameNotifier notifier,
  ) {
    final hasUnclaimed = state.unclaimedCompletedLines.isNotEmpty;
    final nextLine = hasUnclaimed ? state.unclaimedCompletedLines.first : null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: hasUnclaimed ? const Color(0xFFFFFBEB) : AppColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: hasUnclaimed ? AppColors.primaryCoral : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'COMPLETED LINES',
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasUnclaimed ? AppColors.softYellow : AppColors.surfaceContainerHigh,
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: Text(
                      hasUnclaimed
                          ? '${state.unclaimedCompletedLines.length} READY'
                          : '0 AVAILABLE',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: hasUnclaimed ? AppColors.primaryNavy : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "AWARD: '${state.nextAwardLetter}'",
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hasUnclaimed ? AppColors.primaryCoral : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.roundedMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUnclaimed ? nextLine!.name : 'No Ready Lines',
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        hasUnclaimed && nextLine != null
                            ? nextLine.coordinates
                                .map((c) => state.userBoard
                                    .getNumberAt(c.row, c.col)
                                    .toString()
                                    .padLeft(2, '0'))
                                .join(' • ')
                            : 'Match numbers on your board to complete a 5-in-a-row line',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: hasUnclaimed ? 0.8 : 0.0,
                          fontWeight: hasUnclaimed ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasUnclaimed ? AppColors.primaryCoral : AppColors.surfaceContainerHigh,
                    foregroundColor: hasUnclaimed ? Colors.white : AppColors.textMuted,
                    elevation: hasUnclaimed ? 2 : 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.roundedFull,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: (!hasUnclaimed ||
                          state.isClaiming ||
                          state.isMatchOver ||
                          _hasNavigated)
                      ? null
                      : () {
                          notifier.claimLine(nextLine!);
                        },
                  icon: Icon(
                    hasUnclaimed ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('CLAIM LINE'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Number selection and line claiming are separate actions. You can claim a completed line at any time, even when it is not your turn.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalledNumbersRail(
    BuildContext context,
    MultiplayerGameState state,
  ) {
    final called = state.game?.calledNumbers ?? [];

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Called Numbers',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.lightLavender,
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: Text(
                      '${called.length} / 25',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (called.isNotEmpty)
                TextButton(
                  onPressed: () => _showAllCalledModal(context, called),
                  child: Text(
                    'VIEW ALL',
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryCoral,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (called.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No numbers called yet. The host will call the first number.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: called.reversed.map((calledNumber) {
                  return Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.lightLavender,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      calledNumber.toString().padLeft(2, '0'),
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllCalledModal(BuildContext context, List<int> called) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'All Called Numbers (${called.length}/25)',
                style: AppTypography.headlineSm,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: called.map((n) {
                  return Chip(
                    backgroundColor: AppColors.lightLavender,
                    label: Text(
                      n.toString().padLeft(2, '0'),
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Forfeit Match?', style: AppTypography.headlineSm),
        content: Text(
          'Leaving will forfeit this ongoing match and record it as a defeat in your career statistics. Are you sure you want to forfeit and exit?',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isForfeiting = true;
              });
              final notifier = ref.read(
                multiplayerGameProvider(widget.roomId).notifier,
              );
              final room = ref.read(multiplayerGameProvider(widget.roomId)).room;
              final isQuickMatch = room?.isQuickMatch == true;
              if (isQuickMatch) {
                _navigateToResult();
                notifier.forfeitAndExit().catchError((_) => <String, dynamic>{});
              } else {
                _navigateToHomeOnForfeit();
                notifier.forfeitAndExit().catchError((_) => <String, dynamic>{});
              }
            },
            child: const Text('FORFEIT & EXIT'),
          ),
        ],
      ),
    );
  }
}
