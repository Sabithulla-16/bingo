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
import '../../achievements/data/achievements_repository.dart';
import '../../achievements/domain/achievement.dart';
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
  final Set<String> _claimingTaskIds = {};

  Future<void> _handleClaimTask(String taskId) async {
    if (_claimingTaskIds.contains(taskId)) return;
    setState(() => _claimingTaskIds.add(taskId));
    try {
      final repo = ref.read(rewardsRepositoryProvider);
      final reward = await repo.claimTask(taskId);
      ref.read(feedbackServiceProvider).celebration();
      await ref.read(authStateProvider.notifier).reloadProfile();
      ref.invalidate(walletOverviewProvider);
      ref.invalidate(earnTasksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+$reward Chips Claimed!',
              style: AppTypography.labelMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedFull),
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
      if (mounted) setState(() => _claimingTaskIds.remove(taskId));
    }
  }

  Future<void> _handleClaimDaily() async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);
    try {
      final repo = ref.read(rewardsRepositoryProvider);
      final reward = await repo.claimDailyCheckin();
      ref.read(feedbackServiceProvider).celebration();
      await ref.read(authStateProvider.notifier).reloadProfile();
      ref.invalidate(walletOverviewProvider);
      ref.invalidate(dailyCheckinProvider);

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
        ref.invalidate(dailyCheckinProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('already claimed')
                  ? 'Daily reward already claimed today.'
                  : 'Failed to claim daily reward. Please try again.',
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Future<void> _handleClaimWinMatch() async {
    if (_isClaimingWin) return;
    setState(() => _isClaimingWin = true);
    try {
      final repo = ref.read(rewardsRepositoryProvider);
      final reward = await repo.claimTask('win_match');
      ref.read(feedbackServiceProvider).celebration();
      await ref.read(authStateProvider.notifier).reloadProfile();
      ref.invalidate(walletOverviewProvider);

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
    final achievementsAsync = ref.watch(achievementsListProvider);
    final achievements = achievementsAsync.valueOrNull ?? [];

    final checkin =
        checkinAsync.valueOrNull ??
        const DailyCheckinInfo(
          streak: 1,
          isClaimedToday: false,
          todayReward: 25,
          claimedDays: [],
          secondsUntilReset: 86400,
        );

    final tasks = tasksAsync.valueOrNull ?? [];
    final completeTask = tasks.firstWhere(
      (t) => t.id == 'complete_match',
      orElse: () => const MatchRewardTask(
        id: 'complete_match',
        title: 'Complete a Match',
        category: 'match',
        description: 'Finished a valid regular session',
        rewardChips: 20,
        current: 0,
        target: 3,
        status: RewardTaskStatus.inProgress,
      ),
    );

    final winTask = tasks.firstWhere(
      (t) => t.id == 'win_match',
      orElse: () => const MatchRewardTask(
        id: 'win_match',
        title: 'Win a Match',
        category: 'match',
        description: 'Finished the round as top dauber',
        rewardChips: 30,
        current: 0,
        target: 1,
        status: RewardTaskStatus.inProgress,
      ),
    );

    final playMultiplayerTask = tasks.firstWhere(
      (t) => t.id == 'play_multiplayer',
      orElse: () => const MatchRewardTask(
        id: 'play_multiplayer',
        title: 'Play Multiplayer',
        category: 'match',
        description: 'Complete any live synchronized match',
        rewardChips: 20,
        current: 0,
        target: 1,
        status: RewardTaskStatus.inProgress,
      ),
    );

    final roomChampionTask = tasks.firstWhere(
      (t) => t.id == 'room_champion',
      orElse: () => const MatchRewardTask(
        id: 'room_champion',
        title: 'Room Champion',
        category: 'multiplayer',
        description: 'Win a multiplayer room match with 4+ players',
        rewardChips: 100,
        current: 0,
        target: 3,
        status: RewardTaskStatus.inProgress,
      ),
    );

    final playFriendsTask = tasks.firstWhere(
      (t) => t.id == 'play_with_friends',
      orElse: () => const MatchRewardTask(
        id: 'play_with_friends',
        title: 'Play with Friends',
        category: 'multiplayer',
        description: 'Complete matches with invited friends',
        rewardChips: 25,
        current: 0,
        target: 2,
        status: RewardTaskStatus.inProgress,
      ),
    );

    final wallet =
        walletMetricsAsync.valueOrNull ??
        WalletOverviewMetrics(
          balance: chips,
          availableRewards: 0,
          lifetimeEarned: chips,
          tasksCompleted: 0,
          totalTasks: tasks.isEmpty ? 5 : tasks.length + 1,
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
            _buildMatchRewardsSection(completeTask, winTask, playMultiplayerTask),

            const SizedBox(height: 16),

            // 4. Multiplayer Rewards Section
            _buildMultiplayerRewardsSection(roomChampionTask, playFriendsTask),

            const SizedBox(height: 16),

            // 5. Achievements Preview Banner
            _buildAchievementsPreviewBanner(achievements),

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
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.readyGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CLAIMED TODAY (+${checkin.todayReward} CHIPS) ✓',
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

  Widget _buildMatchRewardsSection(
    MatchRewardTask completeTask,
    MatchRewardTask winTask,
    MatchRewardTask playMultiplayerTask,
  ) {
    final completedCount = [completeTask, winTask, playMultiplayerTask]
        .where((t) => t.status.isClaimed || t.status.isReady)
        .length;

    final isClaimingComplete = _claimingTaskIds.contains(completeTask.id);
    final isClaimingMulti = _claimingTaskIds.contains(playMultiplayerTask.id);

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
                '$completedCount of 3',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Task 1: Complete a Match
        _buildTaskCard(
          icon: Icons.sports_score_rounded,
          title: completeTask.title,
          reward: '+${completeTask.rewardChips}',
          desc: completeTask.description,
          statusSubtext: completeTask.status.isClaimed
              ? 'Claimed'
              : (completeTask.status.isReady
                  ? 'Ready to claim'
                  : '${completeTask.current}/${completeTask.target} Completed'),
          buttonLabel: isClaimingComplete
              ? 'CLAIMING...'
              : (completeTask.status.isClaimed
                  ? 'CLAIMED'
                  : (completeTask.status.isReady
                      ? 'CLAIM (+${completeTask.rewardChips} CHIPS)'
                      : 'PLAY MATCH')),
          isClaimed: completeTask.status.isClaimed,
          isHighlight: completeTask.status.isReady && !isClaimingComplete,
          onPressed: completeTask.status.isClaimed
              ? null
              : (completeTask.status.isReady
                  ? () => _handleClaimTask(completeTask.id)
                  : () => context.push(AppRoutes.singlePlayerDifficulty)),
        ),

        const SizedBox(height: 8),

        // Task 2: Win a Match
        _buildTaskCard(
          icon: Icons.military_tech_rounded,
          title: winTask.title,
          reward: '+${winTask.rewardChips}',
          desc: winTask.description,
          statusSubtext: winTask.status.isClaimed
              ? 'Claimed'
              : (winTask.status.isReady
                  ? 'Ready to claim'
                  : '${winTask.current}/${winTask.target} Wins'),
          buttonLabel: _isClaimingWin
              ? 'CLAIMING...'
              : (winTask.status.isClaimed
                  ? 'CLAIMED'
                  : (winTask.status.isReady
                      ? 'CLAIM (+${winTask.rewardChips} CHIPS)'
                      : 'PLAY MATCH')),
          isClaimed: winTask.status.isClaimed,
          isHighlight: winTask.status.isReady && !_isClaimingWin,
          onPressed: (winTask.status.isClaimed || _isClaimingWin)
              ? null
              : (winTask.status.isReady
                  ? _handleClaimWinMatch
                  : () => context.push(AppRoutes.singlePlayerDifficulty)),
        ),

        const SizedBox(height: 8),

        // Task 3: Play Multiplayer
        _buildTaskCard(
          icon: Icons.groups_rounded,
          title: playMultiplayerTask.title,
          reward: '+${playMultiplayerTask.rewardChips}',
          desc: playMultiplayerTask.description,
          statusSubtext: playMultiplayerTask.status.isClaimed
              ? 'Claimed'
              : (playMultiplayerTask.status.isReady
                  ? 'Ready to claim'
                  : '${playMultiplayerTask.current}/${playMultiplayerTask.target} Matches'),
          buttonLabel: isClaimingMulti
              ? 'CLAIMING...'
              : (playMultiplayerTask.status.isClaimed
                  ? 'CLAIMED'
                  : (playMultiplayerTask.status.isReady
                      ? 'CLAIM (+${playMultiplayerTask.rewardChips} CHIPS)'
                      : 'PLAY MATCH')),
          isClaimed: playMultiplayerTask.status.isClaimed,
          isHighlight: playMultiplayerTask.status.isReady && !isClaimingMulti,
          onPressed: playMultiplayerTask.status.isClaimed
              ? null
              : (playMultiplayerTask.status.isReady
                  ? () => _handleClaimTask(playMultiplayerTask.id)
                  : () => context.push(AppRoutes.multiplayerMenu)),
        ),
      ],
    );
  }

  Widget _buildMultiplayerRewardsSection(
    MatchRewardTask roomChampion,
    MatchRewardTask playFriends,
  ) {
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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      roomChampion.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
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
                                      '+${roomChampion.rewardChips}',
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
                                roomChampion.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTaskActionButton(
                    task: roomChampion,
                    defaultLabel: 'JOIN ROOM',
                    isDefaultNavy: true,
                    onDefaultTap: () => context.push(AppRoutes.multiplayerMenu),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Dynamic Progress Track
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
                          roomChampion.status.isClaimed
                              ? 'Claimed ✓'
                              : (roomChampion.status.isReady
                                  ? 'Ready to claim! (100%)'
                                  : 'In Progress (${(roomChampion.current / roomChampion.target * 100).round()}%)'),
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            color: roomChampion.status.isReady
                                ? AppColors.readyGreen
                                : AppColors.textMuted,
                            fontWeight: roomChampion.status.isReady
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${roomChampion.current}/${roomChampion.target} Wins',
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
                      child: LinearProgressIndicator(
                        value: roomChampion.target > 0
                            ? (roomChampion.current / roomChampion.target).clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(
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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      playFriends.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
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
                                      '+${playFriends.rewardChips}',
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
                                playFriends.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTaskActionButton(
                    task: playFriends,
                    defaultLabel: 'INVITE',
                    isDefaultNavy: false,
                    onDefaultTap: () => context.push(AppRoutes.multiplayerMenu),
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
                          playFriends.status.isClaimed
                              ? 'Claimed ✓'
                              : (playFriends.status.isReady
                                  ? 'Ready to claim! (100%)'
                                  : 'In Progress (${(playFriends.current / playFriends.target * 100).round()}%)'),
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            color: playFriends.status.isReady
                                ? AppColors.readyGreen
                                : AppColors.textMuted,
                            fontWeight: playFriends.status.isReady
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${playFriends.current}/${playFriends.target} Matches',
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
                      child: LinearProgressIndicator(
                        value: playFriends.target > 0
                            ? (playFriends.current / playFriends.target).clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(
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

  Widget _buildTaskActionButton({
    required MatchRewardTask task,
    required String defaultLabel,
    required bool isDefaultNavy,
    required VoidCallback onDefaultTap,
  }) {
    if (task.status.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          'CLAIMED ✓',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    if (task.status.isReady) {
      final isClaiming = _claimingTaskIds.contains(task.id);
      return InkWell(
        onTap: isClaiming ? null : () => _handleClaimTask(task.id),
        borderRadius: AppRadii.roundedFull,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.primaryCoral,
            borderRadius: AppRadii.roundedFull,
          ),
          child: Text(
            isClaiming ? 'CLAIMING...' : 'CLAIM (+${task.rewardChips})',
            style: AppTypography.labelSm.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: onDefaultTap,
      borderRadius: AppRadii.roundedFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDefaultNavy
              ? AppColors.primaryNavy
              : AppColors.surfaceContainer,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          defaultLabel,
          style: AppTypography.labelSm.copyWith(
            color: isDefaultNavy ? Colors.white : AppColors.primaryNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
            onTap: isClaimed ? null : onPressed,
            borderRadius: AppRadii.roundedFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isClaimed
                    ? AppColors.surfaceContainerHigh
                    : (isHighlight
                          ? AppColors.primaryCoral
                          : AppColors.surfaceContainerLow),
                borderRadius: AppRadii.roundedFull,
                border: isClaimed
                    ? Border.all(color: AppColors.structuralBorder)
                    : null,
              ),
              child: buttonLabel == 'CLAIMING...'
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isClaimed) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: AppColors.readyGreen,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isClaimed ? 'CLAIMED ✓' : buttonLabel,
                          style: AppTypography.labelSm.copyWith(
                            color: isClaimed
                                ? AppColors.textMuted
                                : (isHighlight
                                      ? Colors.white
                                      : AppColors.primaryNavy),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsPreviewBanner(List<Achievement> achievements) {
    final unlockedCount = achievements
        .where((a) => a.status.isClaimed || a.status.isReady)
        .length;
    final totalCount = achievements.isEmpty ? 28 : achievements.length;
    final totalAvailableChips = achievements
        .where((a) => !a.status.isClaimed)
        .fold(0, (sum, a) => sum + a.rewardChips);

    // Find next unlock in reach
    Achievement? nextUnlock;
    final inProgressList =
        achievements.where((a) => a.status.isInProgress).toList();
    if (inProgressList.isNotEmpty) {
      inProgressList.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
      nextUnlock = inProgressList.first;
    } else {
      final readyList = achievements.where((a) => a.status.isReady).toList();
      if (readyList.isNotEmpty) {
        nextUnlock = readyList.first;
      }
    }

    final nextTitle = nextUnlock != null
        ? '${nextUnlock.title} (${nextUnlock.current}/${nextUnlock.target})'
        : (achievements.isEmpty
            ? 'Play matches to unlock achievements'
            : 'All milestones reached!');
    final nextReward =
        nextUnlock != null ? '+${nextUnlock.rewardChips} CHIPS' : 'MAX LEVEL';

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
                    '$unlockedCount / $totalCount Unlocked • Up to +$totalAvailableChips Chips',
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
                Expanded(
                  child: Column(
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
                        nextTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                    nextReward,
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
