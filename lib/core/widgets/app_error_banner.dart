import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import '../errors/app_error.dart';

/// Reusable non-intrusive banner for inline validation, persistent connection status,
/// or operation warnings adhering to the BINGO design system.
class AppErrorBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final bool isDismissible;
  final VoidCallback? onDismiss;

  const AppErrorBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.onRetry,
    this.retryLabel = 'RETRY',
    this.isDismissible = false,
    this.onDismiss,
  });

  factory AppErrorBanner.fromError(
    AppError error, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool isDismissible = false,
  }) {
    return AppErrorBanner(
      message: error.message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppColors.errorRed.withAlpha(20),
      borderColor: AppColors.errorRed.withAlpha(60),
      textColor: AppColors.errorRed,
      onRetry: onRetry ?? error.recoveryAction,
      retryLabel: error.recoveryActionLabel ?? 'RETRY',
      isDismissible: isDismissible,
      onDismiss: onDismiss,
    );
  }

  factory AppErrorBanner.connectionLost({VoidCallback? onRetry}) {
    return AppErrorBanner(
      message: 'Connection lost. Trying to reconnect...',
      icon: Icons.wifi_off_rounded,
      backgroundColor: AppColors.softYellow.withAlpha(40),
      borderColor: AppColors.softYellowDark.withAlpha(60),
      textColor: AppColors.primaryNavy,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.errorRed.withAlpha(20);
    final border = borderColor ?? AppColors.errorRed.withAlpha(60);
    final text = textColor ?? AppColors.errorRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: text, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(
                color: text,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: text,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                retryLabel ?? 'RETRY',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
            ),
          ],
          if (isDismissible && onDismiss != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: text),
            ),
          ],
        ],
      ),
    );
  }
}
