import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import '../errors/app_error.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Modal error dialog strictly adhering to the BINGO Velvet Daub design tokens.
/// Presents a clear, non-alarming user-friendly message and optional recovery action.
class AppErrorDialog extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const AppErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required AppError error,
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrimOverlayColor,
      builder: (context) => AppErrorDialog(
        error: error,
        onRetry: onRetry,
        retryLabel: retryLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRetry = onRetry ?? error.recoveryAction;
    final effectiveRetryLabel =
        retryLabel ?? error.recoveryActionLabel ?? 'TRY AGAIN';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.roundedXl,
        side: BorderSide(color: AppColors.structuralBorder, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Error Indicator Icon Badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.errorRed.withAlpha(50),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.errorRed,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            // Friendly Title
            Text(
              'Notice',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 10),

            // User-friendly message
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (effectiveRetry != null) ...[
              PrimaryButton(
                label: effectiveRetryLabel,
                icon: Icons.refresh_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  effectiveRetry();
                },
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'DISMISS',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else ...[
              PrimaryButton(
                label: 'OKAY',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
