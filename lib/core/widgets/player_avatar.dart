import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// Reusable circular player avatar token with border outline, host indicator,
/// and online presence status.
class PlayerAvatar extends StatelessWidget {
  final String displayName;
  final double size;
  final bool isHost;
  final bool showOnlineIndicator;
  final Color? backgroundColor;
  final Color? textColor;

  const PlayerAvatar({
    super.key,
    required this.displayName,
    this.size = AppDimensions.avatarMd,
    this.isHost = false,
    this.showOnlineIndicator = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'P';

    final bg = backgroundColor ?? AppColors.primaryCoral;
    final fg =
        textColor ??
        (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? AppColors.textLight
            : AppColors.primaryNavy);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryNavy.withAlpha(25),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadowColor,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTypography.headlineSm.copyWith(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          if (isHost)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.softYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: const Icon(
                  Icons.star,
                  size: 11,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          if (showOnlineIndicator)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: AppColors.softYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
