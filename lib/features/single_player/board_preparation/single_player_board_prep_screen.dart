import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/game_engine/bingo_board.dart';
import '../../../core/game_engine/board_coordinate.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../presentation/single_player_game_notifier.dart';

/// Single Player Board Preparation Screen (Stitch Screen ID: `c059f8f36a2f4a808b71bfa6cd36131e`)
class SinglePlayerBoardPrepScreen extends ConsumerStatefulWidget {
  const SinglePlayerBoardPrepScreen({super.key});

  @override
  ConsumerState<SinglePlayerBoardPrepScreen> createState() =>
      _SinglePlayerBoardPrepScreenState();
}

class _SinglePlayerBoardPrepScreenState
    extends ConsumerState<SinglePlayerBoardPrepScreen> {
  int? _selectedCellIndex;

  void _shuffle() {
    setState(() {
      _selectedCellIndex = null;
      ref.read(preparedBoardProvider.notifier).state = BingoBoard.quickShuffle();
    });
  }

  void _clear() {
    setState(() {
      _selectedCellIndex = 0;
      ref.read(preparedBoardProvider.notifier).state = BingoBoard.empty();
    });
  }

  void _handleCellTapped(int tappedNumber) {
    final currentBoard = ref.read(preparedBoardProvider);
    final tappedIndex = currentBoard.numbers.indexOf(tappedNumber);

    if (tappedIndex == -1) return;

    setState(() {
      if (_selectedCellIndex == null) {
        _selectedCellIndex = tappedIndex;
      } else if (_selectedCellIndex == tappedIndex) {
        _selectedCellIndex = null; // Deselect
      } else {
        // Swap numbers between the two selected cells
        final updated = currentBoard.swapNumbers(_selectedCellIndex!, tappedIndex);
        ref.read(preparedBoardProvider.notifier).state = updated;
        _selectedCellIndex = null;
      }
    });
  }

  void _placeNumberFromPalette(int number) {
    final currentBoard = ref.read(preparedBoardProvider);

    int targetIndex = _selectedCellIndex ?? currentBoard.numbers.indexOf(0);
    if (targetIndex == -1) {
      targetIndex = 0;
    }

    final updated = currentBoard.setNumberAtIndex(targetIndex, number);
    ref.read(preparedBoardProvider.notifier).state = updated;

    setState(() {
      // Advance selection to next empty cell if available
      final nextEmpty = updated.numbers.indexOf(0);
      _selectedCellIndex = nextEmpty != -1 ? nextEmpty : null;
    });
  }

  void _handleConfirm() {
    final currentBoard = ref.read(preparedBoardProvider);
    final difficulty = ref.read(selectedDifficultyProvider);

    if (!currentBoard.isFilledAndValid) {
      // Auto-fill unassigned cells if user confirms
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Filling unassigned cells with random numbers...'),
          duration: Duration(seconds: 1),
        ),
      );
      _shuffle();
      return;
    }

    final gameId = 'sp_${DateTime.now().millisecondsSinceEpoch}';

    ref.read(singlePlayerGameProvider.notifier).initMatch(
          gameId: gameId,
          difficulty: difficulty,
          playerBoard: currentBoard,
        );

    context.pushReplacement(AppRoutes.singlePlayerGamePath(gameId));
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(preparedBoardProvider);
    final isValid = board.isFilledAndValid;
    final unassigned = board.unassignedNumbers;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Board Setup', style: AppTypography.headlineSm),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: StatusBadge(
                label: isValid
                    ? 'BOARD READY • 25/25 NUMBERS'
                    : '${unassigned.length} NUMBERS UNASSIGNED',
                backgroundColor: isValid
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                textColor: isValid
                    ? AppColors.readyGreen
                    : AppColors.softYellowDark,
                icon: isValid ? Icons.check_circle_rounded : Icons.info_outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Set Up Your Board',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Place numbers 1–25 or use Quick Shuffle. Tap any cell to swap.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 18),

            // 5x5 Board Grid
            BingoBoardGrid(
              matrix: board.numbers,
              isInteractive: true,
              onNumberTapped: _handleCellTapped,
            ),

            if (_selectedCellIndex != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Selected Cell: ${BoardCoordinate.fromIndex(_selectedCellIndex!)} — Tap another cell to swap',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primaryCoral,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Quick Actions: Shuffle and Clear
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Quick Shuffle',
                    icon: Icons.shuffle_rounded,
                    onPressed: _shuffle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(
                    label: 'Clear Board',
                    icon: Icons.restart_alt_rounded,
                    onPressed: _clear,
                  ),
                ),
              ],
            ),

            // Number Palette (shown when there are unassigned numbers)
            if (unassigned.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'TAP TO PLACE REMAINING NUMBERS (${unassigned.length}):',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: unassigned.map((cellNum) {
                  return InkWell(
                    onTap: () => _placeNumberFromPalette(cellNum),
                    borderRadius: AppRadii.roundedMd,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(
                          color: AppColors.structuralBorder,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cellNum.toString().padLeft(2, '0'),
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            PrimaryButton(
              label: isValid
                  ? 'Confirm & Start Game'
                  : 'Auto-Fill & Start Game',
              icon: Icons.play_arrow_rounded,
              onPressed: _handleConfirm,
            ),
          ],
        ),
      ),
    );
  }
}
