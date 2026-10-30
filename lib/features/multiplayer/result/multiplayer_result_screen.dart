import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_logo.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Multiplayer Match Result & Leaderboard (Stitch Screen ID: `d92bc16a2a7b4b6393c8e8f0c9b871af`)
class MultiplayerResultScreen extends StatelessWidget {
  final String roomId;

  const MultiplayerResultScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BingoLogo(fontSize: 32)),
            const SizedBox(height: 16),
            const Center(
              child: StatusBadge(
                label: 'MATCH CONCLUDED',
                backgroundColor: Color(0xFFDCFCE7),
                textColor: AppColors.readyGreen,
                icon: Icons.emoji_events_rounded,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ROOM LEADERBOARD',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 20),

            // Podium Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRankRow(
                    rank: '1ST',
                    name: 'Valtry (You)',
                    lines: '5 Lines (BINGO!)',
                    isWinner: true,
                  ),
                  const Divider(color: AppColors.structuralBorder, height: 16),
                  _buildRankRow(
                    rank: '2ND',
                    name: 'Aria',
                    lines: '4 Lines (B-I-N-G)',
                    isWinner: false,
                  ),
                  const Divider(color: AppColors.structuralBorder, height: 16),
                  _buildRankRow(
                    rank: '3RD',
                    name: 'Dante',
                    lines: '2 Lines (B-I)',
                    isWinner: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Vote Rematch',
              icon: Icons.replay_rounded,
              onPressed: () {
                context.pushReplacement(AppRoutes.roomBoardPrepPath(roomId));
              },
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'View Detailed Room Stats',
              icon: Icons.analytics_outlined,
              onPressed: () {
                context.push(AppRoutes.roomStatisticsPath(roomId));
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(
                'Leave Room',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankRow({
    required String rank,
    required String name,
    required String lines,
    required bool isWinner,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isWinner
                ? AppColors.softYellow
                : AppColors.surfaceContainerLow,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            rank,
            style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        PlayerAvatar(displayName: name, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTypography.labelMd),
              Text(lines, style: AppTypography.bodySm),
            ],
          ),
        ),
        if (isWinner)
          const Icon(
            Icons.star_rounded,
            color: AppColors.primaryCoral,
            size: 24,
          ),
      ],
    );
  }
}
