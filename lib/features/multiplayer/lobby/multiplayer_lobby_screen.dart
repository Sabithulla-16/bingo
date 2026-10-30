import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/room_badge.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';

/// Multiplayer Waiting Room / Lobby (Stitch Screen ID: `a584bd1bc3194df098024d3a9ab8c59d`)
class MultiplayerLobbyScreen extends StatefulWidget {
  final String roomId;

  const MultiplayerLobbyScreen({super.key, required this.roomId});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Waiting Lobby', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_rounded,
              color: AppColors.errorRed,
            ),
            onPressed: () => context.go(AppRoutes.multiplayerMenu),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: RoomBadge(roomCode: widget.roomId)),
            const SizedBox(height: 16),
            Text(
              'Waiting for players...',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Minimum 2 players required to begin match.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),

            // Player Slots
            _buildPlayerSlot('Valtry (You)', isHost: true, isReady: true),
            const SizedBox(height: 10),
            _buildPlayerSlot('Aria', isHost: false, isReady: _isReady),
            const SizedBox(height: 10),
            _buildEmptySlot(),
            const SizedBox(height: 10),
            _buildEmptySlot(),

            const Spacer(),
            SecondaryButton(
              label: _isReady ? 'Cancel Ready' : 'Ready Up',
              icon: _isReady ? Icons.close_rounded : Icons.check_circle_outline,
              onPressed: () {
                setState(() => _isReady = !_isReady);
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Host: Start Board Prep',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                context.push(AppRoutes.roomBoardPrepPath(widget.roomId));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(
    String name, {
    required bool isHost,
    required bool isReady,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              PlayerAvatar(displayName: name, size: 38, isHost: isHost),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.labelMd),
                  Text(
                    isHost ? 'Room Host' : 'Challenger',
                    style: AppTypography.bodySm,
                  ),
                ],
              ),
            ],
          ),
          isReady ? StatusBadge.ready() : StatusBadge.waiting(),
        ],
      ),
    );
  }

  Widget _buildEmptySlot() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: AppColors.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.structuralBorder,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Text('Waiting for player...', style: AppTypography.bodySm),
            ],
          ),
          const StatusBadge(
            label: 'OPEN',
            backgroundColor: AppColors.surfaceContainerHigh,
            textColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
