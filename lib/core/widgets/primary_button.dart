import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// Full-bleed or fixed primary Coral button with tactile push down response.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final Color? backgroundColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryCoral;

    return SizedBox(
      width: width ?? double.infinity,
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withAlpha(128),
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
