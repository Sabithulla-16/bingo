import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import 'bingo_logo.dart';
import 'primary_button.dart';

/// Full-screen or widget-level fallback boundary when an unhandled widget build error occurs.
/// Follows the exact BINGO design system to maintain visual polish and security.
class GlobalErrorBoundaryWidget extends StatelessWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onReset;

  const GlobalErrorBoundaryWidget({super.key, this.details, this.onReset});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedXl,
                  border: Border.all(
                    color: AppColors.structuralBorder,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadowColor,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BingoLogo(fontSize: 32),
                    const SizedBox(height: 20),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.errorRed,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "We're having trouble loading this screen. Please return home or restart the application.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'RELOAD APPLICATION',
                      icon: Icons.home_rounded,
                      onPressed:
                          onReset ??
                          () {
                            // Return or trigger rebuild
                            Navigator.maybeOf(
                              context,
                            )?.popUntil((route) => route.isFirst);
                          },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
