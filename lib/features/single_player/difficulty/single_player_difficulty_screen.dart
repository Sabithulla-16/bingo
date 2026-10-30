import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/game_engine/ai_decision_engine.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../presentation/single_player_game_notifier.dart';

/// Single Player Difficulty Selection (Stitch Screen ID: `f8a803af8b374c2eb8b32f5d8716186d`)
class SinglePlayerDifficultyScreen extends ConsumerWidget {
  const SinglePlayerDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDifficulty = ref.watch(selectedDifficultyProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Select Difficulty', style: AppTypography.headlineSm),
        centerTitle: true,
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
              context: context,
              ref: ref,
              difficulty: AiDifficulty.easy,
              title: 'Easy',
              subtitle: 'Random number selection. Great for casual practice and learning mechanics.',
              badgeColor: AppColors.readyGreen,
              isSelected: selectedDifficulty == AiDifficulty.easy,
            ),
            const SizedBox(height: 14),

            _buildDifficultyCard(
              context: context,
              ref: ref,
              difficulty: AiDifficulty.medium,
              title: 'Medium',
              subtitle: 'Balanced play. Periodically targets near-complete lines with 3–4 marked numbers.',
              badgeColor: AppColors.softYellowDark,
              isSelected: selectedDifficulty == AiDifficulty.medium,
            ),
            const SizedBox(height: 14),

            _buildDifficultyCard(
              context: context,
              ref: ref,
              difficulty: AiDifficulty.hard,
              title: 'Hard',
              subtitle: 'Strategic heuristic AI. Evaluates intersection density and targets optimal lines.',
              badgeColor: AppColors.primaryCoral,
              isSelected: selectedDifficulty == AiDifficulty.hard,
            ),

            const SizedBox(height: 20),

            // AI Opponent Preview Card
            AppCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: AppColors.textLight,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BINGO BOT', style: AppTypography.labelMd),
                        Text(
                          'Plays with zero access to your board, strictly relying on fair public call history.',
                          style: AppTypography.bodySm.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
    required BuildContext context,
    required WidgetRef ref,
    required AiDifficulty difficulty,
    required String title,
    required String subtitle,
    required Color badgeColor,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(selectedDifficultyProvider.notifier).state = difficulty;
      },
      borderRadius: AppRadii.roundedXl,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        backgroundColor: isSelected
            ? AppColors.surface
            : AppColors.surfaceContainerLow,
        border: Border.all(
          color: isSelected ? AppColors.primaryNavy : AppColors.structuralBorder,
          width: isSelected ? 2.0 : 1.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryNavy : AppColors.textTertiary,
                  width: 2,
                ),
                color: isSelected ? AppColors.primaryNavy : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.surface,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(25),
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: Text(
                          title.toUpperCase(),
                          style: AppTypography.labelSm.copyWith(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
      ),
    );
  }
}
