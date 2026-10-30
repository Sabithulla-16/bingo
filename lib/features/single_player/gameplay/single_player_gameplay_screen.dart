import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/bingo_progress_letters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Single Player Gameplay (Stitch Screen ID: `c35c79a49c804f4aad87a3ae72090e66`)
class SinglePlayerGameplayScreen extends StatefulWidget {
  final String gameId;

  const SinglePlayerGameplayScreen({super.key, required this.gameId});

  @override
  State<SinglePlayerGameplayScreen> createState() =>
      _SinglePlayerGameplayScreenState();
}

class _SinglePlayerGameplayScreenState
    extends State<SinglePlayerGameplayScreen> {
  // Sample board state
  final List<int> _matrix = List<int>.generate(25, (i) => i + 1);
  final Set<int> _calledNumbers = {3, 7, 12, 18, 22};
  final Set<int> _claimedNumbers = {3, 7};
  int _claimedLines = 2; // B, I

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Single Player', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: AppColors.errorRed),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Turn Banner
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: AppColors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.readyGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('YOUR TURN', style: AppTypography.labelMd),
                    ],
                  ),
                  const StatusBadge(
                    label: 'CALL A NUMBER',
                    backgroundColor: AppColors.lightLavender,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Letter Progress B-I-N-G-O
            BingoProgressLetters(claimedCount: _claimedLines),
            const SizedBox(height: 20),

            // 5x5 Board
            BingoBoardGrid(
              matrix: _matrix,
              calledNumbers: _calledNumbers,
              claimedNumbers: _claimedNumbers,
              onNumberTapped: (number) {
                if (!_calledNumbers.contains(number)) {
                  setState(() {
                    _calledNumbers.add(number);
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Action Buttons
            PrimaryButton(
              label: 'Claim Completed Line',
              icon: Icons.star_rounded,
              onPressed: () {
                setState(() {
                  if (_claimedLines < 5) _claimedLines++;
                });
                if (_claimedLines == 5) {
                  context.pushReplacement(
                    AppRoutes.singlePlayerResultPath(widget.gameId),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Finish Match (Preview Result)',
              onPressed: () {
                context.pushReplacement(
                  AppRoutes.singlePlayerResultPath(widget.gameId),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
