import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../data/multiplayer_repository_provider.dart';

/// Create Room Settings Screen (Stitch Screen ID: `44f9713e773b4977b628d9679a0f371c`)
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  late final TextEditingController _nameController;
  int _maxPlayers = 4;
  int _prepTimeSeconds = 45;
  int _turnTimeSeconds = 20;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Bingo Game Room');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final room = await repo.createRoom(
        name: _nameController.text.trim().isEmpty
            ? 'Bingo Room'
            : _nameController.text.trim(),
        maxPlayers: _maxPlayers,
        prepTimeSeconds: _prepTimeSeconds,
        turnTimeSeconds: _turnTimeSeconds,
      );

      if (!mounted) return;
      context.pushReplacement(AppRoutes.multiplayerLobbyPath(room.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create room: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Room Settings', style: AppTypography.headlineSm),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'CUSTOM MATCH CONFIG',
                icon: Icons.tune_rounded,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Configure Your Room',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Set participant capacity and game turn parameters.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),

            // Room Name Input
            AppTextField(
              label: 'ROOM NAME',
              hintText: 'e.g., Weekend Bingo Champs',
              controller: _nameController,
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            ),
            const SizedBox(height: 20),

            // Player Capacity Selector
            _buildSectionHeader('MAX PLAYERS', Icons.groups_rounded),
            const SizedBox(height: 8),
            Row(
              children: [2, 3, 4].map((count) {
                final isSelected = _maxPlayers == count;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildSelectablePill(
                      label: '$count Players',
                      isSelected: isSelected,
                      onTap: () => setState(() => _maxPlayers = count),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Board Preparation Timer
            _buildSectionHeader('BOARD PREPARATION TIME', Icons.timer_outlined),
            const SizedBox(height: 8),
            Row(
              children: [30, 45, 60].map((sec) {
                final isSelected = _prepTimeSeconds == sec;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildSelectablePill(
                      label: '${sec}s',
                      isSelected: isSelected,
                      onTap: () => setState(() => _prepTimeSeconds = sec),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Turn Countdown Timer
            _buildSectionHeader('TURN TIME LIMIT', Icons.hourglass_top_rounded),
            const SizedBox(height: 8),
            Row(
              children: [15, 20, 30].map((sec) {
                final isSelected = _turnTimeSeconds == sec;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildSelectablePill(
                      label: '${sec}s',
                      isSelected: isSelected,
                      onTap: () => setState(() => _turnTimeSeconds = sec),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Host Identity Snapshot
            if (profile != null)
              AppCard(
                padding: const EdgeInsets.all(14),
                backgroundColor: AppColors.surfaceContainerLow,
                child: Row(
                  children: [
                    PlayerAvatar(
                      backgroundColor: Color(
                        int.parse(profile.avatarColorHex.replaceFirst('#', '0xFF')),
                      ),
                      displayName: profile.displayName,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            'You will host and govern this private room.',
                            style: AppTypography.bodySm.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Create Room & Invite',
              icon: Icons.rocket_launch_rounded,
              isLoading: _isLoading,
              onPressed: _handleCreateRoom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectablePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.roundedFull,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryNavy
              : AppColors.surfaceContainerLow,
          borderRadius: AppRadii.roundedFull,
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.structuralBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: isSelected ? AppColors.textLight : AppColors.primaryNavy,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
