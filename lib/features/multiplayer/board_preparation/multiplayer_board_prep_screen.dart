import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Multiplayer Board Preparation (Stitch Screen ID: `e8593d7a83924868a0b75fad83f69012`)
class MultiplayerBoardPrepScreen extends StatefulWidget {
  final String roomId;

  const MultiplayerBoardPrepScreen({super.key, required this.roomId});

  @override
  State<MultiplayerBoardPrepScreen> createState() =>
      _MultiplayerBoardPrepScreenState();
}

class _MultiplayerBoardPrepScreenState
    extends State<MultiplayerBoardPrepScreen> {
  late List<int> _matrix;
  bool _isBoardLocked = false;

  @override
  void initState() {
    super.initState();
    _shuffleBoard();
  }

  void _shuffleBoard() {
    if (_isBoardLocked) return;
    final numbers = List<int>.generate(
      AppConstants.totalBoardCells,
      (i) => i + 1,
    );
    numbers.shuffle(Random());
    setState(() {
      _matrix = numbers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Multiplayer Prep', style: AppTypography.headlineSm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Synchronized Server Timer Header
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: AppColors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: AppColors.primaryCoral,
                      ),
                      const SizedBox(width: 8),
                      Text('SHARED DEADLINE', style: AppTypography.labelSm),
                    ],
                  ),
                  Text(
                    '00:38',
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.primaryCoral,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: StatusBadge(
                label: 'LOCK YOUR SECRET BOARD',
                icon: Icons.lock_outline_rounded,
              ),
            ),
            const SizedBox(height: 16),
            BingoBoardGrid(matrix: _matrix, isInteractive: !_isBoardLocked),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Quick Shuffle',
                    icon: Icons.shuffle_rounded,
                    onPressed: _isBoardLocked ? null : _shuffleBoard,
                  ),
                ),
              ],
            ),
            const Spacer(),
            PrimaryButton(
              label: _isBoardLocked
                  ? 'Board Locked • Ready!'
                  : 'Lock Board & Confirm',
              icon: _isBoardLocked ? Icons.check_circle : Icons.lock_outline,
              onPressed: () {
                setState(() => _isBoardLocked = true);
                context.pushReplacement(AppRoutes.roomGamePath(widget.roomId));
              },
            ),
          ],
        ),
      ),
    );
  }
}
