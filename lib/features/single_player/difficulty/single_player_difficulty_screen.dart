import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';

enum Difficulty { easy, medium, hard }

/// Single Player Difficulty Selection (Stitch Screen ID: `f8a803af8b374c2eb8b32f5d8716186d`)
class SinglePlayerDifficultyScreen extends StatefulWidget {
  const SinglePlayerDifficultyScreen({super.key});

  @override
  State<SinglePlayerDifficultyScreen> createState() =>
      _SinglePlayerDifficultyScreenState();
}

class _SinglePlayerDifficultyScreenState
    extends State<SinglePlayerDifficultyScreen> {
  Difficulty _selectedDifficulty = Difficulty.medium;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Select Difficulty', style: AppTypography.headlineSm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'AI OPPONENT SETTINGS',
                icon: Icons.psychology_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose your challenge',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 6),
            Text(
              'The computer plays on its own private board following the exact same rules.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),
            _buildDifficultyCard(
              difficulty: Difficulty.easy,
              title: 'Easy',
              subtitle: 'Random number selection. Great for casual practice.',
              badgeColor: AppColors.readyGreen,
            ),
            const SizedBox(height: 12),
            _buildDifficultyCard(
              difficulty: Difficulty.medium,
              title: 'Medium',
              subtitle:
                  'Balanced play. Periodically targets near-complete lines.',
              badgeColor: AppColors.softYellowDark,
            ),
            const SizedBox(height: 12),
            _buildDifficultyCard(
              difficulty: Difficulty.hard,
              title: 'Hard',
              subtitle:
                  'Strategic heuristic AI. Prioritizes high-density line intersections.',
              badgeColor: AppColors.primaryCoral,
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Continue to Board Prep',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                context.push(AppRoutes.singlePlayerBoardPrep);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCard({
    required Difficulty difficulty,
    required String title,
    required String subtitle,
    required Color badgeColor,
  }) {
    final isSelected = _selectedDifficulty == difficulty;

    return AppCard(
      onTap: () => setState(() => _selectedDifficulty = difficulty),
      backgroundColor: isSelected
          ? AppColors.lightLavender.withAlpha(100)
          : AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isSelected ? AppColors.primaryCoral : AppColors.textMuted,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: isSelected
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryCoral,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTypography.headlineSm),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: badgeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTypography.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
