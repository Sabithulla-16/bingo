import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import '../constants/app_constants.dart';

/// Progress tracker displaying B-I-N-G-O letters awarded for each claimed winning line.
class BingoProgressLetters extends StatelessWidget {
  final int claimedCount;
  final double letterSize;

  const BingoProgressLetters({
    super.key,
    required this.claimedCount,
    this.letterSize = 44.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(AppConstants.bingoLetters.length, (index) {
        final letter = AppConstants.bingoLetters[index];
        final isUnlocked = index < claimedCount;

        Color backgroundColor;
        Color textColor;
        Border? border;

        if (isUnlocked) {
          // Unlocked letter colors
          switch (index) {
            case 0: // B
              backgroundColor = AppColors.primaryNavy;
              textColor = Colors.white;
              break;
            case 1: // I
              backgroundColor = AppColors.primaryCoral;
              textColor = Colors.white;
              break;
            case 2: // N
              backgroundColor = AppColors.primaryNavy;
              textColor = Colors.white;
              break;
            case 3: // G
              backgroundColor = AppColors.softYellow;
              textColor = AppColors.primaryNavy;
              break;
            case 4: // O
            default:
              backgroundColor = AppColors.primaryCoral;
              textColor = Colors.white;
              break;
          }
        } else {
          // Locked / pending state
          backgroundColor = AppColors.surfaceContainerLow;
          textColor = AppColors.textMuted;
          border = Border.all(color: AppColors.structuralBorder, width: 1.5);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: letterSize,
          height: letterSize,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadii.roundedLg,
            border: border,
            boxShadow: isUnlocked
                ? const [
                    BoxShadow(
                      color: AppColors.cardShadowColor,
                      offset: Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: AppTypography.displayHeroMobile.copyWith(
              fontSize: letterSize * 0.55,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        );
      }),
    );
  }
}
