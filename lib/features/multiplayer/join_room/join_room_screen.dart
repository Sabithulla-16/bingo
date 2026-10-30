import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';

/// Join Room Screen (Stitch Screen ID: `d221a3db42c344d3b8e705d9a6614e29`)
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleJoin() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != AppConstants.roomCodeLength) {
      setState(() {
        _errorText = 'Room code must be exactly 6 characters.';
      });
      return;
    }

    context.push(AppRoutes.roomLobbyPath(code));
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(title: Text('Join Room', style: AppTypography.headlineSm)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'ENTER ROOM CODE',
                icon: Icons.vpn_key_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Join your friends',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 6),
            Text(
              'Ask the room host for their 6-character room code.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 24),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  AppTextField(
                    label: '6-Digit Code',
                    hintText: 'e.g. BG7829',
                    controller: _codeController,
                    maxLength: AppConstants.roomCodeLength,
                    errorText: _errorText,
                    onChanged: (val) {
                      if (_errorText != null) setState(() => _errorText = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Join Room',
                    icon: Icons.login_rounded,
                    onPressed: _handleJoin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('RECENT ROOMS', style: AppTypography.labelSm),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(14),
              backgroundColor: AppColors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text('BG8821', style: AppTypography.labelMd),
                      const SizedBox(width: 8),
                      Text('• 4 Players', style: AppTypography.bodySm),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      _codeController.text = 'BG8821';
                    },
                    child: Text(
                      'Fill',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primaryCoral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
