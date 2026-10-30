import 'package:flutter/material.dart';
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

/// Single Player Game Result (Stitch Screen ID: `979d94b99a954acab4e6135aa5f5b520`)
class SinglePlayerResultScreen extends StatelessWidget {
  final String gameId;

  const SinglePlayerResultScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BingoLogo(fontSize: 32)),
            const SizedBox(height: 20),
            const Center(
              child: StatusBadge(
                label: 'MATCH COMPLETED',
                backgroundColor: Color(0xFFDCFCE7),
                textColor: AppColors.readyGreen,
                icon: Icons.emoji_events_rounded,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'VICTORY!',
              textAlign: TextAlign.center,
              style: AppTypography.displayHeroMobile.copyWith(
                color: AppColors.primaryCoral,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You successfully completed all 5 BINGO lines!',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),
            const BingoProgressLetters(claimedCount: 5),
            const SizedBox(height: 28),

            // Match Stats Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatRow('TOTAL CALLS', '18 Balls'),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('LINES CLAIMED', '5 Lines (B-I-N-G-O)'),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('COMPUTER PROGRESS', '3 Lines (B-I-N)'),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildStatRow('MATCH DURATION', '3m 14s'),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Play Again',
              icon: Icons.replay_rounded,
              onPressed: () {
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
          style: AppTypography.labelMd.copyWith(color: AppColors.primaryNavy),
        ),
      ],
    );
  }
}
