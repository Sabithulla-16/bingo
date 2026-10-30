import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../constants/app_constants.dart';

/// The canonical BINGO logo component shared across all screens.
/// Features the exact letter color sequence and central daub dot inside 'O' from the Stitch designs.
class BingoLogo extends StatelessWidget {
  final double fontSize;
  final bool showTagline;

  const BingoLogo({super.key, this.fontSize = 36.0, this.showTagline = false});

  @override
  Widget build(BuildContext context) {
    final daubSize = fontSize * 0.22;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'B',
              style: AppTypography.displayHeroMobile.copyWith(
                fontSize: fontSize,
                color: AppColors.primaryNavy,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: fontSize * 0.04),
              child: Text(
                'I',
                style: AppTypography.displayHeroMobile.copyWith(
                  fontSize: fontSize,
                  color: AppColors.primaryCoral,
                ),
              ),
            ),
            Text(
              'N',
              style: AppTypography.displayHeroMobile.copyWith(
                fontSize: fontSize,
                color: AppColors.primaryNavy,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: fontSize * 0.04),
              child: Text(
                'G',
                style: AppTypography.displayHeroMobile.copyWith(
                  fontSize: fontSize,
                  color: AppColors.softYellowDark,
                ),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'O',
                  style: AppTypography.displayHeroMobile.copyWith(
                    fontSize: fontSize,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Container(
                  width: daubSize,
                  height: daubSize,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryCoral,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            AppConstants.appTagline.toUpperCase(),
            style: AppTypography.labelMd.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ],
    );
  }
}
