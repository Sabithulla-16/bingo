import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';

/// Create Room Settings (Stitch Screen ID: `44f9713e773b4977b628d9679a0f371c`)
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _roomNameController = TextEditingController(text: "Valtry's Room");
  int _playerCapacity = 4;
  int _prepTimeSeconds = 45;
  int _turnTimeSeconds = 20;

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Widget _buildSegmentedOption<T>({
    required List<T> values,
    required T selectedValue,
    required ValueChanged<T> onSelected,
    required String Function(T) labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadii.roundedFull,
      ),
      child: Row(
        children: values.map((val) {
          final isSelected = val == selectedValue;
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(val),
              borderRadius: AppRadii.roundedFull,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: AppRadii.roundedFull,
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: AppColors.cardShadowColor,
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labelBuilder(val),
                  style: AppTypography.labelSm.copyWith(
                    color: isSelected
                        ? AppColors.primaryNavy
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Room Settings', style: AppTypography.headlineSm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'ROOM HOST CONFIGURATION',
                icon: Icons.tune_rounded,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Customize your game',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 24),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Room Name',
                    controller: _roomNameController,
                    hintText: 'Enter room name',
                  ),
                  const SizedBox(height: 20),
                  Text('PLAYER CAPACITY', style: AppTypography.labelSm),
                  const SizedBox(height: 8),
                  _buildSegmentedOption<int>(
                    values: const [2, 3, 4],
                    selectedValue: _playerCapacity,
                    onSelected: (val) => setState(() => _playerCapacity = val),
                    labelBuilder: (v) => '$v Players',
                  ),
                  const SizedBox(height: 20),
                  Text('BOARD PREPARATION TIME', style: AppTypography.labelSm),
                  const SizedBox(height: 8),
                  _buildSegmentedOption<int>(
                    values: const [30, 45, 60],
                    selectedValue: _prepTimeSeconds,
                    onSelected: (val) => setState(() => _prepTimeSeconds = val),
                    labelBuilder: (v) => '${v}s',
                  ),
                  const SizedBox(height: 20),
                  Text('TURN TIME LIMIT', style: AppTypography.labelSm),
                  const SizedBox(height: 8),
                  _buildSegmentedOption<int>(
                    values: const [15, 20, 30],
                    selectedValue: _turnTimeSeconds,
                    onSelected: (val) => setState(() => _turnTimeSeconds = val),
                    labelBuilder: (v) => '${v}s',
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Create Room & Invite',
              icon: Icons.check_circle_outline,
              onPressed: () {
                final roomId = const Uuid().v4().substring(0, 8);
                context.push(AppRoutes.roomLobbyPath(roomId));
              },
            ),
          ],
        ),
      ),
    );
  }
}
