import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

/// Pill-shaped status indicator badge.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.lightLavender,
    this.textColor = AppColors.primaryNavy,
    this.icon,
  });

  factory StatusBadge.ready() {
    return const StatusBadge(
      label: 'READY',
      backgroundColor: Color(0xFFDCFCE7),
      textColor: AppColors.readyGreen,
      icon: Icons.check_circle,
    );
  }

  factory StatusBadge.waiting() {
    return const StatusBadge(
      label: 'WAITING',
      backgroundColor: Color(0xFFFEF3C7),
      textColor: AppColors.softYellowDark,
      icon: Icons.hourglass_top,
    );
  }

  factory StatusBadge.host() {
    return const StatusBadge(
      label: 'HOST',
      backgroundColor: AppColors.lightLavender,
      textColor: AppColors.primaryNavy,
      icon: Icons.stars,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadii.roundedFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.labelSm.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
