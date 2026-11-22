import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import 'widgets/splash_animated_board.dart';
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
  bool _minDurationElapsed = false;

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
    _timer = Timer(const Duration(milliseconds: 3800), () {
      if (!mounted) return;
      _minDurationElapsed = true;
      _checkAndRoute();
    });
  }

  void _checkAndRoute() {
    if (!_minDurationElapsed || !mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState is AuthInitial) {
      return; // Keep splash visible until background auth resolution finishes
    }
    if (authState is Authenticated || authState is AuthGuest) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppAuthState>(authStateProvider, (prev, next) {
      if (_minDurationElapsed) {
        _checkAndRoute();
      }
    });

    return ResponsiveScaffold(
      scrollable: false,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 20),
            // Center Stage
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SplashAnimatedBingoBoard(size: 248),
                SizedBox(height: 28),
                BingoLogo(fontSize: 42, showTagline: true),
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
      ),
    );
  }
}
