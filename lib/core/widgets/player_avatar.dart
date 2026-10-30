import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';

/// Reusable circular player avatar token with border outline.
class PlayerAvatar extends StatelessWidget {
  final String displayName;
  final double size;
  final bool isHost;
  final Color? backgroundColor;

  const PlayerAvatar({
    super.key,
    required this.displayName,
    this.size = AppDimensions.avatarMd,
    this.isHost = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'P';

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.lightLavender,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryNavy, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: AppTypography.headlineSm.copyWith(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        if (isHost)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: AppColors.softYellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star,
              size: 12,
              color: AppColors.primaryNavy,
            ),
          ),
      ],
    );
  }
}
