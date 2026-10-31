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
import '../../../core/widgets/secondary_button.dart';
import '../../room_statistics/domain/room_statistics.dart';
import '../presentation/multiplayer_result_notifier.dart';

/// Stitch Screen 14: Multiplayer Match Result & Room Leaderboard
/// Reference: `projects/1917718787847945379/files/16101061057795612716`
class MultiplayerResultScreen extends ConsumerWidget {
  final String roomId;

  const MultiplayerResultScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multiplayerResultNotifierProvider(roomId));
    final notifier = ref.read(
      multiplayerResultNotifierProvider(roomId).notifier,
    );

    // Watch for host starting next round: automatically navigate to board prep
    ref.listen<MultiplayerResultState>(
      multiplayerResultNotifierProvider(roomId),
      (previous, next) {
        if (previous != null && next.roundNumber > previous.roundNumber) {
          context.go(AppRoutes.multiplayerBoardPrepPath(roomId));
        }
      },
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
                          _buildRoomContextBanner(state),
                          const SizedBox(height: 12),
                          _buildMatchResultHero(state),
                          const SizedBox(height: 12),
                          _buildFinalMatchResultsCard(state),
                          const SizedBox(height: 12),
                          _buildMatchOverviewCard(state),
                          const SizedBox(height: 12),
                          _buildLeaderboardPreviewCard(context, state),
                          const SizedBox(height: 12),
                          _buildRecentMatchHistoryCard(context, state),
                          const SizedBox(height: 16),
                          _buildBottomActionArea(context, state, notifier),
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

  Widget _buildHeader(BuildContext context, MultiplayerResultState state) {
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
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primaryNavy,
            ),
            onPressed: () => context.go(AppRoutes.home),
            tooltip: 'Leave Match',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryCoral,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'BINGO',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.softYellow,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ROOM: ',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  state.roomCode,
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomContextBanner(MultiplayerResultState state) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  state.roomName.toUpperCase(),
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  'ROOM: ${state.roomCode}',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryCoral,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  'ROUND ${state.roundNumber.toString().padLeft(2, '0')} COMPLETED',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchResultHero(MultiplayerResultState state) {
    final isYou = state.isYouWinner;
    final winnerName = state.winnerName;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // Minimalist Confetti / Starburst Graphic
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isYou
                      ? const Color(0xFFFFDF9B)
                      : const Color(0xFFFFDF9B),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDC157),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.primaryNavy,
                  size: 36,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryCoral,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.lightLavender,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDF9B),
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 14,
                  color: AppColors.primaryNavy,
                ),
                const SizedBox(width: 4),
                Text(
                  isYou
                      ? 'YOU WON THE ROUND!'
                      : '${winnerName.toUpperCase()} WON THE ROUND',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isYou ? 'VICTORY!' : '${winnerName.toUpperCase()} WON!',
            style: AppTypography.displayHeroMobile.copyWith(
              color: AppColors.primaryNavy,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isYou
                  ? 'Outstanding game! You completed BINGO ahead of all opponents!'
                  : '$winnerName completed BINGO before everyone else. Great match and close board finish!',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
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
                const SizedBox(width: 6),
                Text(
                  'Finished on Call #${state.totalCalls}',
                  style: AppTypography.bodySm.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 6),
                const Text(
                  '•',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  '${state.playerResults.length} Players Active',
                  style: AppTypography.bodySm.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalMatchResultsCard(MultiplayerResultState state) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FINAL MATCH RESULTS',
            style: AppTypography.headlineSm.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Final cards and line counts at match conclusion',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          ...state.playerResults.map((player) => _buildPlayerResultRow(player)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "Opponents' private board layouts remain confidential.",
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerResultRow(RoundPlayerOutcome player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: player.isYou
            ? AppColors.lightLavender.withValues(alpha: 0.3)
            : AppColors.surfaceContainerLow,
        borderRadius: AppRadii.roundedMd,
        border: player.isYou
            ? Border.all(
                color: AppColors.primaryCoral.withValues(alpha: 0.5),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    PlayerAvatar(
                      displayName: player.displayName,
                      size: 34,
                      backgroundColor: Color(
                        int.parse(
                          player.avatarColorHex.replaceFirst('#', '0xFF'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  player.displayName,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (player.isYou) ...[
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
                                    'YOU',
                                    style: AppTypography.labelSm.copyWith(
                                      fontSize: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              if (player.isHost) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHigh,
                                    borderRadius: AppRadii.roundedSm,
                                  ),
                                  child: Text(
                                    'HOST',
                                    style: AppTypography.labelSm.copyWith(
                                      fontSize: 8,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            player.isWinner
                                ? 'Completed BINGO first'
                                : '${5 - player.linesClaimedCount} line away from Bingo!',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 10,
                              color: player.isWinner
                                  ? AppColors.readyGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: player.isWinner
                      ? const Color(0xFFFFDF9B)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  player.isWinner ? 'WINNER 🏆' : 'DEFEATED',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: player.isWinner
                        ? AppColors.primaryNavy
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: ['B', 'I', 'N', 'G', 'O'].map((letter) {
                  final isClaimed = player.claimedLetters.contains(letter);
                  return Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: isClaimed ? AppColors.primaryCoral : Colors.white,
                      borderRadius: AppRadii.roundedSm,
                      border: isClaimed
                          ? null
                          : Border.all(color: AppColors.surfaceContainerHigh),
                      boxShadow: isClaimed
                          ? [
                              BoxShadow(
                                color: AppColors.primaryCoral.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: isClaimed
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              Text(
                '${player.linesClaimedCount} / 5 Lines',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchOverviewCard(MultiplayerResultState state) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MATCH OVERVIEW',
            style: AppTypography.labelSm.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _buildBentoItem('ROOM', state.roomName),
              _buildBentoItem(
                'ROUND',
                'Round ${state.roundNumber.toString().padLeft(2, '0')}',
              ),
              _buildBentoItem(
                'NUMBERS CALLED',
                '${state.totalCalls} / 25 Calls',
              ),
              _buildBentoItem(
                'YOUR OUTCOME',
                state.isYouWinner ? 'VICTORY' : 'DEFEAT',
                color: state.isYouWinner
                    ? AppColors.readyGreen
                    : AppColors.primaryCoral,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoItem(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadii.roundedMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.primaryNavy,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardPreviewCard(
    BuildContext context,
    MultiplayerResultState state,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ROOM LEADERBOARD',
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightLavender,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  '${state.roundNumber} ROUNDS TOTAL',
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
            'Overall performance across all rounds in ${state.roomCode}',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          ...state.leaderboard.map((standing) => _buildStandingRow(standing)),
          const SizedBox(height: 8),
          Text(
            '* Tied players share rank based on total wins, win percentage, and best active streak.',
            style: AppTypography.bodySm.copyWith(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingRow(RoomPlayerStanding standing) {
    final isFirst = standing.rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: standing.isYou
            ? AppColors.lightLavender.withValues(alpha: 0.3)
            : AppColors.surfaceContainerLow,
        borderRadius: AppRadii.roundedMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? const Color(0xFFFFDF9B)
                            : AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${standing.rank}',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        standing.displayName,
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFirst) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 16,
                        color: Color(0xFFEDC157),
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
                          color: AppColors.primaryCoral,
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
              ),
              Text(
                '${standing.winRate.toStringAsFixed(0)}% Win Rate',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${standing.roundsPlayed} Rounds • ${standing.roundsWon}W ${standing.losses}L',
                style: AppTypography.bodySm.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Best Streak: ${standing.bestStreak}W',
                style: AppTypography.bodySm.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: LinearProgressIndicator(
              value: (standing.winRate / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFirst ? const Color(0xFFEDC157) : AppColors.primaryCoral,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMatchHistoryCard(
    BuildContext context,
    MultiplayerResultState state,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT MATCH HISTORY',
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              InkWell(
                onTap: () =>
                    context.push(AppRoutes.roomStatisticsPath(state.roomId)),
                borderRadius: AppRadii.roundedSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VIEW ALL (${state.recentMatches.length})',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryCoral,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.primaryCoral,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...state.recentMatches.take(3).map((record) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'R${record.roundNumber}',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record.winnerName} Won 🏆',
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${record.totalCalls} Calls • ${record.playerCount} Players',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                      'Just now',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
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
    );
  }

  Widget _buildBottomActionArea(
    BuildContext context,
    MultiplayerResultState state,
    MultiplayerResultNotifier notifier,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
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
                const SizedBox(width: 6),
                Text(
                  state.isHost
                      ? 'Host Controls Active • Code ${state.roomCode} preserved'
                      : 'Waiting for host to launch next round...',
                  style: AppTypography.labelSm.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (state.isHost) ...[
            PrimaryButton(
              label: state.isStartingNextRound
                  ? 'PREPARING ROUND ${(state.roundNumber + 1).toString().padLeft(2, '0')}...'
                  : 'START NEXT ROUND',
              icon: Icons.arrow_forward_rounded,
              isLoading: state.isStartingNextRound,
              onPressed: () => notifier.startNextRound(),
            ),
            const SizedBox(height: 6),
            Text(
              'Takes all players directly into Round ${(state.roundNumber + 1).toString().padLeft(2, '0')} Board Preparation.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SecondaryButton(
            label: 'VIEW DETAILED ROOM STATS',
            icon: Icons.bar_chart_rounded,
            onPressed: () =>
                context.push(AppRoutes.roomStatisticsPath(state.roomId)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(
              'RETURN TO MAIN MENU',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
