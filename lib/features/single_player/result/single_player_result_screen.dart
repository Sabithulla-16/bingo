import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_logo.dart';
import '../../../core/widgets/bingo_progress_letters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../presentation/single_player_game_notifier.dart';

/// Single Player Game Result Screen (Stitch Screen ID: `979d94b99a954acab4e6135aa5f5b520`)
class SinglePlayerResultScreen extends ConsumerWidget {
  final String gameId;

  const SinglePlayerResultScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(singlePlayerGameProvider);

    final isVictory = gameState?.winner == GameWinner.player;
    final isDraw = gameState?.winner == GameWinner.draw;

    final playerLines = gameState?.playerEngine.claimedLinesCount ?? 5;
    final botLines = gameState?.computerEngine.claimedLinesCount ?? 3;
    final totalCalls = gameState?.calledNumbers.length ?? 18;
    final difficulty = gameState?.difficulty.name.toUpperCase() ?? 'MEDIUM';

    final durationSec = gameState?.matchDuration.inSeconds ?? 105;
    final durationFormatted =
        '${durationSec ~/ 60}m ${(durationSec % 60).toString().padLeft(2, '0')}s';

    Color bannerColor;
    String statusTitle;
    String heroTitle;
    String subtitle;
    IconData statusIcon;

    if (isVictory) {
      bannerColor = AppColors.readyGreen;
      statusTitle = 'MATCH VICTORY';
      heroTitle = 'VICTORY!';
      subtitle = 'You successfully claimed 5 lines and achieved BINGO!';
      statusIcon = Icons.emoji_events_rounded;
    } else if (isDraw) {
      bannerColor = AppColors.softYellowDark;
      statusTitle = 'MATCH DRAW';
      heroTitle = 'DRAW';
      subtitle = 'All 25 numbers called without a 5-line BINGO winner.';
      statusIcon = Icons.handshake_rounded;
    } else {
      bannerColor = AppColors.primaryNavy;
      statusTitle = 'MATCH COMPLETED';
      heroTitle = 'DEFEAT';
      subtitle = 'The computer claimed 5 winning lines first.';
      statusIcon = Icons.flag_rounded;
    }

    return ResponsiveScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BingoLogo(fontSize: 32)),
            const SizedBox(height: 20),

            Center(
              child: StatusBadge(
                label: statusTitle,
                backgroundColor: bannerColor.withAlpha(25),
                textColor: bannerColor,
                icon: statusIcon,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              heroTitle,
              textAlign: TextAlign.center,
              style: AppTypography.displayHeroMobile.copyWith(
                color: isVictory ? AppColors.primaryCoral : AppColors.primaryNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),

            // Letter Progress B-I-N-G-O
            BingoProgressLetters(claimedCount: playerLines),

            const SizedBox(height: 28),

            // Match Statistics Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatRow('TOTAL CALLS', '$totalCalls Balls'),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('YOUR LINES', '$playerLines Lines'),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('BOT LINES', '$botLines Lines'),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('DIFFICULTY', difficulty),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('MATCH DURATION', durationFormatted),
                ],
              ),
            ),

            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Play Again',
              icon: Icons.replay_rounded,
              onPressed: () {
                ref.read(singlePlayerGameProvider.notifier).rematch();
                context.pushReplacement(AppRoutes.singlePlayerBoardPrep);
              },
            ),
            const SizedBox(height: 12),

            SecondaryButton(
              label: 'Return to Home',
              icon: Icons.home_rounded,
              onPressed: () {
                context.go(AppRoutes.home);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.labelSm),
        Text(
          value,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
