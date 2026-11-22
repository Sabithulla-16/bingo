import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../store/data/store_repository.dart';

/// Multiplayer Menu Screen (Stitch Screen ID: `f4d100bf68cf4088a4dc49448549ce41`)
///
/// Handles guest restriction and offline connection checks before
/// allowing players to create or join private multiplayer rooms.
class MultiplayerMenuScreen extends ConsumerStatefulWidget {
  const MultiplayerMenuScreen({super.key});

  @override
  ConsumerState<MultiplayerMenuScreen> createState() =>
      _MultiplayerMenuScreenState();
}

class _MultiplayerMenuScreenState extends ConsumerState<MultiplayerMenuScreen> {
  bool _isCheckingConnection = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    setState(() {
      _isCheckingConnection = true;
    });

    final connectivity = ref.read(connectivityServiceProvider);
    final connected = await connectivity.isConnected();

    if (mounted) {
      setState(() {
        _isOffline = !connected;
        _isCheckingConnection = false;
      });
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final isGuest = profile?.isGuest ?? true;
    final customization = ref.watch(playerCustomizationProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Multiplayer', style: AppTypography.headlineSm),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryNavy,
          ),
          tooltip: 'Back',
          onPressed: _handleBack,
        ),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  PlayerAvatar(
                    backgroundColor: Color(
                      int.parse(
                        profile.avatarColorHex.replaceFirst('#', '0xFF'),
                      ),
                    ),
                    displayName: profile.displayName,
                    size: 32,
                    avatarId: customization.avatarId,
                    hasGoldenFrame: customization.hasGoldenFrame,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile.displayName,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(isGuest),
    );
  }

  Widget _buildBody(bool isGuest) {
    if (_isCheckingConnection) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCoral),
        ),
      );
    }

    if (_isOffline) {
      return _buildOfflineView();
    }

    if (isGuest) {
      return _buildGuestRestrictionView();
    }

    return _buildMultiplayerOptions();
  }

  /// Displayed when user has no active internet connection.
  Widget _buildOfflineView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: AppCard(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryCoral.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.primaryCoral,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "You're Offline",
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Multiplayer requires an active internet connection to connect with other players in realtime.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'TRY AGAIN',
                icon: Icons.refresh_rounded,
                onPressed: _checkConnectivity,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'GO BACK',
                icon: Icons.arrow_back_rounded,
                onPressed: _handleBack,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displayed when a guest attempts to access multiplayer rooms.
  Widget _buildGuestRestrictionView() {
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
                  Icons.group_rounded,
                  color: AppColors.primaryNavy,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Play Multiplayer with Friends',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                'Multiplayer rooms require an authenticated BINGO account so your match history, chips, and stats are saved safely.',
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
                    '${AppRoutes.auth}?mode=register&redirect=${Uri.encodeComponent(AppRoutes.multiplayerMenu)}',
                  );
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'SIGN IN',
                icon: Icons.login_rounded,
                onPressed: () {
                  context.push(
                    '${AppRoutes.auth}?mode=signIn&redirect=${Uri.encodeComponent(AppRoutes.multiplayerMenu)}',
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

  /// Default multiplayer menu with Create and Join room cards.
  Widget _buildMultiplayerOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: StatusBadge(
              label: 'PRIVATE GAME ROOMS',
              icon: Icons.lock_outline_rounded,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Play With Friends',
            textAlign: TextAlign.center,
            style: AppTypography.headlineLgMobile,
          ),
          const SizedBox(height: 4),
          Text(
            'Host a private game room or join with a 6-character room code.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: 24),

          // Quick Match 1v1 Option Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFDAD6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFAE3029),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Quick Match 1v1',
                                  style: AppTypography.headlineSm,
                                  overflow: TextOverflow.ellipsis,
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
                                  'ONLINE',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF251A00),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Fast-paced 1v1 matchup with real online players',
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Find 1v1 Opponent',
                  icon: Icons.search_rounded,
                  backgroundColor: AppColors.primaryCoral,
                  onPressed: () => context.push(AppRoutes.quickMatch),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Host / Create Room Option Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCoral.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_home_rounded,
                        color: AppColors.primaryCoral,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Host Private Room',
                            style: AppTypography.headlineSm,
                          ),
                          Text(
                            'Customize players (2–4), prep & turn timers',
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Create Private Room',
                  icon: Icons.add_rounded,
                  onPressed: () => context.push(AppRoutes.createRoom),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Join Room Option Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.lightLavender,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: AppColors.primaryNavy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join with Code',
                            style: AppTypography.headlineSm,
                          ),
                          Text(
                            'Enter an invite code from a host friend',
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SecondaryButton(
                  label: 'Enter Room Code',
                  icon: Icons.login_rounded,
                  onPressed: () => context.push(AppRoutes.joinRoom),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // How Multiplayer Works Info Accordion
          AppCard(
            backgroundColor: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primaryNavy,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'HOW MULTIPLAYER WORKS',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRuleStep(
                  step: '1',
                  text:
                      'Host creates room and shares the unique 6-character room code.',
                ),
                const SizedBox(height: 8),
                _buildRuleStep(
                  step: '2',
                  text:
                      'Up to 4 players join, customize their boards, and click Ready.',
                ),
                const SizedBox(height: 8),
                _buildRuleStep(
                  step: '3',
                  text:
                      'Turn-based number calling with synchronized realtime countdowns.',
                ),
                const SizedBox(height: 8),
                _buildRuleStep(
                  step: '4',
                  text:
                      'First player to achieve 5 lines shouts BINGO to claim victory!',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleStep({required String step, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.primaryNavy,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textLight,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTypography.bodySm.copyWith(fontSize: 12)),
        ),
      ],
    );
  }
}
