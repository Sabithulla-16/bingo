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
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../domain/quick_match_rematch.dart';
import '../presentation/quick_match_result_notifier.dart';

class QuickMatchResultScreen extends ConsumerStatefulWidget {
  final String matchId;

  const QuickMatchResultScreen({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<QuickMatchResultScreen> createState() =>
      _QuickMatchResultScreenState();
}

class _QuickMatchResultScreenState
    extends ConsumerState<QuickMatchResultScreen> {
  bool _hasNavigatedToRematch = false;

  void _handleLeaveToHome() async {
    final notifier =
        ref.read(quickMatchResultProvider(widget.matchId).notifier);
    await notifier.cleanUpOnLeaveHome();
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickMatchResultProvider(widget.matchId));
    final notifier =
        ref.read(quickMatchResultProvider(widget.matchId).notifier);
    final currentUserId = ref.watch(authRepositoryProvider).currentUserId ?? '';

    // Auto-navigate when rematch is accepted
    ref.listen<QuickMatchResultState>(
      quickMatchResultProvider(widget.matchId),
      (prev, next) {
        if (next.newMatchIdToNavigate != null &&
            !_hasNavigatedToRematch &&
            mounted) {
          _hasNavigatedToRematch = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go(
                AppRoutes.quickMatchOpponentFoundPath(
                    next.newMatchIdToNavigate!),
              );
            }
          });
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleLeaveToHome();
        }
      },
      child: ResponsiveScaffold(
        scrollable: false,
        padding: EdgeInsets.zero,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopAppBar(context),
              Expanded(
                child: state.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCoral,
                        ),
                      )
                    : state.errorMessage != null
                        ? _buildErrorView(state.errorMessage!)
                        : _buildResultBody(state, notifier, currentUserId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE4E1E9), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF1A1C1B)),
            tooltip: 'Back to Home',
            onPressed: _handleLeaveToHome,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Text(
                    'BINGO',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Color(0xFF20243A),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    left: 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B5E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -3,
                    right: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB2B9F8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'QUICK MATCH 1V1 RESULT',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF20243A).withAlpha(150),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, color: Color(0xFF1A1C1B)),
            tooltip: 'Home',
            onPressed: _handleLeaveToHome,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.primaryCoral, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load match summary',
              style: AppTypography.headlineSm,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'BACK TO HOME',
              onPressed: _handleLeaveToHome,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBody(
    QuickMatchResultState state,
    QuickMatchResultNotifier notifier,
    String currentUserId,
  ) {
    final result = state.resultData;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final isVictory = result.isVictory(currentUserId);
    final isDraw = result.isDraw(currentUserId);
    final myResult = result.myResult(currentUserId);
    final oppResult = result.opponentResult(currentUserId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Result Outcome Hero
          _buildOutcomeHero(isVictory, isDraw, myResult, oppResult),
          const SizedBox(height: 16),

          // 2. Versus Arena Card (YOU vs OPPONENT)
          _buildVersusArenaCard(myResult, oppResult),
          const SizedBox(height: 14),

          // 3. Match Telemetry & Statistics Card
          _buildMatchStatsCard(result),
          const SizedBox(height: 14),

          // 4. Rematch Request Area (If pending or active)
          if (state.hasActivePendingRequest) ...[
            _buildRematchActiveCard(state, notifier, currentUserId),
            const SizedBox(height: 14),
          ],

          // Notice banner (if any)
          if (state.rematchNotice != null) ...[
            _buildRematchNoticeBanner(state.rematchNotice!),
            const SizedBox(height: 14),
          ],

          // 5. Main Action Buttons (REMATCH & BACK TO HOME only!)
          _buildActionButtons(state, notifier, isVictory),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOutcomeHero(
    bool isVictory,
    bool isDraw,
    QuickMatchParticipantResult myResult,
    QuickMatchParticipantResult oppResult,
  ) {
    Color bannerColor;
    String title;
    String subtitle;
    IconData icon;

    if (myResult.isForfeited) {
      bannerColor = AppColors.primaryCoral;
      title = 'DEFEAT (FORFEIT)';
      subtitle = 'You forfeited the match.';
      icon = Icons.flag_rounded;
    } else if (oppResult.isForfeited) {
      bannerColor = AppColors.readyGreen;
      title = 'VICTORY!';
      subtitle = 'Opponent forfeited the match.';
      icon = Icons.emoji_events_rounded;
    } else if (isVictory) {
      bannerColor = AppColors.readyGreen;
      title = 'VICTORY!';
      subtitle = 'You completed 5 lines and won the 1v1 Quick Match!';
      icon = Icons.emoji_events_rounded;
    } else if (isDraw) {
      bannerColor = AppColors.softYellowDark;
      title = 'DRAW';
      subtitle = 'Match concluded with tied scores!';
      icon = Icons.handshake_rounded;
    } else {
      bannerColor = const Color(0xFF6C757D);
      title = 'DEFEAT';
      subtitle = 'Your opponent completed 5 lines first.';
      icon = Icons.sentiment_dissatisfied_rounded;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bannerColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: bannerColor, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: bannerColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF5D5F65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primaryCoral;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return AppColors.primaryCoral;
  }

  Widget _buildVersusArenaCard(
    QuickMatchParticipantResult myResult,
    QuickMatchParticipantResult oppResult,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left: YOU
          Expanded(
            child: Column(
              children: [
                PlayerAvatar(
                  displayName: myResult.displayName,
                  size: 52,
                  backgroundColor: _parseColor(myResult.avatarColorHex),
                  textColor: Colors.white,
                ),
                const SizedBox(height: 6),
                Text(
                  myResult.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF161A30),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'YOU',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLinesBadge(myResult.linesClaimed),
              ],
            ),
          ),

          // Center: VS Badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFECEEF2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'VS',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF161A30),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '1v1',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF77767D),
                ),
              ),
            ],
          ),

          // Right: OPPONENT
          Expanded(
            child: Column(
              children: [
                PlayerAvatar(
                  displayName: oppResult.displayName,
                  size: 52,
                  backgroundColor: _parseColor(oppResult.avatarColorHex),
                  textColor: Colors.white,
                ),
                const SizedBox(height: 6),
                Text(
                  oppResult.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF161A30),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'OPPONENT',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryCoral,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLinesBadge(oppResult.linesClaimed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinesBadge(int lines) {
    final isMax = lines >= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMax
            ? AppColors.readyGreen.withAlpha(25)
            : const Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMax ? AppColors.readyGreen : const Color(0xFFD6D8DE),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMax ? Icons.stars_rounded : Icons.linear_scale_rounded,
            size: 13,
            color: isMax ? AppColors.readyGreen : const Color(0xFF5D5F65),
          ),
          const SizedBox(width: 4),
          Text(
            '$lines / 5 Lines',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMax ? AppColors.readyGreen : const Color(0xFF161A30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchStatsCard(QuickMatchResultData result) {
    final durationMin = result.durationSeconds ~/ 60;
    final durationSec = result.durationSeconds % 60;
    final durationStr =
        '${durationMin}m ${durationSec.toString().padLeft(2, '0')}s';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 18, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              Text(
                'Match Statistics',
                style: AppTypography.headlineSm.copyWith(fontSize: 14),
              ),
              const Spacer(),
              const StatusBadge(
                label: 'OFFICIAL 1V1',
                backgroundColor: Color(0xFFE8EAF6),
                textColor: Color(0xFF161A30),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatTile(
                icon: Icons.timer_outlined,
                label: 'DURATION',
                value: durationStr,
              ),
              const SizedBox(width: 12),
              _buildStatTile(
                icon: Icons.tag_rounded,
                label: 'NUMBERS CALLED',
                value: '${result.totalCalls}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatTile(
                icon: Icons.grid_view_rounded,
                label: 'GRID FORMAT',
                value: 'Classic 5x5',
              ),
              const SizedBox(width: 12),
              _buildStatTile(
                icon: Icons.speed_rounded,
                label: 'TURN PACE',
                value: '20s / Turn',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4E6ED)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF77767D)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF77767D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF161A30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRematchActiveCard(
    QuickMatchResultState state,
    QuickMatchResultNotifier notifier,
    String currentUserId,
  ) {
    final req = state.pendingRematch!;
    final isRequester = state.isRequester(currentUserId);
    final oppName = req.opponent?.displayName ?? 'Opponent';

    if (isRequester) {
      // Caller sent the request -> waiting for opponent
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB2B9F8), width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Waiting for opponent...',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF161A30),
                        ),
                      ),
                      Text(
                        'Rematch request sent to $oppName. Expiring in ${state.rematchSecondsRemaining}s',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: Color(0xFF5D5F65),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => notifier.cancelRematch(),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryCoral,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Opponent requested rematch -> Show Accept / Decline card
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB4A8), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFECE8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sports_kabaddi_rounded,
                    color: AppColors.primaryCoral,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rematch Request!',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF161A30),
                        ),
                      ),
                      Text(
                        '$oppName wants to play another round! (${state.rematchSecondsRemaining}s remaining)',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: Color(0xFF5D5F65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'DECLINE',
                    isLoading: state.isRespondingRematch,
                    onPressed: () => notifier.declineRematch(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'ACCEPT REMATCH',
                    isLoading: state.isRespondingRematch,
                    backgroundColor: AppColors.primaryCoral,
                    onPressed: () => notifier.acceptRematch(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRematchNoticeBanner(String notice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCDFE7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFF5D5F65)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notice,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: Color(0xFF20243A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    QuickMatchResultState state,
    QuickMatchResultNotifier notifier,
    bool isVictory,
  ) {
    final hasActiveReq = state.hasActivePendingRequest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasActiveReq) ...[
          PrimaryButton(
            label: state.isSendingRematch ? 'SENDING REQUEST...' : 'REMATCH',
            icon: Icons.replay_rounded,
            backgroundColor: AppColors.primaryCoral,
            isLoading: state.isSendingRematch,
            onPressed: () => notifier.sendRematchRequest(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Both players must accept to start a rematch.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: Color(0xFF77767D),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SecondaryButton(
          label: 'BACK TO HOME',
          icon: Icons.home_rounded,
          onPressed: _handleLeaveToHome,
        ),
      ],
    );
  }
}
