import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bingo_board_grid.dart';
import '../../../core/widgets/bingo_progress_letters.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Multiplayer Gameplay (Stitch Screen ID: `99e26fda63c3428a82b9702145ca87f5`)
class MultiplayerGameplayScreen extends StatefulWidget {
  final String roomId;

  const MultiplayerGameplayScreen({super.key, required this.roomId});

  @override
  State<MultiplayerGameplayScreen> createState() =>
      _MultiplayerGameplayScreenState();
}

class _MultiplayerGameplayScreenState extends State<MultiplayerGameplayScreen> {
  final List<int> _matrix = List<int>.generate(25, (i) => i + 1);
  final Set<int> _calledNumbers = {4, 9, 15, 21};
  final Set<int> _claimedNumbers = {4};
  int _claimedLines = 1;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.roomId}', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primaryNavy,
            ),
            onPressed: () =>
                context.push(AppRoutes.roomStatisticsPath(widget.roomId)),
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
                      Text("VALTRY'S TURN (14s)", style: AppTypography.labelMd),
                    ],
                  ),
                  const StatusBadge(
                    label: 'ROUND 1',
                    backgroundColor: AppColors.lightLavender,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Opponent Presence Chips
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const PlayerAvatar(displayName: 'Aria', size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Aria', style: AppTypography.labelSm),
                              Text(
                                'Lines: B',
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const PlayerAvatar(displayName: 'Dante', size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dante', style: AppTypography.labelSm),
                              Text(
                                'Lines: --',
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Letter Progress B-I-N-G-O
            BingoProgressLetters(claimedCount: _claimedLines),
            const SizedBox(height: 16),

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
            const SizedBox(height: 16),

            PrimaryButton(
              label: 'Claim Completed Line',
              icon: Icons.star_rounded,
              onPressed: () {
                setState(() {
                  if (_claimedLines < 5) _claimedLines++;
                });
                if (_claimedLines == 5) {
                  context.pushReplacement(
                    AppRoutes.roomResultPath(widget.roomId),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Finish Match (Preview Result)',
              onPressed: () {
                context.pushReplacement(
                  AppRoutes.roomResultPath(widget.roomId),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
