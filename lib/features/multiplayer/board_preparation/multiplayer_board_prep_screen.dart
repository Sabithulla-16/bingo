import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/game_engine/board_coordinate.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../domain/multiplayer_game.dart';
import '../presentation/multiplayer_board_prep_notifier.dart';

/// Multiplayer Board Preparation Screen (Stitch Screen 12: `e8593d7a83924868a0b75fad83f69012`)
class MultiplayerBoardPrepScreen extends ConsumerStatefulWidget {
  final String roomId;

  const MultiplayerBoardPrepScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<MultiplayerBoardPrepScreen> createState() =>
      _MultiplayerBoardPrepScreenState();
}

class _MultiplayerBoardPrepScreenState
    extends ConsumerState<MultiplayerBoardPrepScreen> {
  Color _getTimerColor(int seconds) {
    if (seconds <= 0) return AppColors.surfaceContainerHigh;
    if (seconds < 10) return const Color(0xFFEF4444); // Urgent Red
    if (seconds <= 15) return const Color(0xFFF59E0B); // Amber Warning
    return AppColors.primaryCoral;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerBoardPrepProvider(widget.roomId));
    final notifier =
        ref.read(multiplayerBoardPrepProvider(widget.roomId).notifier);

    // Auto-navigate to game when server transitions match to in_progress
    ref.listen<MultiplayerBoardPrepState>(
      multiplayerBoardPrepProvider(widget.roomId),
      (prev, next) {
        if (next.game?.status == MultiplayerGameStatus.inProgress) {
          context.go(AppRoutes.multiplayerGamePath(widget.roomId));
        }
      },
    );

    final timerColor = _getTimerColor(state.remainingSeconds);
    final roomName = state.room?.name ?? 'Bingo Room';
    final roomCode = state.room?.code ?? '......';

    return ResponsiveScaffold(
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCoral),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Header Bar
                      _buildTopHeader(context, roomCode),
                      const SizedBox(height: 16),

                      // Room Context Title & Badges
                      _buildRoomContext(roomName, roomCode),
                      const SizedBox(height: 16),

                      // Synchronized Server Countdown Timer Card
                      _buildSynchronizedTimerCard(state, timerColor),
                      const SizedBox(height: 16),

                      // Player Readiness Strip
                      _buildPlayerReadinessSection(state),
                      const SizedBox(height: 16),

                      // Board Action Bar (Tap to swap info & Shuffle Board)
                      _buildBoardActionBar(state, notifier),
                      const SizedBox(height: 10),

                      // Active Swap Tip Banner (when cell selected)
                      if (state.selectedCoordinate != null) ...[
                        _buildSwapTipBanner(state, notifier),
                        const SizedBox(height: 10),
                      ],

                      // 5x5 Central Bingo Matrix with Lock Overlay
                      _buildInteractiveBoard(state, notifier),
                      const SizedBox(height: 12),

                      // Numbers placed confirmation pill
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.readyGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '25 / 25 NUMBERS PLACED',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Button: Confirm Board
                      _buildConfirmButton(state, notifier),
                      const SizedBox(height: 8),

                      Center(
                        child: Text(
                          state.isConfirmed
                              ? 'Your board layout is locked. Waiting for other players...'
                              : 'Your board will be locked after confirmation.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Leave Room
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _confirmLeaveRoom(context),
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: AppColors.primaryCoral,
                          ),
                          label: Text(
                            'Leave room',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primaryCoral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Host Time Is Up Modal
                if (state.isExpiredModalOpen && state.isHost)
                  _buildExpiredHostModal(state, notifier),
              ],
            ),
    );
  }

  Widget _buildTopHeader(BuildContext context, String roomCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryNavy),
          onPressed: () => _confirmLeaveRoom(context),
        ),
        Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BINGO',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                    letterSpacing: -0.5,
                  ),
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
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.softYellow,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Text(
              'BOARD PREPARATION',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppRadii.roundedFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 14, color: AppColors.primaryNavy),
              const SizedBox(width: 4),
              Text('Private', style: AppTypography.labelSm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoomContext(String roomName, String roomCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                roomName.toUpperCase(),
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag_rounded, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'ROOM: $roomCode',
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Arrange your board',
          style: AppTypography.headlineMd.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Choose where your numbers go before the match begins.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSynchronizedTimerCard(
    MultiplayerBoardPrepState state,
    Color timerColor,
  ) {
    final mins = state.remainingSeconds ~/ 60;
    final secs = state.remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TIME REMAINING',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: AppRadii.roundedFull,
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SYNCED',
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFF065F46),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: AppTypography.displayHero.copyWith(
                        color: timerColor,
                        fontSize: 38,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.remainingSeconds > 0
                          ? 'Everyone is preparing their boards'
                          : 'Preparation window expired',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Radial Circular Ring with Center Icon
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: state.progressFraction,
                      strokeWidth: 4.5,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                    ),
                    Icon(
                      state.remainingSeconds < 10
                          ? Icons.warning_rounded
                          : Icons.hourglass_top_rounded,
                      size: 20,
                      color: timerColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal Progress Bar
          ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: LinearProgressIndicator(
              value: state.progressFraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerReadinessSection(MultiplayerBoardPrepState state) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'PLAYER READINESS',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primaryNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  '${state.players.length} PLAYERS (${state.readyCount} READY)',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cards Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.players.map((player) {
                final isYou = player.userId == state.currentUserState?.userId;
                return Container(
                  width: 92,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadii.roundedMd,
                    border: isYou
                        ? Border.all(color: AppColors.primaryCoral, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      PlayerAvatar(
                        displayName: player.displayName,
                        size: 36,
                        backgroundColor: Color(
                          int.parse(
                            player.avatarColorHex.replaceFirst('#', '0xFF'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isYou ? 'You' : player.displayName,
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: player.isBoardConfirmed
                              ? const Color(0xFFECFDF5)
                              : AppColors.surfaceContainerHigh,
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                player.isBoardConfirmed
                                    ? Icons.check_circle_rounded
                                    : Icons.circle,
                                size: 10,
                                color: player.isBoardConfirmed
                                    ? AppColors.readyGreen
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                player.isBoardConfirmed ? 'READY' : 'PREP',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: player.isBoardConfirmed
                                      ? AppColors.readyGreen
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_off_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Your board is private. Other players can only see your readiness.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardActionBar(
    MultiplayerBoardPrepState state,
    MultiplayerBoardPrepNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.lightLavender,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz_rounded,
                    size: 16, color: AppColors.primaryNavy),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Tap two to swap',
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: TextButton.icon(
            onPressed: state.isConfirmed ? null : notifier.quickShuffle,
            icon: const Icon(Icons.casino_rounded, size: 16, color: AppColors.primaryNavy),
            label: Text(
              'SHUFFLE BOARD',
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwapTipBanner(
    MultiplayerBoardPrepState state,
    MultiplayerBoardPrepNotifier notifier,
  ) {
    final coord = state.selectedCoordinate!;
    final val = state.board.getNumberAtCoord(coord).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFFDAD6),
        borderRadius: AppRadii.roundedSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.info_rounded, size: 16, color: Color(0xFF690005)),
              const SizedBox(width: 8),
              Text(
                'Tile $val selected. Tap another tile to swap.',
                style: AppTypography.bodySm.copyWith(
                  color: const Color(0xFF690005),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close_rounded,
                size: 16, color: Color(0xFF690005)),
            onPressed: notifier.cancelSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveBoard(
    MultiplayerBoardPrepState state,
    MultiplayerBoardPrepNotifier notifier,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          // 5x5 Grid
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
              final number = state.board.getNumberAtCoord(coord);
              final isSelected = state.selectedCoordinate == coord;

              return InkWell(
                onTap: state.isConfirmed ? null : () => notifier.onCellTapped(coord),
                borderRadius: AppRadii.roundedMd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: isSelected
                      ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                      : Matrix4.identity(),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFDAD6)
                        : AppColors.surface,
                    borderRadius: AppRadii.roundedMd,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryCoral
                          : AppColors.surfaceContainerHigh,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryCoral.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.primaryCoral
                            : AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Locked Overlay when confirmed
          if (state.isConfirmed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: AppRadii.roundedLg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryCoral,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BOARD CONFIRMED!',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Waiting for other players to finish preparing...',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(
    MultiplayerBoardPrepState state,
    MultiplayerBoardPrepNotifier notifier,
  ) {
    if (state.isConfirmed) {
      return Container(
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: AppRadii.roundedLg,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(
              'BOARD LOCKED & CONFIRMED',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return PrimaryButton(
      label: 'CONFIRM BOARD',
      onPressed: notifier.confirmBoard,
      icon: Icons.check_rounded,
    );
  }

  Widget _buildExpiredHostModal(
    MultiplayerBoardPrepState state,
    MultiplayerBoardPrepNotifier notifier,
  ) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDAD6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_off_rounded,
                size: 28,
                color: Color(0xFFBA1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TIME IS UP',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Some players have not confirmed their boards. Choose how to proceed:',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'EXTEND TIMER (+30s)',
              onPressed: () => notifier.extendTimer(seconds: 30),
              icon: Icons.more_time_rounded,
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'DISMISS',
              onPressed: notifier.dismissExpiredModal,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave Room?', style: AppTypography.headlineSm),
        content: Text(
          'Are you sure you want to exit? Your seat in this match will be forfeited.',
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
              context.go(AppRoutes.home);
            },
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
  }
}
