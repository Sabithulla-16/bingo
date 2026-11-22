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
import '../../../core/widgets/victory_effect_overlay.dart';
import '../../room_statistics/domain/room_statistics.dart';
import '../../store/data/store_repository.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../achievements/data/achievements_repository.dart';
import '../../earn_chips/data/rewards_repository.dart';
import '../../profile/domain/player_career_stats.dart';
import '../domain/room.dart';
import '../data/multiplayer_repository_provider.dart';
import '../presentation/multiplayer_result_notifier.dart';

/// Stitch Screen 14: Multiplayer Match Result & Room Leaderboard
/// Reference: `projects/1917718787847945379/files/16101061057795612716`
class MultiplayerResultScreen extends ConsumerStatefulWidget {
  final String roomId;

  const MultiplayerResultScreen({super.key, required this.roomId});

  @override
  ConsumerState<MultiplayerResultScreen> createState() =>
      _MultiplayerResultScreenState();
}

class _MultiplayerResultScreenState
    extends ConsumerState<MultiplayerResultScreen> {
  static final Set<String> _recordedRooms = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordMultiplayerResultOnce();
    });
  }

  Future<void> _recordMultiplayerResultOnce() async {
    final state = ref.read(multiplayerResultNotifierProvider(widget.roomId));
    final matchKey = '${widget.roomId}_round_${state.roundNumber}';
    if (_recordedRooms.contains(matchKey)) return;
    _recordedRooms.add(matchKey);

    final userId = ref.read(authRepositoryProvider).currentUserId ?? 'guest';
    final isVictory = state.isYouWinner;
    final outcome = isVictory ? MatchOutcome.victory : MatchOutcome.defeat;
    final myOutcome = state.playerResults.firstWhere(
      (p) => p.isYou || p.userId == userId,
      orElse: () => const RoundPlayerOutcome(userId: '', displayName: ''),
    );
    final linesClaimed = myOutcome.linesClaimedCount;
    final callsCount = state.totalCalls;

    // 1. Authoritative career stats update:
    // Only record client-side career stats if offline. In online multiplayer,
    // server-authoritative RPCs (rpc_claim_line / rpc_forfeit_match) atomically
    // update player_statistics in Supabase.
    final multiRepo = ref.read(multiplayerRepositoryProvider);
    if (!multiRepo.isOnline) {
      await ref
          .read(profileRepositoryProvider)
          .recordMatchResult(
            userId: userId,
            outcome: outcome,
            linesClaimed: linesClaimed,
            callsCount: callsCount,
            isMultiplayer: true,
          );
    }

    // 2. Rewards repository update
    await ref
        .read(rewardsRepositoryProvider)
        .recordMatchCompleted(isWinner: isVictory, isMultiplayer: true);

    // 3. Update Achievements
    final achRepo = ref.read(achievementsRepositoryProvider);
    final stats = await ref
        .read(profileRepositoryProvider)
        .getCareerStats(userId);

    await achRepo.evaluateFromStats(
      stats,
      isMultiplayer: true,
      isVictory: isVictory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerResultNotifierProvider(widget.roomId));
    final notifier = ref.read(
      multiplayerResultNotifierProvider(widget.roomId).notifier,
    );
    final customization = ref.watch(playerCustomizationProvider);

    // Watch for host starting next round or returning to lobby
    ref.listen<MultiplayerResultState>(
      multiplayerResultNotifierProvider(widget.roomId),
      (previous, next) {
        if (previous == null || previous.isLoading || next.isLoading) return;

        // If the match ended due to forfeit, never auto-advance to board prep
        if (next.isForfeit) return;

        // If current user is recorded as forfeited, navigate Home immediately
        final userOutcome = next.playerResults.where((p) => p.isYou).firstOrNull;
        if (userOutcome?.isForfeited == true) {
          context.go(AppRoutes.home);
          return;
        }

        final roundIncremented =
            next.roundNumber > previous.roundNumber && previous.roundNumber > 0;
        final statusChangedToPrep = next.roomStatus == RoomStatus.preparing &&
            previous.roomStatus != RoomStatus.preparing;
        final statusChangedToWaiting = next.roomStatus == RoomStatus.waiting &&
            previous.roomStatus != RoomStatus.waiting;

        if (roundIncremented || statusChangedToPrep) {
          try {
            context.go(AppRoutes.multiplayerBoardPrepPath(widget.roomId));
          } catch (_) {}
        } else if (statusChangedToWaiting) {
          try {
            context.go(AppRoutes.roomLobbyPath(widget.roomId));
          } catch (_) {}
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
                          _buildMatchResultHero(state, customization),
                          const SizedBox(height: 12),
                          _buildFinalMatchResultsCard(state, customization),
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

  Widget _buildMatchResultHero(
    MultiplayerResultState state,
    dynamic customization,
  ) {
    final isYou = state.isYouWinner;
    final winnerName = state.winnerName;

    return VictoryEffectOverlay(
      isGoldenBurst: isYou && (customization.hasGoldenBurst as bool? ?? false),
      child: AppCard(
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
                    state.isForfeit
                        ? (isYou
                            ? 'OPPONENT FORFEITED • YOU WON!'
                            : 'MATCH FORFEITED')
                        : (isYou
                            ? 'YOU WON THE ROUND!'
                            : '${winnerName.toUpperCase()} WON THE ROUND'),
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
              state.isForfeit
                  ? (isYou ? 'VICTORY BY FORFEIT!' : 'MATCH FORFEITED')
                  : (isYou ? 'VICTORY!' : '${winnerName.toUpperCase()} WON!'),
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
                state.isForfeit
                    ? (isYou
                        ? 'Your opponent forfeited the ongoing match. Victory and rewards have been awarded to you!'
                        : 'The match concluded due to player forfeiture.')
                    : (isYou
                        ? 'Outstanding game! You completed BINGO ahead of all opponents!'
                        : '$winnerName completed BINGO before everyone else. Great match and close board finish!'),
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
      ),
    );
  }

  Widget _buildFinalMatchResultsCard(
    MultiplayerResultState state,
    dynamic customization,
  ) {
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
          ...state.playerResults.map(
            (player) => _buildPlayerResultRow(player, customization),
          ),
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

  Widget _buildPlayerResultRow(
    RoundPlayerOutcome player,
    dynamic customization,
  ) {
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
                      avatarId: player.isYou ? customization.avatarId : null,
                      hasGoldenFrame: player.isYou
                          ? customization.hasGoldenFrame
                          : false,
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
                      : 'Waiting for host to launch next round or return to room...',
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
              icon: Icons.replay_rounded,
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
            SecondaryButton(
              label: 'BACK TO ROOM LOBBY',
              icon: Icons.meeting_room_rounded,
              onPressed: () => notifier.returnToLobby(),
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
            onPressed: () async {
              await notifier.leaveRoom();
              if (context.mounted) {
                context.go(AppRoutes.home);
              }
            },
            child: Text(
              'LEAVE ROOM & RETURN HOME',
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
