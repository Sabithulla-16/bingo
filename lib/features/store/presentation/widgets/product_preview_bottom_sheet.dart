import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../data/supabase/supabase_provider.dart';
import '../../domain/store_item.dart';
import '../../data/store_repository.dart';

class ProductPreviewBottomSheet extends ConsumerStatefulWidget {
  final StoreItem initialItem;
  final VoidCallback? onPurchasedOrEquipped;

  const ProductPreviewBottomSheet({
    super.key,
    required this.initialItem,
    this.onPurchasedOrEquipped,
  });

  static Future<void> show(
    BuildContext context,
    StoreItem item, {
    VoidCallback? onPurchasedOrEquipped,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductPreviewBottomSheet(
        initialItem: item,
        onPurchasedOrEquipped: onPurchasedOrEquipped,
      ),
    );
  }

  @override
  ConsumerState<ProductPreviewBottomSheet> createState() =>
      _ProductPreviewBottomSheetState();
}

class _ProductPreviewBottomSheetState
    extends ConsumerState<ProductPreviewBottomSheet> {
  late StoreItem _selectedItem;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialItem;
  }

  Future<void> _handleEquip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(storeRepositoryProvider);
      await repo.equipItem(_selectedItem.id);
      ref.read(feedbackServiceProvider).lightTap();
      widget.onPurchasedOrEquipped?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBuy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(storeRepositoryProvider);
      await repo.purchaseItem(_selectedItem.id);
      ref.read(feedbackServiceProvider).celebration();
      widget.onPurchasedOrEquipped?.call();
      if (mounted) {
        setState(() {
          _selectedItem = _selectedItem.copyWith(status: StoreItemStatus.owned);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playSoundSample() {
    final feedback = ref.read(feedbackServiceProvider);
    if (_selectedItem.id == 11) {
      feedback.callNumber();
    } else if (_selectedItem.id == 12) {
      feedback.victory();
    } else {
      feedback.lineStrike();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final chips = profile?.chips ?? 500;
    final allItems =
        ref.watch(storeItemsProvider).valueOrNull ?? StoreItem.catalog;

    // Refresh selected item from live store state
    final liveItem = allItems.firstWhere(
      (it) => it.id == _selectedItem.id,
      orElse: () => _selectedItem,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: AppRadii.roundedFull,
                  ),
                ),
              ),

              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Text(
                            liveItem.typeName.toUpperCase(),
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(liveItem),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainer,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Switcher Bar for Board Themes
              if (liveItem.category == StoreCategory.board) ...[
                const Divider(height: 1, color: AppColors.surfaceContainer),
                Container(
                  color: AppColors.surfaceContainerLow.withAlpha(140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'THEME:',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: allItems
                                .where((i) => i.category == StoreCategory.board)
                                .map((themeItem) {
                                  final isSelected =
                                      themeItem.id == liveItem.id;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _selectedItem = themeItem;
                                      }),
                                      borderRadius: AppRadii.roundedFull,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primaryNavy
                                              : AppColors.surfaceContainer,
                                          borderRadius: AppRadii.roundedFull,
                                        ),
                                        child: Text(
                                          themeItem.title,
                                          style: AppTypography.labelSm.copyWith(
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.primaryNavy,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 1, color: AppColors.surfaceContainer),

              // Stage Preview Container
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadii.roundedXl,
                    border: Border.all(color: AppColors.structuralBorder),
                  ),
                  child: Center(child: _buildStagePreview(liveItem)),
                ),
              ),

              // Meta Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveItem.title,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            liveItem.description,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: AppRadii.roundedFull,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.token_rounded,
                            size: 14,
                            color: AppColors.primaryCoral,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            liveItem.isFree ? 'FREE' : '${liveItem.price}',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (!liveItem.isFree) ...[
                            const SizedBox(width: 3),
                            Text(
                              'CHIPS',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Wallet Balance Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: AppRadii.roundedLg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 16,
                            color: AppColors.softYellowDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Current Wallet Balance:',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$chips CHIPS',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.errorRed,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Sticky CTA Action Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActionCta(liveItem, chips),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StoreItem item) {
    if (item.status.isEquipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          'EQUIPPED',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    if (item.status.isOwned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.lightLavender,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          'OWNED',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryCoral.withAlpha(30),
        borderRadius: AppRadii.roundedFull,
      ),
      child: Text(
        'AVAILABLE • ${item.price} CHIPS',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.primaryCoral,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStagePreview(StoreItem item) {
    switch (item.category) {
      case StoreCategory.board:
        return _build5x5BoardPreview(item.themeKey);
      case StoreCategory.numbers:
        return _buildNumbersPreview(item.id == 6);
      case StoreCategory.avatar:
        return _buildAvatarPreview();
      case StoreCategory.victory:
        return _buildVictoryPreview();
      case StoreCategory.frame:
        return _buildFramePreview();
      case StoreCategory.sound:
        return _buildSoundPreview();
      default:
        return _build5x5BoardPreview('classic');
    }
  }

  /// STRICT 5x5 BINGO Board Preview:
  /// Exactly 25 cells (01 to 25), numbers formatted with leading zeros.
  /// No star / free cell. Demonstrates diagonal line daub (01, 07, 13, 19, 25).
  Widget _build5x5BoardPreview(String themeKey) {
    Color boardBg;
    Color headerColor;
    Color defaultCellBg;
    Color defaultCellText;
    Color daubedCellBg;
    Color daubedCellText;

    if (themeKey == 'lavender') {
      boardBg = const Color(0xFFEBE8F7);
      headerColor = const Color(0xFF2E274D);
      defaultCellBg = const Color(0xFFF6F4FD);
      defaultCellText = const Color(0xFF2E274D);
      daubedCellBg = const Color(0xFF7C66DC);
      daubedCellText = Colors.white;
    } else if (themeKey == 'midnight') {
      boardBg = const Color(0xFF1E2338);
      headerColor = const Color(0xFFC2C5E2);
      defaultCellBg = const Color(0xFF262C46);
      defaultCellText = const Color(0xFFE2E8F0);
      daubedCellBg = AppColors.primaryCoral;
      daubedCellText = Colors.white;
    } else if (themeKey == 'neon') {
      boardBg = const Color(0xFF141620);
      headerColor = const Color(0xFFFFD043);
      defaultCellBg = const Color(0xFF202434);
      defaultCellText = Colors.white;
      daubedCellBg = const Color(0xFFFF4757);
      daubedCellText = Colors.white;
    } else {
      // Classic Cream
      boardBg = const Color(0xFFF5F3EC);
      headerColor = AppColors.primaryNavy;
      defaultCellBg = Colors.white;
      defaultCellText = AppColors.primaryNavy;
      daubedCellBg = AppColors.primaryCoral;
      daubedCellText = Colors.white;
    }

    const daubed = {1, 7, 13, 19, 25};

    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: AppRadii.roundedXl,
        border: Border.all(color: AppColors.structuralBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['B', 'I', 'N', 'G', 'O'].map((letter) {
              return Text(
                letter,
                style: AppTypography.labelMd.copyWith(
                  color: headerColor,
                  fontWeight: FontWeight.w900,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // 5x5 Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final number = index + 1;
              final isMarked = daubed.contains(number);
              final numStr = number < 10 ? '0$number' : '$number';

              Color cellBg = isMarked ? daubedCellBg : defaultCellBg;
              Color cellText = isMarked ? daubedCellText : defaultCellText;

              if (themeKey == 'neon' && number == 13) {
                cellBg = const Color(0xFFFFD043);
                cellText = const Color(0xFF0B0F24);
              }

              return Container(
                decoration: BoxDecoration(
                  color: cellBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  numStr,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    fontWeight: isMarked ? FontWeight.w900 : FontWeight.w600,
                    color: cellText,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // 5 In a Row badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: daubedCellBg,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars, color: Colors.white, size: 10),
                    SizedBox(width: 3),
                    Text(
                      '5 IN A ROW!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Diagonal Line Preview',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: headerColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumbersPreview(bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildNumberTile('12', 'B', isBold, false),
        const SizedBox(width: 12),
        _buildNumberTile('38', 'N', isBold, true),
        const SizedBox(width: 12),
        _buildNumberTile('75', 'O', isBold, false),
      ],
    );
  }

  Widget _buildNumberTile(String num, String col, bool isBold, bool daubed) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: daubed ? AppColors.primaryCoral : AppColors.surface,
        borderRadius: AppRadii.roundedLg,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            num,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: isBold ? 24 : 20,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: daubed ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          Text(
            col,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: daubed ? Colors.white70 : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(
        color: AppColors.primaryCoral,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x22FC695C),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.mood_rounded, size: 40, color: Colors.white),
    );
  }

  Widget _buildVictoryPreview() {
    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(
        color: AppColors.softYellow,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33FFD166),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 40,
        color: AppColors.primaryNavy,
      ),
    );
  }

  Widget _buildFramePreview() {
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.softYellowDark,
        shape: BoxShape.circle,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.primaryNavy,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_rounded, size: 38, color: Colors.white),
      ),
    );
  }

  Widget _buildSoundPreview() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primaryNavy,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _playSoundSample,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Play Sound Sample'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryNavy,
            side: const BorderSide(color: AppColors.primaryNavy),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedFull),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCta(StoreItem item, int currentChips) {
    if (item.status.isEquipped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppRadii.roundedFull,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.primaryNavy,
            ),
            const SizedBox(width: 6),
            Text(
              'CURRENTLY EQUIPPED',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    if (item.status.isOwned) {
      return PrimaryButton(
        label: 'EQUIP NOW',
        icon: Icons.check_rounded,
        isLoading: _isLoading,
        onPressed: _handleEquip,
      );
    }

    final hasEnough = currentChips >= item.price;
    return SecondaryButton(
      label: hasEnough
          ? 'BUY (${item.price} CHIPS)'
          : 'INSUFFICIENT CHIPS (${item.price})',
      icon: Icons.shopping_bag_outlined,
      isLoading: _isLoading,
      onPressed: hasEnough ? _handleBuy : null,
    );
  }
}
