import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import '../widgets/app_error_dialog.dart';
import 'app_error.dart';
import 'error_logger.dart';
import 'error_mapper.dart';

/// Presentation mode for user-facing errors.
enum ErrorPresentation { snackBar, dialog, silent }

/// Centralized coordinator for mapping, logging, and displaying application errors.
class ErrorHandler {
  const ErrorHandler._();

  /// Processes any thrown exception: maps it to an [AppError], logs technical
  /// diagnostics securely, and optionally presents user-friendly UI.
  static AppError handle(
    Object error, {
    StackTrace? stackTrace,
    BuildContext? context,
    ErrorPresentation presentation = ErrorPresentation.snackBar,
    VoidCallback? onRetry,
    String? retryLabel,
    String? operation,
  }) {
    final appError = ErrorMapper.map(
      error,
      stackTrace,
    ).copyWith(recoveryAction: onRetry, recoveryActionLabel: retryLabel);

    // 1. Secure Diagnostic Logging
    ErrorLogger.log(appError, operation: operation, stackTrace: stackTrace);

    // 2. UI Presentation (if BuildContext provided and mounted)
    if (context != null && context.mounted) {
      switch (presentation) {
        case ErrorPresentation.snackBar:
          showSnackBar(
            context,
            appError,
            onRetry: onRetry,
            retryLabel: retryLabel,
          );
          break;
        case ErrorPresentation.dialog:
          showDialog(
            context,
            appError,
            onRetry: onRetry,
            retryLabel: retryLabel,
          );
          break;
        case ErrorPresentation.silent:
          break;
      }
    }

    return appError;
  }

  /// Displays a styled BINGO SnackBar matching design tokens.
  static void showSnackBar(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.primaryCoral,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.message,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
        duration: const Duration(seconds: 4),
        action: (onRetry != null || error.recoveryAction != null)
            ? SnackBarAction(
                label: retryLabel ?? error.recoveryActionLabel ?? 'RETRY',
                textColor: AppColors.primaryCoral,
                onPressed: onRetry ?? error.recoveryAction!,
              )
            : null,
      ),
    );
  }

  /// Displays an [AppErrorDialog] modal.
  static Future<void> showDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    return AppErrorDialog.show(
      context,
      error: error,
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }
}
