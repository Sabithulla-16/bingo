import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// Reusable circular player avatar token supporting custom avatar styles,
/// cosmetic profile frames (Golden Frame), host indicators, and online presence.
class PlayerAvatar extends StatelessWidget {
  final String displayName;
  final double size;
  final bool isHost;
  final bool showOnlineIndicator;
  final Color? backgroundColor;
  final Color? textColor;
  final bool hasGoldenFrame;
  final int? avatarId;

  const PlayerAvatar({
    super.key,
    required this.displayName,
    this.size = AppDimensions.avatarMd,
    this.isHost = false,
    this.showOnlineIndicator = false,
    this.backgroundColor,
    this.textColor,
    this.hasGoldenFrame = false,
    this.avatarId,
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

    final isFunAvatar = avatarId == 7;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Golden Profile Frame (Cosmetic Item #9)
          if (hasGoldenFrame)
            Container(
              width: size + 6,
              height: size + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFF8DC),
                    Color(0xFFFFA500),
                    Color(0xFFFFD700),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(120),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),

          // Core circular avatar body
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: hasGoldenFrame
                    ? const Color(0xFFFFD700)
                    : AppColors.primaryNavy.withAlpha(25),
                width: hasGoldenFrame ? 2.0 : 1.5,
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
            child: isFunAvatar
                ? Icon(
                    Icons.face_retouching_natural_rounded,
                    size: size * 0.55,
                    color: fg,
                  )
                : Text(
                    initials,
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: size * 0.44,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
          ),

          // Host badge indicator
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

          // Online status indicator
          if (showOnlineIndicator)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: AppColors.readyGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
