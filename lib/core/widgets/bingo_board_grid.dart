import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import 'bingo_cell.dart';

/// Reusable 5x5 Bingo Board matrix grid.
class BingoBoardGrid extends StatelessWidget {
  final List<int> matrix;
  final Set<int> calledNumbers;
  final Set<int> claimedNumbers;
  final Set<int> completedUnclaimedNumbers;
  final ValueChanged<int>? onNumberTapped;
  final bool isInteractive;

  const BingoBoardGrid({
    super.key,
    required this.matrix,
    this.calledNumbers = const {},
    this.claimedNumbers = const {},
    this.completedUnclaimedNumbers = const {},
    this.onNumberTapped,
    this.isInteractive = true,
  }) : assert(
         matrix.length == 25,
         'Bingo matrix must contain exactly 25 numbers',
       );

  BingoCellState _resolveCellState(int number) {
    if (claimedNumbers.contains(number)) {
      return BingoCellState.claimed;
    }
    if (completedUnclaimedNumbers.contains(number)) {
      return BingoCellState.completedUnclaimed;
    }
    if (calledNumbers.contains(number)) {
      return BingoCellState.called;
    }
    return BingoCellState.available;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.roundedXl,
        border: Border.all(color: AppColors.structuralBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 25,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 6.0,
          mainAxisSpacing: 6.0,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final number = matrix[index];
          final state = _resolveCellState(number);

          return BingoCell(
            number: number,
            state: state,
            isInteractive: isInteractive,
            onTap: onNumberTapped != null
                ? () => onNumberTapped!(number)
                : null,
          );
        },
      ),
    );
  }
}
