import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Single Player Board Preparation (Stitch Screen ID: `c059f8f36a2f4a808b71bfa6cd36131e`)
class SinglePlayerBoardPrepScreen extends StatefulWidget {
  const SinglePlayerBoardPrepScreen({super.key});

  @override
  State<SinglePlayerBoardPrepScreen> createState() =>
      _SinglePlayerBoardPrepScreenState();
}

class _SinglePlayerBoardPrepScreenState
    extends State<SinglePlayerBoardPrepScreen> {
  late List<int> _matrix;

  @override
  void initState() {
    super.initState();
    _shuffleBoard();
  }

  void _shuffleBoard() {
    final numbers =
        List<int>.generate(AppConstants.totalBoardCells, (i) => i + 1);
    numbers.shuffle(Random());
    setState(() {
      _matrix = numbers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Board Setup', style: AppTypography.headlineSm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'ARRANGE YOUR BOARD',
                icon: Icons.grid_on_rounded,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Prepare your 5×5 matrix',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Numbers 1 to 25 must appear exactly once. Use Quick Shuffle to randomize.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 20),
            BingoBoardGrid(
              matrix: _matrix,
              isInteractive: true,
              onNumberTapped: (cellNumber) {
                // Interactive cell tap feedback
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Quick Shuffle',
                    icon: Icons.shuffle_rounded,
                    onPressed: _shuffleBoard,
                  ),
                ),
              ],
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Confirm & Start Game',
              icon: Icons.check_circle_outline,
              onPressed: () {
                final gameId = 'sp_${DateTime.now().millisecondsSinceEpoch}';
                context.push(AppRoutes.singlePlayerGamePath(gameId));
              },
            ),
          ],
        ),
      ),
    );
  }
}
