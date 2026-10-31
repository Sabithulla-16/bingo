import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/room_statistics.dart';
import 'room_statistics_notifier.dart';

/// Stitch Screen 15: Detailed Room Statistics & Match History
/// Reference: `projects/1917718787847945379/files/3d876d713b4f4007a8ca42fcf502e534`
class RoomStatisticsScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomStatisticsScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomStatisticsScreen> createState() =>
      _RoomStatisticsScreenState();
}

class _RoomStatisticsScreenState extends ConsumerState<RoomStatisticsScreen> {
  final Set<String> _expandedRounds = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomStatisticsNotifierProvider(widget.roomId));
    final notifier = ref.read(
      roomStatisticsNotifierProvider(widget.roomId).notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryCoral),
              )
            : Column(
                children: [
                  _buildHeader(context, state),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNarrativeHeader(state),
                          const SizedBox(height: 12),
                          _buildSegmentedTabBar(state, notifier),
                          const SizedBox(height: 14),
                          if (state.selectedTab ==
                              RoomStatisticsTab.leaderboard) ...[
                            _buildBentoQuickStats(state),
                            const SizedBox(height: 14),
                            _buildStandingsSection(state),
                          ] else ...[
                            _buildMatchHistorySection(state),
                          ],
                          const SizedBox(height: 16),
                          _buildBottomAction(context, state),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RoomStatisticsState state) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.primaryNavy,
                ),
                onPressed: () => Navigator.of(context).canPop()
                    ? Navigator.of(context).pop()
                    : context.go(AppRoutes.home),
                tooltip: 'Back',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: AppColors.primaryCoral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PRIVATE ROOM',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryCoral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'BINGO',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.softYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Text(
                'Room Statistics',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primaryNavy,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrativeHeader(RoomStatisticsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ROOM STATISTICS',
              style: AppTypography.labelSm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryCoral,
                letterSpacing: 1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 11,
                    color: AppColors.primaryCoral,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ROOM: ${state.roomCode}',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Friends & rankings',
          style: AppTypography.headlineLgMobile.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
        Text(
          "See who's leading and revisit your previous matches.",
          style: AppTypography.bodySm.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTabBar(
    RoomStatisticsState state,
    RoomStatisticsNotifier notifier,
  ) {
    final isLeaderboard = state.selectedTab == RoomStatisticsTab.leaderboard;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadii.roundedFull,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => notifier.switchTab(RoomStatisticsTab.leaderboard),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isLeaderboard
                      ? AppColors.primaryCoral
                      : Colors.transparent,
                  borderRadius: AppRadii.roundedFull,
                  boxShadow: isLeaderboard
                      ? [
                          BoxShadow(
                            color: AppColors.primaryCoral.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'LEADERBOARD',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isLeaderboard
                        ? Colors.white
                        : AppColors.primaryNavy.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => notifier.switchTab(RoomStatisticsTab.matchHistory),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isLeaderboard
                      ? AppColors.primaryCoral
                      : Colors.transparent,
                  borderRadius: AppRadii.roundedFull,
                  boxShadow: !isLeaderboard
                      ? [
                          BoxShadow(
                            color: AppColors.primaryCoral.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'MATCH HISTORY',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: !isLeaderboard
                        ? Colors.white
                        : AppColors.primaryNavy.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoQuickStats(RoomStatisticsState state) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUNDS',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.overview.totalRounds.toString().padLeft(2, '0'),
                  style: AppTypography.headlineLgMobile.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  'Completed',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAYERS',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.overview.activePlayers.toString().padLeft(2, '0'),
                  style: AppTypography.headlineLgMobile.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  'In Session',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDF9B),
              borderRadius: AppRadii.roundedLg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEADER',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5B4300),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.overview.leaderName,
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF251A00),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${state.overview.leaderWins} Wins',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5B4300),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStandingsSection(RoomStatisticsState state) {
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
                  'Overall Standings',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  'Performance across all completed rounds in ${state.roomCode}',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Text(
                '${state.standings.length} PLAYERS RANKED',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...state.standings.map(
          (standing) => _buildDetailedStandingCard(standing),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '* Tied players share rank based on equal wins, equal win rate, and equal best active streak.',
            style: AppTypography.bodySm.copyWith(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStandingCard(RoomPlayerStanding standing) {
    final isRank1 = standing.rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: standing.isYou
            ? AppColors.lightLavender.withValues(alpha: 0.3)
            : AppColors.surface,
        borderRadius: AppRadii.roundedLg,
        border: standing.isYou
            ? Border.all(
                color: AppColors.primaryCoral.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Stack(
                      children: [
                        PlayerAvatar(
                          displayName: standing.displayName,
                          size: 44,
                          backgroundColor: Color(
                            int.parse(
                              standing.avatarColorHex.replaceFirst('#', '0xFF'),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isRank1
                                  ? const Color(0xFFFFDF9B)
                                  : AppColors.primaryNavy,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${standing.rank}',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isRank1
                                    ? AppColors.primaryNavy
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                                  standing.displayName,
                                  style: AppTypography.headlineSm.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.primaryNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (standing.isYou) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCoral,
                                    borderRadius: AppRadii.roundedSm,
                                  ),
                                  child: Text(
                                    'YOU',
                                    style: AppTypography.labelSm.copyWith(
                                      fontSize: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              if (standing.isHost) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy,
                                    borderRadius: AppRadii.roundedSm,
                                  ),
                                  child: Text(
                                    'HOST',
                                    style: AppTypography.labelSm.copyWith(
                                      fontSize: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (isRank1) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFDF9B),
                                    borderRadius: AppRadii.roundedFull,
                                  ),
                                  child: Text(
                                    '👑 #1 LEADER',
                                    style: AppTypography.labelSm.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF5B4300),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${standing.currentStreak}-Win Streak 🔥',
                                  style: AppTypography.labelSm.copyWith(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              standing.rank == 2
                                  ? 'Tied 2nd Place *'
                                  : 'Rank #${standing.rank}',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${standing.winRate.toStringAsFixed(0)}%',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isRank1
                          ? AppColors.primaryCoral
                          : AppColors.primaryNavy,
                    ),
                  ),
                  Text(
                    'WIN RATE',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: LinearProgressIndicator(
              value: (standing.winRate / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isRank1 ? const Color(0xFFEDC157) : AppColors.primaryCoral,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Record: ${standing.roundsWon}W - ${standing.draws}D - ${standing.losses}L',
                style: AppTypography.bodySm.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                'Streak: ${standing.currentStreak}W (Best: ${standing.bestStreak}W)',
                style: AppTypography.bodySm.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (standing.wonRounds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Victor in:',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: standing.wonRounds.map((r) {
                      return Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isRank1
                              ? const Color(0xFFFFDF9B)
                              : Colors.white,
                          borderRadius: AppRadii.roundedFull,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          'R${r.toString().padLeft(2, '0')} ${isRank1 ? "🏆" : "⭐"}',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchHistorySection(RoomStatisticsState state) {
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
                  'Match Archive',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  'Detailed log of all completed rounds in ${state.roomCode}.',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
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
                '${state.history.length} ROUNDS RECORDED',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...state.history.map((record) => _buildExpandableRoundCard(record)),
      ],
    );
  }

  Widget _buildExpandableRoundCard(RoomRoundRecord record) {
    final isExpanded = _expandedRounds.contains(record.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.roundedLg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedRounds.remove(record.id);
                } else {
                  _expandedRounds.add(record.id);
                }
              });
            },
            borderRadius: AppRadii.roundedMd,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ROUND ${record.roundNumber.toString().padLeft(2, '0')}',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDF9B),
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Text(
                            'Winner: ${record.winnerName} 🏆',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.winnerName} Won • ${record.playerCount} Players • ${record.totalCalls} Called Numbers',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppColors.primaryNavy,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: AppColors.surfaceContainerHigh, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Winner: ${record.winnerName}',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Total Calls: ${record.totalCalls} / 25 calls',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedMd,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PARTICIPATING PLAYERS',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'LINES COMPLETED',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    color: AppColors.surfaceContainerHigh,
                    height: 10,
                  ),
                  ...record.playerOutcomes.map((p) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              PlayerAvatar(
                                displayName: p.displayName,
                                size: 20,
                                backgroundColor: Color(
                                  int.parse(
                                    p.avatarColorHex.replaceFirst('#', '0xFF'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.displayName,
                                style: AppTypography.labelSm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.isWinner
                                  ? const Color(0xFFFFDF9B)
                                  : AppColors.surfaceContainerHigh,
                              borderRadius: AppRadii.roundedSm,
                            ),
                            child: Text(
                              p.isWinner
                                  ? '5/5 Lines • B-I-N-G-O Winner 🏆'
                                  : '${p.linesClaimedCount}/5 Lines',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 11,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Player private boards and unmarked numbers remain confidential.',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, RoomStatisticsState state) {
    return Column(
      children: [
        PrimaryButton(
          label: 'BACK TO ROOM LOBBY',
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go(AppRoutes.multiplayerLobbyPath(state.roomId)),
        ),
        const SizedBox(height: 8),
        Text(
          'Room code ${state.roomCode} • Cumulative match records remain saved for all participants.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
