import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// Secondary action button using structural Midnight Navy.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          disabledBackgroundColor: AppColors.primaryNavy.withAlpha(128),
          foregroundColor: AppColors.textOnPrimary,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTypography.labelLg.copyWith(
                        color: AppColors.textOnPrimary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(icon, size: 18, color: AppColors.textOnPrimary),
                  ],
                ],
              ),
      ),
    );
  }
}
