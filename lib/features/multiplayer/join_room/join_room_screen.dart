import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../data/multiplayer_repository_provider.dart';
import '../domain/room_lookup_result.dart';

/// Text formatter ensuring all entered characters are upper-case.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

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
  bool _isSearching = false;
  String? _errorMessage;
  RoomLookupResult? _lookupResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!.trim().toUpperCase();
      _performLookup(_codeController.text);
    }
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    if (mounted) {
      final code = _codeController.text.trim().toUpperCase();
      if (code.length == 6) {
        _performLookup(code);
      } else {
        setState(() {
          _lookupResult = null;
          _errorMessage = null;
        });
      }
    }
  }

  Future<void> _performLookup(String code) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final result = await repo.lookupRoomByCode(code);
      if (mounted) {
        setState(() {
          _lookupResult = result;
          if (!result.canJoin && !result.status.isWaiting) {
            _errorMessage = result.userMessage;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleJoin(String code) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.isGuest) {
      setState(
        () => _errorMessage =
            'An authenticated account is required to join multiplayer rooms.',
      );
      return;
    }

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
        _errorMessage = ErrorHandler.handle(
          e,
          operation: 'join_room_by_code',
          presentation: ErrorPresentation.silent,
        ).message;
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryNavy,
          ),
          tooltip: 'Back to Multiplayer',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.multiplayerMenu);
            }
          },
        ),
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

            // Segmented 6-box Code Input Display with interactive text field overlay
            Center(
              child: SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Visual 6-box display
                    Row(
                      mainAxisSize: MainAxisSize.min,
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

                    // Transparent interactive TextField overlay capturing user taps & native keyboard input
                    Positioned.fill(
                      child: TextField(
                        controller: _codeController,
                        focusNode: _focusNode,
                        autofocus: true,
                        showCursor: false,
                        maxLength: 6,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9]'),
                          ),
                          UpperCaseTextFormatter(),
                        ],
                        cursorColor: Colors.transparent,
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          fillColor: Colors.transparent,
                          filled: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (val) {
                          if (val.trim().length == 6) {
                            _handleJoin(val.trim());
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Loading / Searching indicator
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryCoral,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checking room status...',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
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

            // Authoritative Room Lookup Status Card
            if (_lookupResult != null && !_lookupResult!.status.isNotFound) ...[
              const SizedBox(height: 16),
              _buildStructuredRoomCard(_lookupResult!),
            ],

            const SizedBox(height: 20),

            // Primary Join Action Button
            PrimaryButton(
              label: _lookupResult != null && !_lookupResult!.canJoin
                  ? 'Cannot Join Room'
                  : 'Join Room',
              icon: Icons.login_rounded,
              isLoading: _isLoading,
              onPressed:
                  currentCode.length == 6 &&
                      (_lookupResult == null || _lookupResult!.canJoin)
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
                  ref.watch(recentRoomsProvider).when(
                    data: (recentRooms) {
                      if (recentRooms.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No recent rooms yet. Enter a room code above to join a match.',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: recentRooms.map((room) {
                          final code = (room['code'] ?? '').toString();
                          final roomName = room['name'] as String? ?? 'BINGO Room';
                          final participants = room['participant_count'] != null
                              ? '${room['participant_count']}/${room['max_players'] ?? 4}'
                              : null;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: () {
                                _codeController.text = code;
                                _performLookup(code);
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.meeting_room_outlined,
                                          size: 16,
                                          color: AppColors.primaryNavy,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              code,
                                              style: AppTypography.labelMd
                                                  .copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.0,
                                                  ),
                                            ),
                                            if (roomName.isNotEmpty &&
                                                roomName != code)
                                              Text(
                                                participants != null
                                                    ? '$roomName • $participants'
                                                    : roomName,
                                                style: AppTypography.bodySm
                                                    .copyWith(
                                                      fontSize: 10,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Check Code',
                                          style: AppTypography.labelSm
                                              .copyWith(
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
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No recent rooms available.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
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

  Widget _buildStructuredRoomCard(RoomLookupResult result) {
    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;

    switch (result.status) {
      case RoomLookupStatus.waiting:
        badgeBg = const Color(0xFFE8F5E9);
        badgeText = AppColors.readyGreen;
        badgeLabel = 'ROOM FOUND • ACCEPTING PLAYERS';
        badgeIcon = Icons.check_circle_outline_rounded;
        break;
      case RoomLookupStatus.full:
        badgeBg = const Color(0xFFFFF3E0);
        badgeText = AppColors.softYellowDark;
        badgeLabel = 'ROOM FULL';
        badgeIcon = Icons.groups_rounded;
        break;
      case RoomLookupStatus.boardPreparation:
        badgeBg = const Color(0xFFEDE7F6);
        badgeText = AppColors.primaryNavy;
        badgeLabel = 'PREPARING BOARD';
        badgeIcon = Icons.dashboard_customize_rounded;
        break;
      case RoomLookupStatus.playing:
        badgeBg = const Color(0xFFFFEBEE);
        badgeText = AppColors.primaryCoral;
        badgeLabel = 'GAME IN PROGRESS';
        badgeIcon = Icons.sports_esports_rounded;
        break;
      case RoomLookupStatus.roundCompleted:
        badgeBg = const Color(0xFFEDE7F6);
        badgeText = AppColors.primaryNavy;
        badgeLabel = 'ROUND FINISHED';
        badgeIcon = Icons.flag_rounded;
        break;
      case RoomLookupStatus.closed:
        badgeBg = AppColors.surfaceContainerHigh;
        badgeText = AppColors.textMuted;
        badgeLabel = 'ROOM CLOSED';
        badgeIcon = Icons.lock_outline_rounded;
        break;
      case RoomLookupStatus.expired:
        badgeBg = AppColors.surfaceContainerHigh;
        badgeText = AppColors.textMuted;
        badgeLabel = 'EXPIRED';
        badgeIcon = Icons.timer_off_outlined;
        break;
      case RoomLookupStatus.notFound:
        badgeBg = const Color(0xFFFFEBEE);
        badgeText = AppColors.errorRed;
        badgeLabel = 'NOT FOUND';
        badgeIcon = Icons.help_outline_rounded;
        break;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: StatusBadge(
                  label: badgeLabel,
                  backgroundColor: badgeBg,
                  textColor: badgeText,
                  icon: badgeIcon,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${result.currentPlayers}/${result.maxPlayers} PLAYERS',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.name ?? 'Bingo Room',
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Host: ${result.hostName ?? "Player"}',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.userMessage,
            style: AppTypography.bodySm.copyWith(
              color: result.canJoin
                  ? AppColors.readyGreen
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
