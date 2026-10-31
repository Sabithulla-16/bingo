import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';

/// Multiplayer Menu Screen (Stitch Screen ID: `f4d100bf68cf4088a4dc49448549ce41`)
class MultiplayerMenuScreen extends ConsumerWidget {
  const MultiplayerMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Multiplayer', style: AppTypography.headlineSm),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryNavy,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  PlayerAvatar(
                    backgroundColor: Color(
                      int.parse(
                        profile.avatarColorHex.replaceFirst('#', '0xFF'),
                      ),
                    ),
                    displayName: profile.displayName,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile.displayName,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'PRIVATE GAME ROOMS',
                icon: Icons.lock_outline_rounded,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Play With Friends',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Host a private game room or join with a 6-character room code.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),

            // Host / Create Room Option Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCoral.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_home_rounded,
                          color: AppColors.primaryCoral,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Host Private Room',
                              style: AppTypography.headlineSm,
                            ),
                            Text(
                              'Customize players (2–4), prep & turn timers',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Create Private Room',
                    icon: Icons.add_rounded,
                    onPressed: () => context.push(AppRoutes.createRoom),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Join Room Option Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.lightLavender,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          color: AppColors.primaryNavy,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join with Code',
                              style: AppTypography.headlineSm,
                            ),
                            Text(
                              'Enter an invite code from a host friend',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(
                    label: 'Enter Room Code',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push(AppRoutes.joinRoom),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // How Multiplayer Works Info Accordion
            AppCard(
              backgroundColor: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.primaryNavy,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HOW MULTIPLAYER WORKS',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRuleStep(
                    step: '1',
                    text:
                        'Host creates room and shares the unique 6-character room code.',
                  ),
                  const SizedBox(height: 8),
                  _buildRuleStep(
                    step: '2',
                    text:
                        'Up to 4 players join, customize their boards, and click Ready.',
                  ),
                  const SizedBox(height: 8),
                  _buildRuleStep(
                    step: '3',
                    text:
                        'Turn-based number calling with synchronized realtime countdowns.',
                  ),
                  const SizedBox(height: 8),
                  _buildRuleStep(
                    step: '4',
                    text:
                        'First player to achieve 5 lines shouts BINGO to claim victory!',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleStep({required String step, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.primaryNavy,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textLight,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTypography.bodySm.copyWith(fontSize: 12)),
        ),
      ],
    );
  }
}
