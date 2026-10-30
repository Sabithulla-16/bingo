import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/room_badge.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Detailed Room Statistics (Stitch Screen ID: `3d876d713b4f4007a8ca42fcf502e534`)
class RoomStatisticsScreen extends StatelessWidget {
  final String roomId;

  const RoomStatisticsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Room Statistics', style: AppTypography.headlineSm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: RoomBadge(roomCode: roomId)),
            const SizedBox(height: 16),
            const Center(
              child: StatusBadge(
                label: 'SESSION SCOREBOARD',
                icon: Icons.leaderboard_rounded,
              ),
            ),
            const SizedBox(height: 20),

            // Scoreboard Summary Table
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PLAYER', style: AppTypography.labelSm),
                      Text('W - D - L', style: AppTypography.labelSm),
                      Text('WIN %', style: AppTypography.labelSm),
                      Text('STREAK', style: AppTypography.labelSm),
                    ],
                  ),
                  const Divider(color: AppColors.structuralBorder, height: 20),
                  _buildScoreRow('Valtry', '3 - 0 - 1', '75%', '2 🔥'),
                  const Divider(color: AppColors.structuralBorder, height: 16),
                  _buildScoreRow('Aria', '1 - 0 - 3', '25%', '0'),
                  const Divider(color: AppColors.structuralBorder, height: 16),
                  _buildScoreRow('Dante', '0 - 0 - 4', '0%', '0'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('ROUND-BY-ROUND LOG', style: AppTypography.labelSm),
            const SizedBox(height: 10),
            _buildRoundLog('Round 4', 'Winner: Valtry (18 calls)', '3m ago'),
            const SizedBox(height: 8),
            _buildRoundLog('Round 3', 'Winner: Aria (22 calls)', '8m ago'),
            const SizedBox(height: 8),
            _buildRoundLog('Round 2', 'Winner: Valtry (15 calls)', '14m ago'),

            const Spacer(),
            SecondaryButton(
              label: 'Return to Waiting Lobby',
              icon: Icons.meeting_room_rounded,
              onPressed: () {
                context.pushReplacement(AppRoutes.roomLobbyPath(roomId));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String name, String record, String pct, String streak) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: AppTypography.labelMd),
        Text(record, style: AppTypography.bodySm),
        Text(pct, style: AppTypography.bodySm),
        Text(streak, style: AppTypography.labelSm),
      ],
    );
  }

  Widget _buildRoundLog(String round, String details, String time) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: AppColors.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(round, style: AppTypography.labelMd),
              Text(details, style: AppTypography.bodySm),
            ],
          ),
          Text(
            time,
            style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
