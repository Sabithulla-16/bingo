import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/room.dart';
import '../presentation/multiplayer_lobby_notifier.dart';

/// Multiplayer Waiting Room / Lobby Screen (Stitch Screen ID: `a584bd1bc3194df098024d3a9ab8c59d`)
class MultiplayerLobbyScreen extends ConsumerWidget {
  final String roomId;

  const MultiplayerLobbyScreen({super.key, required this.roomId});

  void _copyRoomCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code $code copied to clipboard!'),
        backgroundColor: AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref, bool isHost) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: isHost ? 'Close Room?' : 'Leave Room?',
        message: isHost
            ? 'Closing the room will dismiss all participants.'
            : 'Are you sure you want to leave this waiting lobby?',
        confirmLabel: isHost ? 'Close Room' : 'Leave Room',
        cancelLabel: 'Stay in Room',
        isDestructive: true,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await ref.read(multiplayerLobbyProvider(roomId).notifier).leaveRoom();
          if (context.mounted) {
            context.go(AppRoutes.multiplayerMenu);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyState = ref.watch(multiplayerLobbyProvider(roomId));

    // Listen for room status transitions (e.g. host starts game -> 'preparing')
    ref.listen<MultiplayerLobbyState>(multiplayerLobbyProvider(roomId), (prev, next) {
      if (next.room != null && next.room!.status == RoomStatus.preparing) {
        context.pushReplacement(AppRoutes.multiplayerBoardPrepPath(roomId));
      }
    });

    if (lobbyState.isLoading) {
      return const ResponsiveScaffold(
        body: Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    final room = lobbyState.room;
    if (room == null) {
      return ResponsiveScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Room Not Found', style: AppTypography.headlineMd),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Return to Multiplayer Menu',
                onPressed: () => context.go(AppRoutes.multiplayerMenu),
              ),
            ],
          ),
        ),
      );
    }

    final players = lobbyState.players;
    final isHost = lobbyState.isHost;
    final maxPlayers = room.maxPlayers;
    final readyCount = players.where((p) => p.isReady).length;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(room.name, style: AppTypography.headlineSm),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _confirmLeave(context, ref, isHost),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: isHost ? 'Close Room' : 'Leave Room',
            onPressed: () => _confirmLeave(context, ref, isHost),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center Room Code & Copy Banner
            AppCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.primaryNavy,
              child: Column(
                children: [
                  Text(
                    'ROOM CODE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textLight.withAlpha(180),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.code,
                        style: AppTypography.displayHeroMobile.copyWith(
                          color: AppColors.textLight,
                          letterSpacing: 4.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _copyRoomCode(context, room.code),
                        borderRadius: AppRadii.roundedFull,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share this code with up to ${room.maxPlayers - 1} friends to join',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textLight.withAlpha(200),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Settings Summary Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadii.roundedFull,
                border: Border.all(color: AppColors.structuralBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${room.prepTimeSeconds}s Prep', style: AppTypography.labelSm),
                  const SizedBox(width: 12),
                  const Text('•', style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(width: 12),
                  const Icon(Icons.hourglass_top_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${room.turnTimeSeconds}s Turn', style: AppTypography.labelSm),
                  const SizedBox(width: 12),
                  const Text('•', style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(width: 12),
                  const Icon(Icons.groups_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${players.length}/$maxPlayers Players', style: AppTypography.labelSm),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Participants List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PARTICIPANTS (${players.length}/$maxPlayers)',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                StatusBadge(
                  label: '$readyCount/$maxPlayers READY',
                  backgroundColor: readyCount >= 2 && readyCount == players.length
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  textColor: readyCount >= 2 && readyCount == players.length
                      ? AppColors.readyGreen
                      : AppColors.softYellowDark,
                  icon: readyCount >= 2 && readyCount == players.length
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_empty_rounded,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Player Slots (2 to 4 slots)
            ...List.generate(maxPlayers, (index) {
              final player = index < players.length ? players[index] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildPlayerSlot(
                  context: context,
                  ref: ref,
                  seatNumber: index + 1,
                  player: player,
                  isHostUser: isHost,
                ),
              );
            }),

            const SizedBox(height: 16),

            // Host / Guest Action Trigger
            if (isHost) ...[
              PrimaryButton(
                label: 'Start Game',
                icon: Icons.play_arrow_rounded,
                onPressed: lobbyState.canStartGame
                    ? () => ref
                        .read(multiplayerLobbyProvider(roomId).notifier)
                        .startGame()
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                lobbyState.canStartGame
                    ? 'All players ready! Tap Start Game to enter board preparation.'
                    : players.length < 2
                    ? 'Waiting for at least 1 more player to join...'
                    : 'Waiting for all players to toggle Ready ($readyCount/${players.length} ready)',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ] else ...[
              SecondaryButton(
                label: lobbyState.isCurrentUserReady ? 'Cancel Ready' : 'Ready Up',
                icon: lobbyState.isCurrentUserReady
                    ? Icons.close_rounded
                    : Icons.check_rounded,
                onPressed: () => ref
                    .read(multiplayerLobbyProvider(roomId).notifier)
                    .toggleReady(),
              ),
              const SizedBox(height: 8),
              Text(
                lobbyState.isCurrentUserReady
                    ? 'You are ready! Waiting for host to start match...'
                    : 'Tap Ready Up when you are prepared to begin.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlot({
    required BuildContext context,
    required WidgetRef ref,
    required int seatNumber,
    required RoomPlayer? player,
    required bool isHostUser,
  }) {
    if (player == null) {
      // Empty Open Slot
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow.withAlpha(120),
          borderRadius: AppRadii.roundedLg,
          border: Border.all(
            color: AppColors.structuralBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$seatNumber',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Empty Slot $seatNumber',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    'Waiting for player to join...',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.person_add_alt_1_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      );
    }

    // Occupied Slot
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          PlayerAvatar(
            backgroundColor: Color(
              int.parse(player.avatarColorHex.replaceFirst('#', '0xFF')),
            ),
            displayName: player.displayName,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.displayName,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primaryNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (player.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.softYellow,
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 10, color: AppColors.primaryNavy),
                            const SizedBox(width: 2),
                            Text(
                              'HOST',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primaryNavy,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  player.isHost ? 'Room Organizer' : 'Challenger',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Ready Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: player.isReady
                  ? const Color(0xFFDCFCE7)
                  : AppColors.surfaceContainerHigh,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  player.isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 14,
                  color: player.isReady ? AppColors.readyGreen : AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  player.isReady ? 'READY' : 'WAITING',
                  style: AppTypography.labelSm.copyWith(
                    color: player.isReady ? AppColors.readyGreen : AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Kick button for host on other players
          if (isHostUser && !player.isHost) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.errorRed),
              tooltip: 'Kick player',
              onPressed: () {
                ref
                    .read(multiplayerLobbyProvider(roomId).notifier)
                    .kickPlayer(player.userId);
              },
            ),
          ],
        ],
      ),
    );
  }
}
