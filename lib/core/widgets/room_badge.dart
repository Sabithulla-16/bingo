import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

/// Room code pill badge featuring one-tap clipboard copy.
class RoomBadge extends StatelessWidget {
  final String roomCode;

  const RoomBadge({super.key, required this.roomCode});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code $roomCode copied to clipboard!'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copyToClipboard(context),
      borderRadius: AppRadii.roundedFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.roundedFull,
          border: Border.all(color: AppColors.structuralBorder, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ROOM: ',
              style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
            ),
            Text(
              roomCode.toUpperCase(),
              style: AppTypography.labelLg.copyWith(
                color: AppColors.primaryCoral,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppColors.primaryNavy,
            ),
          ],
        ),
      ),
    );
  }
}
