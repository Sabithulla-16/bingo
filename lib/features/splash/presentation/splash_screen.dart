import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/bingo_logo.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_state.dart';

/// Splash Screen (Stitch Screen ID: `97875f5450c745e9afb99ca9389aa94d`)
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  // Sample 25-cell preview matrix matching Stitch splash screen
  final List<int> _previewMatrix = const [
    1, 2, 3, 4, 5,
    6, 7, 8, 9, 10,
    11, 12, 13, 14, 15,
    16, 17, 18, 19, 20,
    21, 22, 23, 24, 25,
  ];

  @override
  void initState() {
    super.initState();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSessionTimer() {
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (authState is Authenticated) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.auth);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      scrollable: false,
      body: Stack(
        children: [
          // Ambient blur circles from Stitch design
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightLavender.withAlpha(128),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryCoral.withAlpha(38),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),
              // Center Stage
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: BingoBoardGrid(
                      matrix: _previewMatrix,
                      calledNumbers: const {1, 7, 13, 19, 25},
                      claimedNumbers: const {1, 7, 13, 19, 25},
                      isInteractive: false,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const BingoLogo(
                    fontSize: 42,
                    showTagline: true,
                  ),
                ],
              ),
              // Footer Loading State
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLoadingIndicator(dotSize: 10),
                    const SizedBox(height: 14),
                    Text(
                      'PREPARING YOUR GAME',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome to BINGO',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
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
}
