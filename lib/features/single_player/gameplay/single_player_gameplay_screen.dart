import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/game_engine/bingo_engine.dart';
import '../../../core/game_engine/winning_line.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../presentation/single_player_game_notifier.dart';

/// Single Player Gameplay Screen (Stitch Screen ID: `c35c79a49c804f4aad87a3ae72090e66`)
class SinglePlayerGameplayScreen extends ConsumerStatefulWidget {
  final String gameId;

  const SinglePlayerGameplayScreen({super.key, required this.gameId});

  @override
  ConsumerState<SinglePlayerGameplayScreen> createState() =>
      _SinglePlayerGameplayScreenState();
}

class _SinglePlayerGameplayScreenState
    extends ConsumerState<SinglePlayerGameplayScreen> {
  void _openHistoryModal(List<int> calledNumbers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final sorted = List<int>.from(calledNumbers)..sort();
        return Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Called Numbers',
                        style: AppTypography.headlineSm,
                      ),
                      Text(
                        '${calledNumbers.length} of 25 numbers selected this match',
                        style: AppTypography.bodySm,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No numbers called yet.')),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sorted.map((cellNum) {
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.lightLavender,
                        borderRadius: AppRadii.roundedMd,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cellNum.toString().padLeft(2, '0'),
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Back to Match',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Leave Match?',
        message:
            'Leaving will forfeit this practice round against the computer.',
        confirmLabel: 'Leave Match',
        cancelLabel: 'Resume',
        isDestructive: true,
        onConfirm: () {
          Navigator.of(ctx).pop();
          context.go(AppRoutes.home);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SinglePlayerMatchState?>(singlePlayerGameProvider, (prev, next) {
      if (next == null) return;

      // 1. Critical BINGO Victory Trigger: Play upgraded BINGO victory sound whenever
      // ANY participant (human player, bot, or simultaneous draw) completes all 5 lines.
      final wasCompleted = prev != null && prev.winner != GameWinner.none;
      final isCompleted = next.winner != GameWinner.none;
      final anyReachedBingo =
          next.playerClaimedLineIds.length >= 5 ||
          next.computerClaimedLineIds.length >= 5;
      final prevAnyReachedBingo =
          prev != null &&
          (prev.playerClaimedLineIds.length >= 5 ||
              prev.computerClaimedLineIds.length >= 5);

      if ((isCompleted && !wasCompleted) ||
          (anyReachedBingo && !prevAnyReachedBingo)) {
        ref.read(feedbackServiceProvider).victoryBingo();
      }

      // 2. Line Strike Sound: Whenever player or bot successfully claims a winning line
      final prevPlayerLines = prev?.playerClaimedLineIds.length ?? 0;
      final nextPlayerLines = next.playerClaimedLineIds.length;
      final prevBotLines = prev?.computerClaimedLineIds.length ?? 0;
      final nextBotLines = next.computerClaimedLineIds.length;

      if (nextPlayerLines > prevPlayerLines || nextBotLines > prevBotLines) {
        // If not a full 5-line victory, play the line strike sound
        if (!isCompleted && !anyReachedBingo) {
          ref.read(feedbackServiceProvider).claimLine();
        }
      }

      // 3. Number Call Sound: Whenever a new number is successfully called (human or bot turn)
      final prevCalls = prev?.calledNumbers.length ?? 0;
      final nextCalls = next.calledNumbers.length;
      if (nextCalls > prevCalls) {
        ref.read(feedbackServiceProvider).callNumber();
      }
    });

    final gameState = ref.watch(singlePlayerGameProvider);

    // If state is not initialized (e.g. direct deep link), fallback gracefully
    if (gameState == null) {
      return ResponsiveScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Match not found', style: AppTypography.headlineMd),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Start New Match',
                onPressed: () => context.go(AppRoutes.singlePlayerDifficulty),
              ),
            ],
          ),
        ),
      );
    }

    final playerEngine = gameState.playerEngine;
    final botEngine = gameState.computerEngine;
    final unclaimedLines = playerEngine.unclaimedCompletedLines;
    final calledNumbers = gameState.calledNumbers;

    // Check if match ended
    final hasWinner = gameState.winner != GameWinner.none;

    return ResponsiveScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Navigation & Difficulty Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Wordmark with brand accent dots
                Row(
                  children: [
                    Text('BINGO', style: AppTypography.headlineSm),
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryCoral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.softYellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.lightLavender,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Center Match Difficulty Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softYellow.withAlpha(40),
                    borderRadius: AppRadii.roundedFull,
                    border: Border.all(
                      color: AppColors.softYellowDark.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.softYellowDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        gameState.difficulty.name.toUpperCase(),
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.softYellowDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Exit / Pause Button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: _confirmExit,
                  tooltip: 'Exit match',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Head-to-Head Card (You vs Bot)
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // YOU
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryCoral,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Y',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOU', style: AppTypography.labelMd),
                                Text(
                                  '${playerEngine.claimedLinesCount} Lines',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildLetterTrack(playerEngine.claimedLetters),
                      ],
                    ),
                  ),

                  // VS Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: Text('VS', style: AppTypography.labelSm),
                  ),

                  // BOT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('BOT', style: AppTypography.labelMd),
                                Text(
                                  '${botEngine.claimedLinesCount} Lines',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryNavy,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.smart_toy_rounded,
                                size: 16,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildLetterTrack(botEngine.claimedLetters),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Bot Line Claim Toast / Alert
            if (gameState.botActionToast != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightLavender,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(
                    color: AppColors.primaryNavy.withAlpha(50),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: AppColors.primaryCoral,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gameState.botActionToast!,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Turn Indicator Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: gameState.isPlayerTurn
                    ? AppColors.primaryNavy
                    : AppColors.surfaceContainerHigh,
                borderRadius: AppRadii.roundedLg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: gameState.isPlayerTurn
                          ? AppColors.primaryCoral
                          : AppColors.softYellowDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gameState.isPlayerTurn
                        ? 'YOUR TURN'
                        : 'COMPUTER THINKING...',
                    style: AppTypography.labelMd.copyWith(
                      color: gameState.isPlayerTurn
                          ? AppColors.textLight
                          : AppColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      gameState.isPlayerTurn
                          ? 'Tap any uncalled number'
                          : 'Evaluating optimal line...',
                      style: AppTypography.bodySm.copyWith(
                        color: gameState.isPlayerTurn
                            ? AppColors.textLight.withAlpha(200)
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Line Ready to Claim Alert (shown above board if unclaimed lines exist)
            if (unclaimedLines.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softYellow,
                  borderRadius: AppRadii.roundedFull,
                ),
                alignment: Alignment.center,
                child: Text(
                  '✦ ${unclaimedLines.first.name.toUpperCase()} READY TO CLAIM ✦',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

            // 5x5 Central Bingo Board
            BingoBoardGrid(
              matrix: gameState.playerBoard.numbers,
              calledNumbers: calledNumbers.toSet(),
              claimedNumbers: _getClaimedNumbers(playerEngine),
              completedUnclaimedNumbers: _getUnclaimedNumbers(playerEngine),
              onNumberTapped: (number) {
                if (gameState.isPlayerTurn &&
                    !gameState.isComputerThinking &&
                    !gameState.isNumberCalled(number) &&
                    !hasWinner) {
                  ref
                      .read(singlePlayerGameProvider.notifier)
                      .callNumber(number);
                } else {
                  ref.read(feedbackServiceProvider).lightTap();
                }
              },
            ),

            const SizedBox(height: 12),

            // Line Claiming Action Panel
            if (unclaimedLines.isNotEmpty) ...[
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                size: 16,
                                color: AppColors.primaryCoral,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'COMPLETED LINES (${unclaimedLines.length} READY)',
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.primaryNavy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCoral.withAlpha(25),
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Text(
                            'NEXT: ${BingoEngine.lettersSequence[playerEngine.claimedLinesCount < 5 ? playerEngine.claimedLinesCount : 4]}',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primaryCoral,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...unclaimedLines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.name, style: AppTypography.labelMd),
                                  Text(
                                    line.coordinates
                                        .map(
                                          (c) => gameState.playerBoard
                                              .getNumberAt(c.row, c.col)
                                              .toString()
                                              .padLeft(2, '0'),
                                        )
                                        .join(' · '),
                                    style: AppTypography.bodySm.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref
                                    .read(singlePlayerGameProvider.notifier)
                                    .claimLine(line.id);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryCoral,
                                foregroundColor: AppColors.textLight,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(Icons.verified, size: 14),
                              label: const Text('CLAIM ✦'),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (unclaimedLines.length > 1) ...[
                      const SizedBox(height: 6),
                      PrimaryButton(
                        label: 'Claim All Lines (${unclaimedLines.length})',
                        onPressed: () {
                          ref
                              .read(singlePlayerGameProvider.notifier)
                              .claimAllLines();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Called Numbers Horizontal Stream
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'CALLED NUMBERS',
                                style: AppTypography.labelMd,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: AppRadii.roundedFull,
                              ),
                              child: Text(
                                '${calledNumbers.length} / 25',
                                style: AppTypography.labelSm,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openHistoryModal(calledNumbers),
                        icon: const Icon(Icons.list, size: 16),
                        label: Text('VIEW ALL', style: AppTypography.labelSm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (calledNumbers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No numbers called yet. Tap a number above to begin!',
                      ),
                    )
                  else
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: calledNumbers.length,
                        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          // Most recent is at the front
                          final reversedIndex = calledNumbers.length - 1 - i;
                          final num = calledNumbers[reversedIndex];
                          final isLatest = i == 0;

                          return Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isLatest
                                  ? AppColors.primaryNavy
                                  : AppColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                              boxShadow: isLatest
                                  ? const [
                                      BoxShadow(
                                        color: AppColors.cardShadowColor,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              num.toString().padLeft(2, '0'),
                              style: AppTypography.labelMd.copyWith(
                                color: isLatest
                                    ? AppColors.textLight
                                    : AppColors.primaryNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Game Completed Banner / Outcome CTA
            if (hasWinner) ...[
              const SizedBox(height: 14),
              PrimaryButton(
                label: gameState.winner == GameWinner.player
                    ? 'BINGO! View Results'
                    : gameState.winner == GameWinner.computer
                    ? 'Bot Won! View Results'
                    : 'Match Draw! View Results',
                icon: Icons.emoji_events_rounded,
                onPressed: () {
                  context.push(
                    AppRoutes.singlePlayerResultPath(gameState.gameId),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLetterTrack(List<String> claimedLetters) {
    const letters = ['B', 'I', 'N', 'G', 'O'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: letters.map((letter) {
        final isClaimed = claimedLetters.contains(letter);
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: isClaimed
                ? AppColors.primaryCoral
                : AppColors.surfaceContainerHigh,
            borderRadius: AppRadii.roundedSm,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: AppTypography.labelSm.copyWith(
              color: isClaimed ? AppColors.textLight : AppColors.textTertiary,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }).toList(),
    );
  }

  Set<int> _getClaimedNumbers(BingoEngine engine) {
    final claimed = <int>{};
    for (final lineId in engine.claimedLineIds) {
      final line = WinningLine.allLines.firstWhere((l) => l.id == lineId);
      for (final c in line.coordinates) {
        claimed.add(engine.board.getNumberAt(c.row, c.col));
      }
    }
    return claimed;
  }

  Set<int> _getUnclaimedNumbers(BingoEngine engine) {
    final unclaimed = <int>{};
    for (final line in engine.unclaimedCompletedLines) {
      for (final c in line.coordinates) {
        unclaimed.add(engine.board.getNumberAt(c.row, c.col));
      }
    }
    return unclaimed;
  }
}
