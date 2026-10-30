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
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_state.dart';

/// Player Profile & Personal Statistics (Stitch Screen ID: `5e7e8a333408412990869a864a7b06f2`)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final displayName = authState is Authenticated
        ? authState.profile.displayName
        : 'Valtry';
    final email = authState is Authenticated
        ? authState.profile.email
        : 'player@bingo.app';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Player Profile', style: AppTypography.headlineSm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  PlayerAvatar(displayName: displayName, size: 72),
                  const SizedBox(height: 12),
                  Text(displayName, style: AppTypography.headlineMd),
                  Text(email, style: AppTypography.bodySm),
                  const SizedBox(height: 8),
                  const StatusBadge(
                    label: 'VERIFIED PLAYER',
                    icon: Icons.verified_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lifetime Stats Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAREER STATISTICS', style: AppTypography.labelSm),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCareerStat('MATCHES', '48'),
                      _buildCareerStat('WINS', '32'),
                      _buildCareerStat('WIN %', '66.7%'),
                      _buildCareerStat('BEST STREAK', '7 🔥'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Badges & Achievements
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACHIEVEMENTS', style: AppTypography.labelSm),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBadge(
                        Icons.bolt_rounded,
                        'Speed Striker',
                        AppColors.softYellow,
                      ),
                      _buildBadge(
                        Icons.military_tech_rounded,
                        'Room Master',
                        AppColors.primaryCoral,
                      ),
                      _buildBadge(
                        Icons.all_inclusive_rounded,
                        'Streak King',
                        AppColors.primaryNavy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              onPressed: () async {
                await ref.read(authStateProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(AppRoutes.auth);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineSm),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.labelSm),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String name, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(name, style: AppTypography.bodySm.copyWith(fontSize: 11)),
      ],
    );
  }
}
