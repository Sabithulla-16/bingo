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
import '../presentation/quick_match_notifier.dart';
import 'quick_match_matrix.dart';

/// Quick Match Finding Opponent Screen (Stitch Screen ID: `183fab299da247d480d700008e8f863c`)
///
/// Features two authoritative internal states:
/// - State A: IDLE (Static decorative board, game info, START SEARCHING)
/// - State B: SEARCHING (Authoritative queue entry, animated matrix, elapsed timer, CANCEL SEARCH)
class QuickMatchScreen extends ConsumerStatefulWidget {
  const QuickMatchScreen({super.key});

  @override
  ConsumerState<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends ConsumerState<QuickMatchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused || appState == AppLifecycleState.detached) {
      final state = ref.read(quickMatchProvider);
      if (state.isSearching) {
        ref.read(quickMatchProvider.notifier).cancelSearching();
      }
    }
  }

  void _handleBack() {
    final notifier = ref.read(quickMatchProvider.notifier);
    final state = ref.read(quickMatchProvider);
    if (state.isSearching) {
      notifier.cancelSearching();
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickMatchProvider);
    final notifier = ref.read(quickMatchProvider.notifier);

    // Auto-navigate to Opponent Found when match is confirmed
    ref.listen<QuickMatchState>(quickMatchProvider, (prev, next) {
      if (next.isIdle) {
        _hasNavigated = false;
      }
      if (next.isMatched && next.matchId != null && !_hasNavigated) {
        _hasNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go(AppRoutes.quickMatchOpponentFoundPath(next.matchId!));
          }
        });
      }
    });

    return PopScope(
      canPop: !state.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: ResponsiveScaffold(
        scrollable: false,
        padding: EdgeInsets.zero,
        body: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              _buildTopAppBar(context, state),

              Expanded(
                child: state.isGuest
                    ? _buildGuestRestrictionView(context)
                    : _buildMainContent(context, state, notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, QuickMatchState state) {
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
            tooltip: 'Back',
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
                  color: AppColors.surfaceContainer,
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
                displayName: state.currentUserDisplayName,
                size: 32,
                backgroundColor: Color(
                  int.tryParse(state.currentUserAvatarColorHex.replaceFirst('#', '0xFF')) ??
                      0xFF20243A,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    QuickMatchState state,
    QuickMatchNotifier notifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eyebrow & Dynamic Main Heading
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDEE1FE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public, size: 14, color: Color(0xFF161A30)),
                  SizedBox(width: 6),
                  Text(
                    'ONLINE MATCHMAKING',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF161A30),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.isSearching ? 'Finding your opponent...' : 'Ready for a challenge?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B0F24),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            state.isSearching
                ? 'Searching for available players'
                : 'Find a player online and compete for the BINGO!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF46464D),
            ),
          ),
          const SizedBox(height: 16),

          // Match Type Summary Card
          _buildSummaryCard(state),
          const SizedBox(height: 14),

          // Central Matchmaking Stage (YOU vs MATRIX vs OPPONENT)
          _buildCentralMatchmakingStage(state),
          const SizedBox(height: 14),

          // State Status / Timer Container
          _buildStatusAndTimerSection(state),
          const SizedBox(height: 14),

          // Dynamic Telemetry Cards (Visible in Searching)
          if (state.isSearching) ...[
            _buildTelemetryCards(state),
            const SizedBox(height: 14),
          ],

          // Idle Extra Info Card (Visible in Idle)
          if (state.isIdle) ...[
            _buildIdleInfoCard(),
            const SizedBox(height: 14),
          ],

          // Error Banner (Visible when error occurred)
          if (state.errorMessage != null) ...[
            _buildErrorBanner(state, notifier),
            const SizedBox(height: 14),
          ],

          // Primary Action Button (START SEARCHING vs CANCEL SEARCH)
          _buildPrimaryActionButton(state, notifier),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(QuickMatchState state) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFF0B0F24),
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
                          'Quick Match',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B0F24),
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
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '1 VS 1',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF251A00),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Classic 5×5 Bingo · Numbers 1–25',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: Color(0xFF46464D),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: state.isSearching
                      ? const Color(0xFFDEE1FE)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  state.isSearching ? 'ACTIVE' : 'READY',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: state.isSearching
                        ? const Color(0xFF161A30)
                        : const Color(0xFF46464D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMetaChip(Icons.timer_outlined, 'Board Prep: 30s'),
              const SizedBox(width: 8),
              _buildMetaChip(Icons.hourglass_top_rounded, 'Turn Time: 20s'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F1),
        borderRadius: BorderRadius.circular(6),
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF46464D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralMatchmakingStage(QuickMatchState state) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Connecting Line
          Positioned(
            left: 40,
            right: 40,
            child: Container(
              height: 2,
              color: const Color(0xFFEEEEEB),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left: YOU
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F24),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: Colors.white,
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
                  const SizedBox(height: 6),
                  Text(
                    'YOU (${state.currentUserDisplayName})',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B0F24),
                    ),
                  ),
                ],
              ),

              // Center: 5x5 Matrix Grid
              QuickMatchMatrix(isSearching: state.isSearching),

              // Right: Opponent Slot
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = state.isSearching
                          ? 1.0 + (_pulseController.value * 0.05)
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: state.isSearching
                                  ? AppColors.primaryCoral
                                  : const Color(0xFFC7C5CD),
                              width: state.isSearching ? 2 : 1.5,
                              style: state.isSearching
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                            ),
                          ),
                          child: Icon(
                            state.isSearching
                                ? Icons.radar_rounded
                                : Icons.person_search_rounded,
                            size: 28,
                            color: state.isSearching
                                ? AppColors.primaryCoral
                                : const Color(0xFF77767D),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.isSearching ? 'MATCHING...' : 'FIND OPPONENT',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: state.isSearching
                          ? AppColors.primaryCoral
                          : const Color(0xFF77767D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndTimerSection(QuickMatchState state) {
    return Column(
      children: [
        if (state.isSearching) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryCoral,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ELAPSED: ${state.elapsedTimerString}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF1A1C1B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          state.isSearching
              ? 'Finding your opponent...'
              : 'Ready to find an opponent?',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B0F24),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          state.isSearching
              ? 'Searching for available players'
              : 'Tap start below to enter matchmaking queue',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            color: Color(0xFF46464D),
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryCards(QuickMatchState state) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    size: 18,
                    color: AppColors.primaryCoral,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MATCHMAKING',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF77767D),
                        ),
                      ),
                      Text(
                        state.matchmakingStatusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B0F24),
                        ),
                      ),
                    ],
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
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.dns_rounded,
                    size: 18,
                    color: Color(0xFF1B873F),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SERVER REGION',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF77767D),
                        ),
                      ),
                      Text(
                        state.serverRegion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B0F24),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleInfoCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFDEE1FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF161A30),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fast-Paced Online Play',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B0F24),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Complete 5 lines (horizontal, vertical, or diagonal) to call BINGO and claim victory!',
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

  Widget _buildErrorBanner(QuickMatchState state, QuickMatchNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryCoral.withAlpha(80),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.primaryCoral,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Notice',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF161A30),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.errorMessage ?? 'An error occurred during matchmaking.',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: Color(0xFF5D5F65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => notifier.startSearching(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: AppColors.primaryCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    QuickMatchState state,
    QuickMatchNotifier notifier,
  ) {
    if (state.isSearching) {
      return Column(
        children: [
          PrimaryButton(
            label: 'CANCEL SEARCH',
            icon: Icons.close_rounded,
            backgroundColor: AppColors.primaryCoral,
            onPressed: () => notifier.cancelSearching(),
          ),
          const SizedBox(height: 6),
          const Text(
            'You can cancel anytime before a match is found.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: Color(0xFF77767D),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        PrimaryButton(
          label: 'START SEARCHING',
          icon: Icons.arrow_forward_rounded,
          backgroundColor: AppColors.primaryCoral,
          onPressed: () => notifier.startSearching(),
        ),
        const SizedBox(height: 6),
        const Text(
          'You can cancel matchmaking at any time once started.',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            color: Color(0xFF77767D),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestRestrictionView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: AppCard(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StatusBadge(
                label: 'ACCOUNT REQUIRED',
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sports_kabaddi_rounded,
                  color: AppColors.primaryNavy,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Play Online 1v1 Matches',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                'Quick Match requires an authenticated BINGO account so your career stats, win streaks, and rank rewards are preserved safely.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'CREATE ACCOUNT',
                icon: Icons.person_add_rounded,
                onPressed: () {
                  context.push(
                    '${AppRoutes.auth}?mode=register&redirect=${Uri.encodeComponent(AppRoutes.quickMatch)}',
                  );
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'SIGN IN',
                icon: Icons.login_rounded,
                onPressed: () {
                  context.push(
                    '${AppRoutes.auth}?mode=signIn&redirect=${Uri.encodeComponent(AppRoutes.quickMatch)}',
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _handleBack,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(
                  'NOT NOW',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
