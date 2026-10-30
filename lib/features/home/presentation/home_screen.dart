import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_state.dart';

/// Home Screen (Stitch Screen ID: `587a408834c84cee91acba026d408bad`)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final playerName = authState is Authenticated
        ? authState.profile.displayName
        : 'Player';

    return ResponsiveScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => context.push(AppRoutes.profile),
                  child: Row(
                    children: [
                      PlayerAvatar(displayName: playerName, size: 44),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HELLO,', style: AppTypography.labelSm),
                          Text(playerName, style: AppTypography.headlineSm),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(AppRoutes.profile),
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Center(child: BingoLogo(fontSize: 36, showTagline: true)),
            const SizedBox(height: 28),

            // Single Player Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const StatusBadge(
                        label: 'SOLO PRACTICE',
                        backgroundColor: AppColors.lightLavender,
                        icon: Icons.person,
                      ),
                      Icon(
                        Icons.smart_toy_outlined,
                        color: AppColors.primaryNavy.withAlpha(150),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Single Player', style: AppTypography.headlineMd),
                  const SizedBox(height: 4),
                  Text(
                    'Compete against the computer with Easy, Medium, or Hard AI strategies.',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Play Single Player',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () =>
                        context.push(AppRoutes.singlePlayerDifficulty),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Multiplayer Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const StatusBadge(
                        label: '2-4 PLAYERS',
                        backgroundColor: Color(0xFFFEF3C7),
                        textColor: AppColors.softYellowDark,
                        icon: Icons.groups_rounded,
                      ),
                      Icon(
                        Icons.wifi_tethering,
                        color: AppColors.primaryCoral.withAlpha(200),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Multiplayer Rooms', style: AppTypography.headlineMd),
                  const SizedBox(height: 4),
                  Text(
                    'Create private rooms, invite friends with a code, and compete in real-time.',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(
                    label: 'Play Multiplayer',
                    icon: Icons.sports_esports_rounded,
                    onPressed: () => context.push(AppRoutes.multiplayerMenu),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats Card
            AppCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('MATCHES', '12'),
                  Container(
                    height: 30,
                    width: 1,
                    color: AppColors.structuralBorder,
                  ),
                  _buildStatItem('WIN RATE', '75%'),
                  Container(
                    height: 30,
                    width: 1,
                    color: AppColors.structuralBorder,
                  ),
                  _buildStatItem('BEST STREAK', '4 🔥'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineSm),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.labelSm),
      ],
    );
  }
}
