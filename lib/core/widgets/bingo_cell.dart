import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import '../theme/board_theme_config.dart';

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

/// A responsive, high-craft 5x5 Bingo cell widget supporting all four presentation states,
/// dynamic board theme styling, and customized number font weights.
class BingoCell extends StatelessWidget {
  final int number;
  final BingoCellState state;
  final VoidCallback? onTap;
  final bool isInteractive;
  final BoardThemeConfig? themeConfig;
  final int? numberStyleId;

  const BingoCell({
    super.key,
    required this.number,
    this.state = BingoCellState.available,
    this.onTap,
    this.isInteractive = true,
    this.themeConfig,
    this.numberStyleId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeConfig ?? BoardThemeConfig.classic();

    Color backgroundColor;
    Color textColor;
    Border border;
    Widget? overlay;

    switch (state) {
      case BingoCellState.available:
        backgroundColor = theme.cellAvailableBackground;
        textColor = theme.cellAvailableText;
        border = Border.all(color: theme.cellAvailableBorder, width: 1.5);
        break;

      case BingoCellState.called:
        backgroundColor = theme.cellCalledBackground;
        textColor = theme.cellCalledText;
        border = Border.all(color: theme.cellCalledBorder, width: 2.0);
        break;

      case BingoCellState.completedUnclaimed:
        backgroundColor = theme.cellCompletedBackground;
        textColor = theme.cellCompletedText;
        border = Border.all(color: theme.cellCompletedBorder, width: 2.5);
        break;

      case BingoCellState.claimed:
        backgroundColor = theme.cellClaimedBackground;
        textColor = theme.cellClaimedText;
        border = Border.all(color: theme.cellClaimedBorder, width: 1.5);
        overlay = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.stampRingColor, width: 2.0),
          ),
        );
        break;
    }

    final numberFormatted = number < 10 ? '0$number' : '$number';

    // Bold Numbers customization (id: 6) uses ultra-heavy weight
    final isBoldNumbers = numberStyleId == 6;
    final textStyle =
        (isBoldNumbers
                ? AppTypography.bingoNumber.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )
                : AppTypography.bingoNumber)
            .copyWith(color: textColor);

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
                Text(numberFormatted, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
