import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../data/rewards_repository.dart';
import '../domain/earn_chips_models.dart';

class EarnChipsScreen extends ConsumerStatefulWidget {
  const EarnChipsScreen({super.key});

  @override
  ConsumerState<EarnChipsScreen> createState() => _EarnChipsScreenState();
}

class _EarnChipsScreenState extends ConsumerState<EarnChipsScreen> {
  bool _isClaimingDaily = false;
  bool _isClaimingWin = false;

  Future<void> _handleClaimDaily() async {
    setState(() => _isClaimingDaily = true);
    try {
      final repo = ref.read(rewardsRepositoryProvider);
      final reward = await repo.claimDailyCheckin();
      ref.read(feedbackServiceProvider).celebration();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+$reward Chips Added to Wallet!',
              style: AppTypography.labelMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedFull),
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
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Future<void> _handleClaimWinMatch() async {
    setState(() => _isClaimingWin = true);
    try {
      final repo = ref.read(rewardsRepositoryProvider);
      final reward = await repo.claimTask('win_match');
      ref.read(feedbackServiceProvider).celebration();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+$reward Chips Claimed!',
              style: AppTypography.labelMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedFull),
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
      if (mounted) setState(() => _isClaimingWin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final chips = profile?.chips ?? 500;

    final checkinAsync = ref.watch(dailyCheckinProvider);
    final tasksAsync = ref.watch(earnTasksProvider);
    final walletMetricsAsync = ref.watch(walletOverviewProvider);

    final checkin =
        checkinAsync.valueOrNull ??
        const DailyCheckinInfo(
          streak: 4,
          isClaimedToday: false,
          todayReward: 40,
          claimedDays: [1, 2, 3],
          secondsUntilReset: 51720,
        );

    final tasks = tasksAsync.valueOrNull ?? [];
    final winTask = tasks.firstWhere(
      (t) => t.id == 'win_match',
      orElse: () => const MatchRewardTask(
        id: 'win_match',
        title: 'Win a Match',
        category: 'match',
        description: 'Finished the round as top dauber',
        rewardChips: 30,
        current: 1,
        target: 1,
        status: RewardTaskStatus.readyToClaim,
      ),
    );

    final wallet =
        walletMetricsAsync.valueOrNull ??
        WalletOverviewMetrics(
          balance: chips,
          availableRewards: 70,
          lifetimeEarned: 1450,
          tasksCompleted: 18,
          totalTasks: 24,
        );

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Earn Chips', style: AppTypography.headlineSm),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryNavy,
          ),
          tooltip: 'Back to Store',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.store);
            }
          },
        ),
        actions: [
          // Current Chip Balance Pill (No profile icon in header)
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
            // 1. Hero Balance & Earning Overview Card
            _buildWalletOverviewCard(wallet),

            const SizedBox(height: 16),

            // 2. Daily Rewards: 7-Day Check-in Card
            _buildDailyCheckinCard(checkin),

            const SizedBox(height: 16),

            // 3. Match Rewards Section
            _buildMatchRewardsSection(winTask),

            const SizedBox(height: 16),

            // 4. Multiplayer Rewards Section
            _buildMultiplayerRewardsSection(),

            const SizedBox(height: 16),

            // 5. Achievements Preview Banner
            _buildAchievementsPreviewBanner(),

            const SizedBox(height: 16),

            // 6. Fairness Reassurance Footer
            _buildFairnessFooter(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION BUILDERS
  // ==========================================

  Widget _buildWalletOverviewCard(WalletOverviewMetrics wallet) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.softYellow.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.softYellowDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT WALLET BALANCE',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${wallet.balance}',
                            style: AppTypography.headlineMd.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CHIPS',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primaryCoral,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryCoral.withAlpha(25),
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '+${wallet.availableRewards} Unclaimed',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primaryCoral,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3 Bento Metric Tiles
          Row(
            children: [
              Expanded(
                child: _buildBentoTile(
                  'Available Rewards',
                  '+${wallet.availableRewards} Chips',
                  AppColors.primaryCoral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoTile(
                  'Lifetime Earned',
                  '+${wallet.lifetimeEarned} Chips',
                  AppColors.primaryNavy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoTile(
                  'Tasks Completed',
                  '${wallet.tasksCompleted} / ${wallet.totalTasks}',
                  AppColors.primaryNavy,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Informational description
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadii.roundedLg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.palette_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Earn chips purely through gameplay & milestones to unlock bespoke daubers, audio suites, and boards in the Store.',
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoTile(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(
              fontSize: 9.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCheckinCard(DailyCheckinInfo checkin) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Daily Check-in',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy,
                              borderRadius: AppRadii.roundedFull,
                            ),
                            child: Text(
                              'Day ${checkin.streak} of 7',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '+${checkin.todayReward} Chips waiting today',
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '${checkin.streak} Streak',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 7-Day Visual Progression Track (D1 to D7)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isToday = dayNum == checkin.streak;
              final isClaimed = checkin.claimedDays.contains(dayNum);
              final isLocked = dayNum > checkin.streak;
              final rewardVal = DailyCheckinInfo.defaultDayRewards[index];

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: _buildDayProgressNode(
                    dayNum: dayNum,
                    reward: rewardVal,
                    isToday: isToday,
                    isClaimed: isClaimed,
                    isLocked: isLocked,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 14),

          // Action Button & Timer
          if (checkin.isClaimedToday)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedFull,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CLAIMED TODAY (+${checkin.todayReward} CHIPS)',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            SecondaryButton(
              label: 'CLAIM TODAY (+${checkin.todayReward} CHIPS)',
              icon: Icons.monetization_on_rounded,
              isLoading: _isClaimingDaily,
              onPressed: _handleClaimDaily,
            ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                checkin.isClaimedToday
                    ? 'Come back tomorrow • Resets in ${checkin.formattedResetCountdown}'
                    : 'Resets in ${checkin.formattedResetCountdown}',
                style: AppTypography.bodySm.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayProgressNode({
    required int dayNum,
    required int reward,
    required bool isToday,
    required bool isClaimed,
    required bool isLocked,
  }) {
    Color bg = AppColors.surfaceContainerLow;
    Color border = Colors.transparent;

    if (isToday) {
      bg = AppColors.primaryCoral.withAlpha(25);
      border = AppColors.primaryCoral;
    } else if (dayNum == 7) {
      bg = AppColors.softYellow.withAlpha(40);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            'D$dayNum',
            style: AppTypography.labelSm.copyWith(
              fontSize: 9.5,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
              color: isToday ? AppColors.primaryCoral : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          if (isClaimed)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            )
          else if (isToday)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.primaryCoral,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.monetization_on,
                size: 14,
                color: Colors.white,
              ),
            )
          else if (dayNum == 7)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.softYellowDark.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stars_rounded,
                size: 14,
                color: AppColors.softYellowDark,
              ),
            )
          else
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '+$reward',
            style: AppTypography.labelSm.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isToday ? AppColors.primaryCoral : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRewardsSection(MatchRewardTask winTask) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Rewards',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Play single player daub sessions & challenge sprints',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Text(
                '2 of 3',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Task 1: Complete a Match (Claimed)
        _buildTaskCard(
          icon: Icons.sports_score_rounded,
          title: 'Complete a Match',
          reward: '+20',
          desc: 'Finished a valid regular session',
          statusSubtext: '3/3 Completed',
          buttonLabel: 'CLAIMED',
          isClaimed: true,
          onPressed: null,
        ),

        const SizedBox(height: 8),

        // Task 2: Win a Match (Claim Ready)
        _buildTaskCard(
          icon: Icons.military_tech_rounded,
          title: 'Win a Match',
          reward: '+30',
          desc: 'Finished the round as top dauber',
          statusSubtext: winTask.status.isClaimed
              ? 'Claimed'
              : 'Ready to claim',
          buttonLabel: _isClaimingWin
              ? 'CLAIMING...'
              : (winTask.status.isClaimed ? 'CLAIMED' : 'CLAIM (+30 CHIPS)'),
          isClaimed: winTask.status.isClaimed,
          isHighlight: !winTask.status.isClaimed && !_isClaimingWin,
          onPressed: (winTask.status.isClaimed || _isClaimingWin)
              ? null
              : _handleClaimWinMatch,
        ),

        const SizedBox(height: 8),

        // Task 3: Play Multiplayer (Incomplete)
        _buildTaskCard(
          icon: Icons.groups_rounded,
          title: 'Play Multiplayer',
          reward: '+20',
          desc: 'Complete any live synchronized match',
          statusSubtext: '0/1 Matches',
          buttonLabel: 'PLAY MATCH',
          isClaimed: false,
          onPressed: () => context.push(AppRoutes.multiplayerMenu),
        ),
      ],
    );
  }

  Widget _buildMultiplayerRewardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multiplayer Rewards',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Compete with other players in live rooms',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Text(
                'Weekly',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Room Champion Card
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.softYellow.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: AppColors.softYellowDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Room Champion',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.softYellow,
                                  borderRadius: AppRadii.roundedFull,
                                ),
                                child: Text(
                                  '+100',
                                  style: AppTypography.labelSm.copyWith(
                                    fontSize: 9,
                                    color: AppColors.primaryNavy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Win a multiplayer room match with 4+ players',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push(AppRoutes.multiplayerMenu),
                    borderRadius: AppRadii.roundedFull,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: AppRadii.roundedFull,
                      ),
                      child: Text(
                        'JOIN ROOM',
                        style: AppTypography.labelSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress track (2/3 Wins - 66%)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'In Progress (66%)',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '2/3 Wins',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: AppRadii.roundedFull,
                      child: const LinearProgressIndicator(
                        value: 0.66,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryCoral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Play with Friends Card
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.diversity_3_rounded,
                          color: AppColors.primaryNavy,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Play with Friends',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  borderRadius: AppRadii.roundedFull,
                                ),
                                child: Text(
                                  '+25',
                                  style: AppTypography.labelSm.copyWith(
                                    fontSize: 9,
                                    color: AppColors.primaryNavy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Complete matches with invited friends',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push(AppRoutes.multiplayerMenu),
                    borderRadius: AppRadii.roundedFull,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: AppRadii.roundedFull,
                      ),
                      child: Text(
                        'INVITE',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'In Progress (50%)',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '1/2 Matches',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: AppRadii.roundedFull,
                      child: const LinearProgressIndicator(
                        value: 0.5,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard({
    required IconData icon,
    required String title,
    required String reward,
    required String desc,
    required String statusSubtext,
    required String buttonLabel,
    required bool isClaimed,
    bool isHighlight = false,
    VoidCallback? onPressed,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isHighlight
                  ? AppColors.primaryCoral.withAlpha(25)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isHighlight
                  ? AppColors.primaryCoral
                  : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isHighlight
                            ? AppColors.primaryCoral
                            : AppColors.surfaceContainer,
                        borderRadius: AppRadii.roundedFull,
                      ),
                      child: Text(
                        reward,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isHighlight
                              ? Colors.white
                              : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  statusSubtext,
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9.5,
                    color: isHighlight
                        ? AppColors.primaryCoral
                        : AppColors.textMuted,
                    fontWeight: isHighlight
                        ? FontWeight.w800
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onPressed,
            borderRadius: AppRadii.roundedFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isHighlight
                    ? AppColors.primaryCoral
                    : AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Text(
                buttonLabel,
                style: AppTypography.labelSm.copyWith(
                  color: isHighlight
                      ? Colors.white
                      : (isClaimed
                            ? AppColors.textMuted
                            : AppColors.primaryNavy),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsPreviewBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: AppRadii.roundedXl,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F20243A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.softYellow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements & Milestones',
                    style: AppTypography.labelMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '12 / 28 Unlocked • Up to +1,850 Chips',
                    style: AppTypography.labelSm.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT UNLOCK IN REACH',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        color: AppColors.softYellow,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Winning Streak (2/3 wins)',
                      style: AppTypography.labelMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.roundedFull,
                  ),
                  child: Text(
                    '+200 CHIPS',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryCoral,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          PrimaryButton(
            label: 'View All Achievements',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push(AppRoutes.achievements),
          ),
        ],
      ),
    );
  }

  Widget _buildFairnessFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadii.roundedLg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Cosmetic Economy • Chips cannot be bought with real cash. Earned strictly through gameplay.',
              style: AppTypography.bodySm.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
