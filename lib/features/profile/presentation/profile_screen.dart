import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../domain/player_career_stats.dart';
import '../domain/player_profile.dart';

/// Player Profile & Personal Statistics (Stitch Screen ID: `5e7e8a333408412990869a864a7b06f2`)
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _openEditProfileDialog(PlayerProfile profile) {
    showDialog(
      context: context,
      barrierColor: AppColors.scrimOverlayColor,
      builder: (ctx) => _EditProfileDialog(initialProfile: profile),
    );
  }

  void _openPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _AudioAndPreferencesSheet(),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to log out of your BINGO account?',
        confirmLabel: 'Log Out',
        cancelLabel: 'Cancel',
        isDestructive: true,
        onConfirm: () async {
          await ref.read(authStateProvider.notifier).signOut();
          if (mounted) {
            context.go(AppRoutes.auth);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile =
        ref.watch(currentProfileProvider) ??
        PlayerProfile(
          id: 'valtry-local-user',
          displayName: 'Valtry',
          email: 'valtry@bingo.app',
          avatarId: 'avatar_coral',
          avatarColorHex: '#FC695C',
          chips: 500,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
        );

    final statsAsync = ref.watch(careerStatsProvider(currentProfile.id));
    final stats = statsAsync.value ?? PlayerCareerStats.sampleData();

    return ResponsiveScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryNavy),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Column(
          children: [
            Text('BINGO', style: AppTypography.headlineSm),
            Text(
              'Player Profile & Personal Statistics',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primaryNavy),
            onPressed: _openPreferencesSheet,
            tooltip: 'Audio & Settings',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: PlayerAvatar(
                displayName: currentProfile.displayName,
                size: 32,
                backgroundColor: _parseColor(currentProfile.avatarColorHex),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sub-Header
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryCoral,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PLAYER PROFILE',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primaryCoral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Your profile', style: AppTypography.displayHeroMobile),
            Text(
              'Overall BINGO statistics and lifetime match records across all rooms.',
              style: AppTypography.bodyMd,
            ),
            const SizedBox(height: 18),

            // Player Identity Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      PlayerAvatar(
                        displayName: currentProfile.displayName,
                        size: 64,
                        showOnlineIndicator: true,
                        backgroundColor: _parseColor(
                          currentProfile.avatarColorHex,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    currentProfile.displayName,
                                    style: AppTypography.headlineSm,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.primaryCoral,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Player ID: ${currentProfile.shortPlayerId}',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              currentProfile.formattedMemberSince,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightLavender,
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.military_tech_rounded,
                              size: 14,
                              color: AppColors.primaryNavy,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'BINGO PLAYER',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _openEditProfileDialog(currentProfile),
                        borderRadius: AppRadii.roundedFull,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: AppColors.primaryNavy,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'EDIT PROFILE',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Performance 2x2 Grid
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR PERFORMANCE',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primaryCoral,
                  ),
                ),
                Text(
                  'Your results across all completed matches',
                  style: AppTypography.headlineSm,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'TOTAL MATCHES',
                        value: '${stats.totalMatches}',
                        subtitle: 'Completed games',
                        icon: Icons.sports_esports_outlined,
                        valueColor: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'WINS',
                        value: '${stats.wins}',
                        subtitle: 'First to BINGO',
                        icon: Icons.emoji_events_outlined,
                        valueColor: AppColors.primaryCoral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'LOSSES',
                        value: '${stats.losses}',
                        subtitle: 'Defeats',
                        icon: Icons.flag_outlined,
                        valueColor: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'DRAWS',
                        value: '${stats.draws}',
                        subtitle: 'No BINGO winner',
                        icon: Icons.handshake_outlined,
                        valueColor: AppColors.softYellow,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Win Rate Metric Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WIN RATE',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${stats.winRatePercentage}%',
                        style: AppTypography.displayHeroMobile.copyWith(
                          color: AppColors.primaryCoral,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'overall ratio',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Percentage of completed matches won. Draws and losses count toward total games played.',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: 12),
                  // Rounded track
                  ClipRRect(
                    borderRadius: AppRadii.roundedFull,
                    child: LinearProgressIndicator(
                      value: stats.totalMatches > 0
                          ? stats.wins / stats.totalMatches
                          : 0.0,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryCoral,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calculation: (${stats.wins} Wins / ${stats.totalMatches} Matches) × 100',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Winning Streaks Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WINNING STREAKS',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primaryCoral,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'CURRENT STREAK',
                                  style: AppTypography.labelSm,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCoral.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: AppColors.primaryCoral,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${stats.currentStreak} WINS',
                              style: AppTypography.headlineMd.copyWith(
                                color: AppColors.primaryCoral,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Active streak • Next match counts',
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'BEST STREAK',
                                  style: AppTypography.labelSm,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.softYellow.withAlpha(40),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.primaryNavy,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${stats.bestStreak} WINS',
                              style: AppTypography.headlineMd.copyWith(
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Personal record • Permanent',
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Personal Highlights Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        color: AppColors.primaryCoral,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('PERSONAL HIGHLIGHTS', style: AppTypography.labelMd),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildHighlightRow(
                    'Most Wins in Single Room',
                    '6 Wins (Friday BINGO)',
                    AppColors.primaryNavy,
                  ),
                  const SizedBox(height: 8),
                  _buildHighlightRow(
                    'Highest Lines Claimed',
                    '${stats.highestLinesClaimed} / 5 Lines (12 times)',
                    AppColors.primaryNavy,
                  ),
                  const SizedBox(height: 8),
                  _buildHighlightRow(
                    'Longest Winning Streak',
                    '${stats.bestStreak} Consecutive',
                    AppColors.primaryCoral,
                  ),
                  const SizedBox(height: 8),
                  _buildHighlightRow(
                    'Average Calls per Match',
                    '${stats.averageCallsPerMatch} Calls',
                    AppColors.primaryNavy,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recent Matches History
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECENT MATCHES',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primaryCoral,
                          ),
                        ),
                        Text(
                          'Your latest completed games',
                          style: AppTypography.bodySm,
                        ),
                      ],
                    ),
                    Text(
                      'TOTAL (${stats.totalMatches})',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...stats.recentMatches.map((match) => _buildMatchCard(match)),
              ],
            ),

            const SizedBox(height: 20),

            // Account Actions
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.lightLavender,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppColors.primaryNavy,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Audio & Game Settings',
                      style: AppTypography.bodyLg,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _openPreferencesSheet,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.errorRed,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Log Out',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.errorRed,
                      ),
                    ),
                    subtitle: Text(
                      'Requires confirmation',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _confirmSignOut,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Return to Home CTA
            SecondaryButton(
              label: 'Return to Home',
              icon: Icons.arrow_back,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color valueColor,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.labelSm),
              Icon(icon, size: 18, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.displayHeroMobile.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySm.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadii.roundedMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: AppTypography.labelMd.copyWith(color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchRecord match) {
    Color badgeBg;
    Color badgeFg;
    String badgeText;

    switch (match.outcome) {
      case MatchOutcome.victory:
        badgeBg = AppColors.primaryCoral.withAlpha(30);
        badgeFg = AppColors.primaryCoral;
        badgeText = 'VICTORY';
        break;
      case MatchOutcome.defeat:
        badgeBg = AppColors.surfaceContainerHigh;
        badgeFg = AppColors.textSecondary;
        badgeText = 'DEFEAT';
        break;
      case MatchOutcome.draw:
        badgeBg = AppColors.softYellow.withAlpha(40);
        badgeFg = AppColors.primaryNavy;
        badgeText = 'DRAW';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: AppRadii.roundedFull,
                  ),
                  child: Text(
                    badgeText,
                    style: AppTypography.labelSm.copyWith(
                      color: badgeFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  match.formattedTimeAgo,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(match.roomName, style: AppTypography.headlineSm),
                Text(
                  'Round 0${match.roundNumber}',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${match.linesClaimed} / 5 Lines Claimed',
                  style: AppTypography.labelMd.copyWith(
                    color: match.outcome == MatchOutcome.victory
                        ? AppColors.primaryCoral
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${match.callsCount} Calls',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return AppColors.primaryCoral;
    }
  }
}

/// Edit Profile Modal Dialog with Avatar Palette Selection
class _EditProfileDialog extends ConsumerStatefulWidget {
  final PlayerProfile initialProfile;

  const _EditProfileDialog({required this.initialProfile});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late TextEditingController _nameController;
  late String _selectedColorHex;
  bool _isSaving = false;

  final List<String> _palette = [
    '#FC695C', // Coral
    '#FFD166', // Soft Yellow
    '#20243A', // Midnight Navy
    '#E8E5FF', // Light Lavender
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialProfile.displayName,
    );
    _selectedColorHex = widget.initialProfile.avatarColorHex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await ref
          .read(authStateProvider.notifier)
          .updateProfile(
            displayName: newName,
            avatarColorHex: _selectedColorHex,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedXl),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile', style: AppTypography.headlineSm),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  PlayerAvatar(
                    displayName: _nameController.text.isNotEmpty
                        ? _nameController.text
                        : widget.initialProfile.displayName,
                    size: 72,
                    backgroundColor: _parseColor(_selectedColorHex),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose Avatar Palette',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primaryCoral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _palette.map((hex) {
                      final isSelected = hex == _selectedColorHex;
                      final col = _parseColor(hex);
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorHex = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryNavy
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Display Name',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            AppTextField(
              controller: _nameController,
              hintText: 'Enter your player codename',
              maxLength: 20,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: AppTypography.labelMd),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: _handleSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return AppColors.primaryCoral;
    }
  }
}

/// Modal Bottom Sheet for Audio & Preference Controls
class _AudioAndPreferencesSheet extends ConsumerWidget {
  const _AudioAndPreferencesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(playerPreferencesProvider);
    final notifier = ref.read(playerPreferencesProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Audio & Game Settings', style: AppTypography.headlineSm),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text('Sound Effects', style: AppTypography.bodyLg),
            subtitle: Text(
              'Play ball call and win sounds',
              style: AppTypography.bodySm,
            ),
            activeThumbColor: AppColors.primaryCoral,
            value: prefs.soundEffectsEnabled,
            onChanged: (_) => notifier.toggleSoundEffects(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: Text('Haptic Feedback', style: AppTypography.bodyLg),
            subtitle: Text(
              'Tactile vibrations on line strikes and calls',
              style: AppTypography.bodySm,
            ),
            activeThumbColor: AppColors.primaryCoral,
            value: prefs.hapticsEnabled,
            onChanged: (_) => notifier.toggleHaptics(),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
