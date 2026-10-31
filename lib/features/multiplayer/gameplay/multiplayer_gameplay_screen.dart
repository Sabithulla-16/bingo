import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/game_engine/board_coordinate.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_cell.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../domain/multiplayer_game.dart';
import '../presentation/multiplayer_game_notifier.dart';

/// Multiplayer Gameplay Screen (Stitch Screen 13: `99e26fda63c3428a82b9702145ca87f5`)
class MultiplayerGameplayScreen extends ConsumerWidget {
  final String roomId;

  const MultiplayerGameplayScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multiplayerGameProvider(roomId));
    final notifier = ref.read(multiplayerGameProvider(roomId).notifier);

    // Auto-navigate to result screen upon match conclusion and trigger audio feedback
    ref.listen<MultiplayerGameState>(multiplayerGameProvider(roomId), (
      prev,
      next,
    ) {
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

      if (isCompleted && !wasCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.hasWon
                  ? 'BINGO! VICTORY ACHIEVED!'
                  : 'Match Ended! Check Final Leaderboard.',
              style: AppTypography.labelLg.copyWith(color: Colors.white),
            ),
            backgroundColor: next.hasWon
                ? AppColors.primaryCoral
                : AppColors.primaryNavy,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    final roomName = state.room?.name ?? 'Bingo Room';
    final roomCode = state.room?.code ?? '......';
    final currentTurnUserId = state.game?.currentTurnUserId;
    final currentTurnPlayer = state.players
        .where((p) => p.userId == currentTurnUserId)
        .firstOrNull;

    return ResponsiveScaffold(
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

                  // Toast Notification Banner (Live opponent action event)
                  if (state.toastNotification != null) ...[
                    _buildToastBanner(state.toastNotification!),
                    const SizedBox(height: 10),
                  ],

                  // Match Status Strip
                  _buildMatchStatusStrip(roomName, state),
                  const SizedBox(height: 12),

                  // Multiplayer Presence Rail (Horizontal compact player cards)
                  _buildPresenceRail(state),
                  const SizedBox(height: 14),

                  // Turn Indicator Banner
                  _buildTurnBanner(state, currentTurnPlayer),
                  const SizedBox(height: 14),

                  // Private 5x5 Bingo Board (Center Stage)
                  _buildPrivateBoard(context, ref, state, notifier),
                  const SizedBox(height: 14),

                  // Line Claiming Interface (Shown when one or more lines are completed)
                  if (state.unclaimedCompletedLines.isNotEmpty) ...[
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
                  context.push(AppRoutes.roomStatisticsPath(roomId)),
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

  Widget _buildPresenceRail(MultiplayerGameState state) {
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

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.players.map((player) {
              final isYou = player.userId == state.currentUserId;
              final letters = ['B', 'I', 'N', 'G', 'O'];

              return Container(
                width: 104,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedMd,
                  border: isYou
                      ? Border.all(color: AppColors.primaryCoral, width: 1.5)
                      : null,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
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
                        PlayerAvatar(
                          displayName: player.displayName,
                          size: 24,
                          backgroundColor: Color(
                            int.parse(
                              player.avatarColorHex.replaceFirst('#', '0xFF'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isYou ? 'You' : player.displayName,
                                style: AppTypography.labelSm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                player.isHost ? 'HOST' : 'GUEST',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: player.isHost
                                      ? AppColors.primaryCoral
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lines',
                          style: AppTypography.labelSm.copyWith(fontSize: 10),
                        ),
                        Text(
                          '${player.linesClaimed}/5',
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: player.linesClaimed > 0
                                ? AppColors.primaryCoral
                                : AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Mini BINGO Progress Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (idx) {
                        final isEarned = player.linesClaimed > idx;
                        return Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: isEarned
                                ? AppColors.primaryCoral
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            letters[idx],
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isEarned
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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
  ) {
    return AppCard(
      padding: const EdgeInsets.all(12),
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
                  state.isMyTurn && cellState == BingoCellState.available;

              return BingoCell(
                number: number,
                state: cellState,
                isInteractive: canCall,
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
    final nextLine = state.unclaimedCompletedLines.first;

    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: const Color(0xFFFFFBEB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryCoral,
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
                    decoration: const BoxDecoration(
                      color: AppColors.softYellow,
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: Text(
                      '${state.unclaimedCompletedLines.length} READY',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "AWARD: '${state.nextAwardLetter}'",
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryCoral,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextLine.name,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      'Completed line ready for BINGO claim',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCoral,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.roundedFull,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: state.isClaiming
                      ? null
                      : () {
                          notifier.claimLine(nextLine);
                        },
                  icon: const Icon(Icons.check_rounded, size: 16),
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
        title: Text('Exit Match?', style: AppTypography.headlineSm),
        content: Text(
          'Leaving will forfeit your ongoing match. You will be able to rejoin if the game is still active.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('STAY'),
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
            child: const Text('FORFEIT & EXIT'),
          ),
        ],
      ),
    );
  }
}
