import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

/// The visual presentation states for an individual 5x5 Bingo cell.
enum BingoCellState {
  /// Unmarked available number
  available,

  /// Number has been called
  called,

  /// Member of a completed winning line awaiting manual claim
  completedUnclaimed,

  /// Claimed winning cell (awarded letter)
  claimed,
}

/// A responsive, high-craft 5x5 Bingo cell widget supporting all four presentation states.
class BingoCell extends StatelessWidget {
  final int number;
  final BingoCellState state;
  final VoidCallback? onTap;
  final bool isInteractive;

  const BingoCell({
    super.key,
    required this.number,
    this.state = BingoCellState.available,
    this.onTap,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Border border;
    Widget? overlay;

    switch (state) {
      case BingoCellState.available:
        backgroundColor = AppColors.surface;
        textColor = AppColors.primaryNavy;
        border = Border.all(color: AppColors.structuralBorder, width: 1.5);
        break;

      case BingoCellState.called:
        backgroundColor = AppColors.lightLavender;
        textColor = AppColors.primaryNavy;
        border = Border.all(color: AppColors.primaryNavy, width: 2.0);
        break;

      case BingoCellState.completedUnclaimed:
        backgroundColor = AppColors.softYellow;
        textColor = AppColors.primaryNavy;
        border = Border.all(color: AppColors.primaryCoral, width: 2.5);
        break;

      case BingoCellState.claimed:
        backgroundColor = AppColors.primaryCoral;
        textColor = AppColors.textOnPrimary;
        border = Border.all(color: AppColors.primaryCoral, width: 1.5);
        overlay = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(51), // 20% white stamp ring
              width: 2.0,
            ),
          ),
        );
        break;
    }

    final numberFormatted = number < 10 ? '0$number' : '$number';

    return AspectRatio(
      aspectRatio: 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          borderRadius: AppRadii.roundedCell,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadii.roundedCell,
              border: border,
              boxShadow:
                  state == BingoCellState.claimed ||
                      state == BingoCellState.completedUnclaimed
                  ? const [
                      BoxShadow(
                        color: AppColors.cardShadowColor,
                        offset: Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(4.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ?overlay,
                Text(
                  numberFormatted,
                  style: AppTypography.bingoNumber.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
