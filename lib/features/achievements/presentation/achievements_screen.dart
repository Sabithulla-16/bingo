import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../data/achievements_repository.dart';
import '../domain/achievement.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementCategory _selectedFilter = AchievementCategory.all;
  final Set<String> _claimingIds = {};

  Future<void> _handleClaim(Achievement item) async {
    if (_claimingIds.contains(item.id)) return;
    setState(() => _claimingIds.add(item.id));

    try {
      final repo = ref.read(achievementsRepositoryProvider);
      final reward = await repo.claimAchievement(item.id);
      ref.read(feedbackServiceProvider).celebration();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: AppColors.softYellow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '+$reward Chips Claimed!',
                  style: AppTypography.labelMd.copyWith(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedFull),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claimingIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final chips = profile?.chips ?? 500;

    final achievementsAsync = ref.watch(achievementsListProvider);
    final rawList = achievementsAsync.valueOrNull ?? Achievement.standardList;

    // Filter by active category tab
    final filtered = _selectedFilter == AchievementCategory.all
        ? rawList
        : rawList.where((a) => a.category == _selectedFilter).toList();

    // Enforce mandatory Priority Sorting: Ready -> In Progress -> Locked -> Claimed
    final sortedList = Achievement.sortList(filtered);

    // Compute overview metrics
    final totalCount = rawList.length;
    final unlockedCount = rawList
        .where((a) => a.status.isReady || a.status.isClaimed)
        .length;
    final remainingCount = totalCount - unlockedCount;
    final completionPercentage = totalCount > 0
        ? (unlockedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final unclaimedReadyTotal = rawList
        .where((a) => a.status.isReady)
        .fold<int>(0, (sum, a) => sum + a.rewardChips);
    final totalChipsWon = rawList
        .where((a) => a.status.isClaimed)
        .fold<int>(850, (sum, a) => sum);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Achievements', style: AppTypography.headlineSm),
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
          // Expanded Chip Balance Pill (No profile icon in header)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: AppRadii.roundedFull,
                border: Border.all(color: AppColors.structuralBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    size: 16,
                    color: AppColors.softYellowDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$chips',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'CHIPS',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Trophy Showcase Hero Overview Card
            _buildTrophyShowcaseCard(
              completionPercentage: completionPercentage,
              unlockedCount: unlockedCount,
              totalCount: totalCount,
              remainingCount: remainingCount,
              totalChipsWon: totalChipsWon,
              unclaimedReadyTotal: unclaimedReadyTotal,
            ),

            const SizedBox(height: 14),

            // 2. Category Filter Rail
            _buildCategoryFilterRail(rawList),

            const SizedBox(height: 10),

            // 3. Sorting Header Hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SORTED: READY → IN PROGRESS → LOCKED → CLAIMED',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${sortedList.length} shown',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 9,
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 4. Achievement Cards Stack
            _buildAchievementList(sortedList),

            const SizedBox(height: 20),

            // 5. Sync & Reassurance Footer
            _buildSyncFooter(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION BUILDERS
  // ==========================================

  Widget _buildTrophyShowcaseCard({
    required double completionPercentage,
    required int unlockedCount,
    required int totalCount,
    required int remainingCount,
    required int totalChipsWon,
    required int unclaimedReadyTotal,
  }) {
    final percentInt = (completionPercentage * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: AppRadii.roundedFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.military_tech_rounded,
                            size: 14,
                            color: AppColors.primaryCoral,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'MILESTONE VAULT',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Trophy Showcase',
                      style: AppTypography.headlineMd.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Complete milestones to earn chips & bragging rights',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Radial Progress Circle Meter
              _buildRadialProgress(completionPercentage, percentInt),
            ],
          ),

          const SizedBox(height: 14),

          // Overall Linear Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OVERALL COMPLETION',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$unlockedCount / $totalCount Unlocked',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: LinearProgressIndicator(
              value: completionPercentage,
              minHeight: 7,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryCoral,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 4-Grid Stats Bento Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadii.roundedLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildBentoStat(
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.primaryNavy,
                    value: '$unlockedCount',
                    label: 'Unlocked',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.structuralBorder,
                ),
                Expanded(
                  child: _buildBentoStat(
                    icon: Icons.hourglass_top_rounded,
                    iconColor: AppColors.textMuted,
                    value: '$remainingCount',
                    label: 'Remaining',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.structuralBorder,
                ),
                Expanded(
                  child: _buildBentoStat(
                    icon: Icons.monetization_on_rounded,
                    iconColor: AppColors.softYellowDark,
                    value: '$totalChipsWon',
                    label: 'Chips Won',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.structuralBorder,
                ),
                Expanded(
                  child: _buildBentoStat(
                    icon: Icons.redeem_rounded,
                    iconColor: AppColors.primaryCoral,
                    value: '$unclaimedReadyTotal',
                    label: 'Unclaimed',
                    valueColor: AppColors.primaryCoral,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadialProgress(double percent, int percentInt) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(64, 64),
            painter: _RadialPainter(
              progress: percent,
              trackColor: AppColors.surfaceContainerHigh,
              fillColor: AppColors.primaryCoral,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentInt%',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                'GOAL',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 7.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoStat({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w900,
            color: valueColor ?? AppColors.primaryNavy,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(
            fontSize: 8.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterRail(List<Achievement> allAchievements) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AchievementCategory.values.map((cat) {
          final isSelected = _selectedFilter == cat;
          final count = cat == AchievementCategory.all
              ? allAchievements.length
              : allAchievements.where((a) => a.category == cat).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = cat),
              borderRadius: AppRadii.roundedFull,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryNavy : AppColors.surface,
                  borderRadius: AppRadii.roundedFull,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryNavy
                        : AppColors.structuralBorder,
                  ),
                ),
                child: Text(
                  '${cat.label} ($count)',
                  style: AppTypography.labelSm.copyWith(
                    color: isSelected ? Colors.white : AppColors.primaryNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAchievementList(List<Achievement> sortedList) {
    if (sortedList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'No achievements in this category.',
          style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = sortedList[index];
        return _buildAchievementCard(item);
      },
    );
  }

  Widget _buildAchievementCard(Achievement item) {
    final isClaiming = _claimingIds.contains(item.id);

    // Dynamic styling based on state
    Color cardBg = AppColors.surface;
    Color borderColor = AppColors.structuralBorder;
    if (item.status.isReady) {
      borderColor = AppColors.primaryCoral.withAlpha(120);
    } else if (item.status.isLocked) {
      cardBg = AppColors.surfaceContainerLow.withAlpha(160);
    }

    return AppCard(
      backgroundColor: cardBg,
      padding: const EdgeInsets.all(14),
      border: Border.all(color: borderColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          _buildCardIcon(item),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: item.status.isLocked
                              ? AppColors.textSecondary
                              : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusPill(item),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 11,
                    color: item.status.isLocked
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Card Footer: Reward & Progress / Claim Action
                _buildCardFooter(item, isClaiming),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardIcon(Achievement item) {
    IconData iconData;
    Color iconColor = AppColors.primaryNavy;
    Color bg = AppColors.surfaceContainerLow;

    switch (item.icon) {
      case 'ads_click':
        iconData = Icons.ads_click_rounded;
        break;
      case 'local_fire_department':
        iconData = Icons.local_fire_department_rounded;
        iconColor = AppColors.primaryCoral;
        break;
      case 'sports_esports':
        iconData = Icons.sports_esports_rounded;
        break;
      case 'hotel_class':
        iconData = Icons.hotel_class_rounded;
        iconColor = AppColors.softYellowDark;
        break;
      case 'calendar_month':
        iconData = Icons.calendar_month_rounded;
        break;
      case 'casino':
        iconData = Icons.casino_rounded;
        break;
      case 'lock':
        iconData = Icons.lock_rounded;
        iconColor = AppColors.textMuted;
        break;
      case 'diamond':
        iconData = Icons.diamond_rounded;
        break;
      case 'military_tech':
        iconData = Icons.military_tech_rounded;
        break;
      case 'emoji_events':
        iconData = Icons.emoji_events_rounded;
        iconColor = AppColors.softYellowDark;
        break;
      case 'group':
        iconData = Icons.group_rounded;
        break;
      case 'palette':
        iconData = Icons.palette_rounded;
        break;
      case 'event_available':
        iconData = Icons.event_available_rounded;
        break;
      default:
        iconData = Icons.stars_rounded;
    }

    if (item.status.isReady) {
      bg = AppColors.primaryCoral.withAlpha(25);
      iconColor = AppColors.primaryCoral;
    }

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, size: 22, color: iconColor),
        ),
        if (item.status.isReady)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primaryCoral,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusPill(Achievement item) {
    if (item.status.isReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryCoral,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          'READY',
          style: AppTypography.labelSm.copyWith(
            fontSize: 8.5,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (item.status.isInProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          'IN PROGRESS',
          style: AppTypography.labelSm.copyWith(
            fontSize: 8.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (item.status.isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          'LOCKED',
          style: AppTypography.labelSm.copyWith(
            fontSize: 8.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadii.roundedFull,
      ),
      child: Text(
        'CLAIMED ✓',
        style: AppTypography.labelSm.copyWith(
          fontSize: 8.5,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCardFooter(Achievement item, bool isClaiming) {
    if (item.status.isReady) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 15,
                color: AppColors.softYellowDark,
              ),
              const SizedBox(width: 4),
              Text(
                '+${item.rewardChips} Chips',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: isClaiming ? null : () => _handleClaim(item),
            borderRadius: AppRadii.roundedFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryCoral,
                borderRadius: AppRadii.roundedFull,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33FC695C),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'CLAIM +${item.rewardChips}',
                    style: AppTypography.labelSm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.redeem_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (item.status.isClaimed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '+${item.rewardChips} Chips',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: AppColors.readyGreen,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.current} / ${item.target}',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // In Progress or Locked
    final percent = item.progressPercentInt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: 14,
                  color: item.status.isLocked
                      ? AppColors.textMuted
                      : AppColors.softYellowDark,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${item.rewardChips} Chips',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: item.status.isLocked
                        ? AppColors.textMuted
                        : AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
            Text(
              '${item.current} / ${item.target} ($percent%)',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadii.roundedFull,
          child: LinearProgressIndicator(
            value: item.progressPercentage,
            minHeight: 5,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(
              item.status.isLocked
                  ? AppColors.textMuted
                  : (item.icon == 'local_fire_department'
                        ? AppColors.primaryCoral
                        : AppColors.primaryNavy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncFooter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sync_rounded,
              size: 14,
              color: AppColors.primaryNavy,
            ),
            const SizedBox(width: 6),
            Text(
              'Achievements update automatically after every verified match.',
              style: AppTypography.labelSm.copyWith(
                fontSize: 9.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  _RadialPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
