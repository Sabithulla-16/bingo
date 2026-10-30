import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Multiplayer Menu (Stitch Screen ID: `f4d100bf68cf4088a4dc49448549ce41`)
class MultiplayerMenuScreen extends StatelessWidget {
  const MultiplayerMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Multiplayer', style: AppTypography.headlineSm),
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
              'Play with friends',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Create a private 2–4 player room or enter an invite code to join.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 28),

            // Create Room Option Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCoral.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_home_rounded,
                          color: AppColors.primaryCoral,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Host a Game', style: AppTypography.headlineSm),
                          Text(
                            'Configure capacity & timers',
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Create Room',
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightLavender,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join with Code',
                            style: AppTypography.headlineSm,
                          ),
                          Text(
                            'Enter 6-digit room code',
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(
                    label: 'Join Room',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push(AppRoutes.joinRoom),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
