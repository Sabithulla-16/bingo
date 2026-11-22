import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../presentation/opponent_found_notifier.dart';

/// Quick Match Opponent Found Screen (Stitch Screen ID: `e1110943fe5e4adc96a7b38c64fff876`)
///
/// Displays the locked 1v1 matchup and authoritative 10-second synchronized countdown.
class OpponentFoundScreen extends ConsumerStatefulWidget {
  final String matchId;

  const OpponentFoundScreen({super.key, required this.matchId});

  @override
  ConsumerState<OpponentFoundScreen> createState() => _OpponentFoundScreenState();
}

class _OpponentFoundScreenState extends ConsumerState<OpponentFoundScreen> {
  bool _hasNavigated = false;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(opponentFoundProvider(widget.matchId));

    // Listen for authoritative server transition into Board Preparation
    ref.listen<OpponentFoundState>(opponentFoundProvider(widget.matchId), (prev, next) {
      if (next.shouldNavigateToBoardPrep && next.match != null && !_hasNavigated) {
        _hasNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go(AppRoutes.multiplayerBoardPrepPath(next.match!.roomId));
          }
        });
      }
    });

    return ResponsiveScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context, state),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status & Match Announcement Hero
                    _buildHeroSection(),
                    const SizedBox(height: 14),

                    // Player Matchup Card (Centerpiece Versus Arena)
                    _buildVersusArena(state),
                    const SizedBox(height: 12),

                    // Match Details Card (Mode, Players, Connection)
                    _buildMatchDetailsCard(),
                    const SizedBox(height: 10),

                    // Match Rules Summary Chips
                    _buildRulesChips(),
                    const SizedBox(height: 14),

                    // Ready Status & Synchronizing Card
                    _buildSynchronizingCard(),
                    const SizedBox(height: 16),

                    // Interactive Action Area (10-Second Authoritative Countdown)
                    _buildCountdownCard(state),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, OpponentFoundState state) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(200),
        border: const Border(
          bottom: BorderSide(color: Color(0x0A000000)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1C1B)),
            tooltip: 'Leave match',
            onPressed: _handleBack,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Text(
                    'BINGO',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Color(0xFF20243A),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    left: 6,
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
                    top: -4,
                    right: 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB2B9F8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    left: 28,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD166),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'QUICK MATCH',
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B873F),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'ONLINE',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF1A1C1B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PlayerAvatar(
                displayName: state.currentUserName,
                size: 32,
                backgroundColor: Color(
                  int.tryParse(state.currentUserAvatarColor.replaceFirst('#', '0xFF')) ??
                      0xFF20243A,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDAD6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Color(0xFFAE3029),
              ),
              SizedBox(width: 6),
              Text(
                'MATCH FOUND',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Color(0xFF410002),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Opponent Found!',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B0F24),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Your next BINGO challenge is locked and ready.',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            color: Color(0xFF46464D),
          ),
        ),
      ],
    );
  }

  Widget _buildVersusArena(OpponentFoundState state) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background geometric circles matching Stitch
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFDEE1FE).withAlpha(60),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -15,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDF9B).withAlpha(80),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Player 1 (You)
              SizedBox(
                width: 100,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDEE1FE),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFDEE1FE),
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: PlayerAvatar(
                            displayName: state.currentUserName,
                            size: 58,
                            backgroundColor: Color(
                              int.tryParse(state.currentUserAvatarColor.replaceFirst('#', '0xFF')) ??
                                  0xFF20243A,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B873F),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.currentUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B0F24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEE1FE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF161A30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // VS Divider Badge
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(width: 14, height: 2, color: const Color(0xFFE8E8E5)),
                      const SizedBox(width: 4),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF20243A),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: Color(0xFFEDC157),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(width: 14, height: 2, color: const Color(0xFFE8E8E5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1 VS 1',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFF46464D),
                    ),
                  ),
                ],
              ),

              // Player 2 (Opponent)
              SizedBox(
                width: 100,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDAD6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFDAD6),
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: PlayerAvatar(
                            displayName: state.opponentName,
                            size: 58,
                            backgroundColor: Color(
                              int.tryParse(state.opponentAvatarColor.replaceFirst('#', '0xFF')) ??
                                  0xFFAE3029,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B873F),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.opponentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B0F24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'OPPONENT',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF46464D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchDetailsCard() {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildDetailCell(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFF0B0F24),
              label: 'MODE',
              value: 'Quick Match',
              valueColor: const Color(0xFF0B0F24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDetailCell(
              icon: Icons.group_rounded,
              iconColor: const Color(0xFF0B0F24),
              label: 'PLAYERS',
              value: '2 Online',
              valueColor: const Color(0xFF0B0F24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDetailCell(
              icon: Icons.wifi_rounded,
              iconColor: const Color(0xFF1B873F),
              label: 'CONNECTION',
              value: 'Connected',
              valueColor: const Color(0xFF1B873F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCell({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF77767D),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildRulePill(Icons.timer_outlined, 'Board Preparation: 30s'),
        _buildRulePill(Icons.hourglass_top_rounded, 'Turn Time: 20s'),
        _buildRulePill(Icons.grid_view_rounded, '5×5 Matrix · Numbers 1–25'),
      ],
    );
  }

  Widget _buildRulePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF0B0F24)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF46464D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynchronizingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1B873F).withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync_rounded,
              color: Color(0xFF1B873F),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Both Players Connected',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B0F24),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B873F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Preparing your match...',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: Color(0xFF46464D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(OpponentFoundState state) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          const Text(
            'MATCH STARTING IN',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF46464D),
            ),
          ),
          const SizedBox(height: 12),

          // Big Coral Countdown Circle (96x96 matching Stitch)
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFFFDAD6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${state.remainingSeconds}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: Color(0xFFAE3029),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'SECONDS',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFFAE3029),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get ready! Your match is about to begin.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1C1B),
            ),
          ),
          const SizedBox(height: 14),

          // Smooth Progress Bar
          Container(
            width: 200,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDAD6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: state.progressFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFAE3029),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
