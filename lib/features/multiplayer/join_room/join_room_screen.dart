import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/multiplayer_repository_provider.dart';

/// Join Room Screen (Stitch Screen ID: `d221a3db42c344d3b8e705d9a6614e29`)
class JoinRoomScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinRoomScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  // Mock / persisted recent room codes
  final List<String> _recentRooms = const ['BG7742', 'WIN990', 'PRO882'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!.trim().toUpperCase();
    }
    _codeController.addListener(() {
      final text = _codeController.text.toUpperCase();
      if (text != _codeController.text) {
        _codeController.value = _codeController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleJoin(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) {
      setState(() => _errorMessage = 'Room code must be exactly 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final room = await repo.joinRoomByCode(cleanCode);

      if (!mounted) return;
      context.pushReplacement(AppRoutes.multiplayerLobbyPath(room.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e
            .toString()
            .replaceFirst('StateError: ', '')
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = _codeController.text;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Join Room', style: AppTypography.headlineSm),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: StatusBadge(
                label: 'INVITATION CODE',
                icon: Icons.vpn_key_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter Room Code',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the 6-character room code shared by your host.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 28),

            // Segmented 6-box Code Input Display
            GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final char = index < currentCode.length
                        ? currentCode[index]
                        : '';
                    final isCurrent = index == currentCode.length;

                    return Container(
                      width: 46,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: char.isNotEmpty
                            ? AppColors.surface
                            : AppColors.surfaceContainerLow,
                        borderRadius: AppRadii.roundedLg,
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primaryNavy
                              : char.isNotEmpty
                              ? AppColors.primaryNavy
                              : AppColors.structuralBorder,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                        boxShadow: char.isNotEmpty
                            ? const [
                                BoxShadow(
                                  color: Color(0x0F20243A),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: AppTypography.headlineLgMobile.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Hidden text field managing native keyboard input
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 1,
                child: TextField(
                  controller: _codeController,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  onSubmitted: (val) {
                    if (val.length == 6) _handleJoin(val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Error / Validation Banner
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withAlpha(20),
                  borderRadius: AppRadii.roundedMd,
                  border: Border.all(color: AppColors.errorRed.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.errorRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Codes are case-insensitive',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),

            const SizedBox(height: 24),

            // Primary Join Action Button
            PrimaryButton(
              label: 'Join Room',
              icon: Icons.login_rounded,
              isLoading: _isLoading,
              onPressed: currentCode.length == 6
                  ? () => _handleJoin(currentCode)
                  : null,
            ),

            const SizedBox(height: 32),

            // Quick Rejoin / Recent Rooms
            AppCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'RECENT ROOMS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._recentRooms.map((code) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          _codeController.text = code;
                          _handleJoin(code);
                        },
                        borderRadius: AppRadii.roundedMd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedMd,
                            border: Border.all(
                              color: AppColors.structuralBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.meeting_room_outlined,
                                    size: 16,
                                    color: AppColors.primaryNavy,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    code,
                                    style: AppTypography.labelMd.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'TAP TO JOIN',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primaryCoral,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: AppColors.primaryCoral,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
