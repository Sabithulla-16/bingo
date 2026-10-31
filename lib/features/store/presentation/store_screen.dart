import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../data/store_repository.dart';
import '../domain/store_item.dart';
import 'widgets/product_preview_bottom_sheet.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  int _featuredTabIndex = 0; // 0: Featured, 1: Popular, 2: New Drops
  StoreCategory _selectedCategory = StoreCategory.all;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final chips = profile?.chips ?? 500;
    final itemsAsync = ref.watch(storeItemsProvider);
    final allItems = itemsAsync.valueOrNull ?? StoreItem.catalog;

    // Filter items based on selected category
    final displayedItems = _selectedCategory == StoreCategory.all
        ? allItems
        : allItems.where((i) => i.category == _selectedCategory).toList();

    // Featured Hero Item (Lavender Dream is default #2, or Neon Party #4, or Midnight #3)
    final featuredItem = allItems.firstWhere(
      (i) =>
          i.id ==
          (_featuredTabIndex == 0 ? 2 : (_featuredTabIndex == 1 ? 4 : 3)),
      orElse: () => allItems.first,
    );

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('Bingo Store', style: AppTypography.headlineSm),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryNavy,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        actions: [
          // Expanded Chip Balance Pill (No profile icon in Store header)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: AppRadii.roundedFull,
                border: Border.all(color: AppColors.structuralBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.token_rounded,
                    size: 16,
                    color: AppColors.primaryCoral,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$chips',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'CHIPS',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Featured Customization Banner
            _buildFeaturedBanner(featuredItem),

            const SizedBox(height: 16),

            // 2. Earn Chips by Playing Section
            _buildEarnChipsSection(),

            const SizedBox(height: 20),

            // 3. Customization Vault Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Customization Vault',
                        style: AppTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${displayedItems.length} items)',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCoral.withAlpha(25),
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: Text(
                      '100% Cosmetic',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primaryCoral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Category Navigation immediately below Customization Vault heading
            _buildCategoryFilterRail(),

            const SizedBox(height: 14),

            // 4. Two-Column Product Grid
            _buildProductGrid(displayedItems, chips),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION BUILDERS
  // ==========================================

  Widget _buildFeaturedBanner(StoreItem featured) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Tabs (Featured, Popular, New Drops) - No removed "HOT PICK"
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFeaturedTab(0, 'Featured'),
                _buildFeaturedTab(1, 'Popular'),
                _buildFeaturedTab(2, 'New Drops'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featured.title,
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      featured.description,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () =>
                          ProductPreviewBottomSheet.show(context, featured),
                      borderRadius: AppRadii.roundedFull,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCoral,
                          borderRadius: AppRadii.roundedFull,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22FC695C),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'PREVIEW THEME',
                              style: AppTypography.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Mini 5x5 Board Graphic (Strict 25 cells 01-25)
              GestureDetector(
                onTap: () => ProductPreviewBottomSheet.show(context, featured),
                child: _buildMini5x5BoardGraphic(featured.themeKey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTab(int index, String label) {
    final isSelected = _featuredTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _featuredTabIndex = index),
      borderRadius: AppRadii.roundedFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.transparent,
          borderRadius: AppRadii.roundedFull,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildMini5x5BoardGraphic(String themeKey) {
    Color bg = const Color(0xFFEBE8F7);
    Color border = const Color(0xFFD9D3F3);
    Color header = const Color(0xFF2E274D);
    Color daubed = const Color(0xFF7C66DC);

    if (themeKey == 'midnight') {
      bg = const Color(0xFF1E2338);
      border = const Color(0xFF2C3352);
      header = const Color(0xFFC2C5E2);
      daubed = AppColors.primaryCoral;
    } else if (themeKey == 'neon') {
      bg = const Color(0xFF141620);
      border = const Color(0xFF2B3045);
      header = const Color(0xFFFFD043);
      daubed = const Color(0xFFFF4757);
    } else if (themeKey == 'classic') {
      bg = const Color(0xFFF5F3EC);
      border = const Color(0xFFE5E0D3);
      header = AppColors.primaryNavy;
      daubed = AppColors.primaryCoral;
    }

    const daubedIndices = {1, 7, 13, 19, 25};

    return Container(
      width: 110,
      height: 110,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['B', 'I', 'N', 'G', 'O'].map((l) {
              return Text(
                l,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: header,
                ),
              );
            }).toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, i) {
              final num = i + 1;
              final isMarked = daubedIndices.contains(num);
              final numStr = num < 10 ? '0$num' : '$num';

              return Container(
                decoration: BoxDecoration(
                  color: isMarked ? daubed : Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
                child: Text(
                  numStr,
                  style: TextStyle(
                    fontSize: 5.5,
                    fontWeight: isMarked ? FontWeight.w900 : FontWeight.w600,
                    color: isMarked ? Colors.white : header,
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '5 IN A ROW',
                style: TextStyle(
                  fontSize: 5.5,
                  fontWeight: FontWeight.w800,
                  color: daubed,
                ),
              ),
              Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 5.5,
                  fontWeight: FontWeight.w800,
                  color: daubed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarnChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn Chips by Playing',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Play, complete challenges, and collect rewards.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.earnChips),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryCoral,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryCoral,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primaryCoral,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4 Reward Cards in 2x2 Grid
        Row(
          children: [
            Expanded(
              child: _buildRewardCard(
                icon: Icons.calendar_today_rounded,
                iconColor: AppColors.primaryCoral,
                badge: '+50 CHIPS',
                badgeBg: AppColors.primaryCoral,
                title: 'Daily Check-in',
                desc: 'Claim your daily reward',
                buttonLabel: 'CLAIM NOW',
                statusText: 'Streak: 4 Days',
                onPressed: () => context.push(AppRoutes.earnChips),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRewardCard(
                icon: Icons.sports_esports_rounded,
                iconColor: AppColors.primaryNavy,
                badge: '+20 / MATCH',
                badgeBg: AppColors.surfaceContainerHigh,
                badgeTextColor: AppColors.primaryNavy,
                title: 'Match Doubling',
                desc: 'Earn chips by playing matches',
                buttonLabel: 'PLAY MATCH',
                statusText: '2/5 Daily Games Played',
                onPressed: () => context.push(AppRoutes.singlePlayerDifficulty),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildRewardCard(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.softYellowDark,
                badge: '+100 / WIN',
                badgeBg: AppColors.softYellow,
                badgeTextColor: AppColors.primaryNavy,
                title: 'Room Jackpot',
                desc: 'Be the first to hit BINGO!',
                buttonLabel: 'JOIN ROOM',
                statusText: '3 Active Public Rooms',
                onPressed: () => context.push(AppRoutes.multiplayerMenu),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRewardCard(
                icon: Icons.military_tech_rounded,
                iconColor: AppColors.primaryNavy,
                badge: 'UP TO +500',
                badgeBg: AppColors.lightLavender,
                badgeTextColor: AppColors.primaryNavy,
                title: 'Achievements',
                desc: 'Collect trophies and badges',
                buttonLabel: 'VIEW TASKS',
                statusText: '12/28 Unlocked',
                onPressed: () => context.push(AppRoutes.achievements),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Fairness Reassurance Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: AppColors.structuralBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 15,
                color: AppColors.primaryCoral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '100% Cosmetic • Zero pay-to-win boosts. All cosmetics are fair and luck-based.',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeBg,
    Color badgeTextColor = Colors.white,
    required String title,
    required String desc,
    required String buttonLabel,
    required String statusText,
    required VoidCallback onPressed,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: buttonLabel == 'CLAIM NOW'
                    ? AppColors.primaryNavy
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.structuralBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                buttonLabel,
                style: AppTypography.labelSm.copyWith(
                  color: buttonLabel == 'CLAIM NOW'
                      ? Colors.white
                      : AppColors.primaryNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              statusText,
              style: AppTypography.labelSm.copyWith(
                fontSize: 9.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRail() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: StoreCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = cat),
              borderRadius: AppRadii.roundedFull,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryNavy
                      : AppColors.surfaceContainer,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  cat.label,
                  style: AppTypography.labelSm.copyWith(
                    color: isSelected ? Colors.white : AppColors.primaryNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductGrid(List<StoreItem> items, int currentChips) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildProductCard(item, currentChips);
      },
    );
  }

  Widget _buildProductCard(StoreItem item, int currentChips) {
    return InkWell(
      onTap: () => ProductPreviewBottomSheet.show(context, item),
      borderRadius: AppRadii.roundedLg,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Thumbnail Stage
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: _buildItemThumbnail(item)),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              item.typeName.toUpperCase(),
              style: AppTypography.labelSm.copyWith(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.surfaceContainer),
            const SizedBox(height: 6),

            // Card Action Footer
            _buildCardFooter(item, currentChips),
          ],
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(StoreItem item) {
    if (item.category == StoreCategory.board) {
      return _buildMini5x5BoardGraphic(item.themeKey);
    }
    if (item.category == StoreCategory.numbers) {
      return Text(
        item.id == 6 ? '77' : '42',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: item.id == 6 ? 28 : 24,
          fontWeight: item.id == 6 ? FontWeight.w900 : FontWeight.w700,
          color: AppColors.primaryNavy,
        ),
      );
    }
    if (item.category == StoreCategory.avatar) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primaryCoral,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mood_rounded, color: Colors.white, size: 24),
      );
    }
    if (item.category == StoreCategory.victory) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.softYellow,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.primaryNavy,
          size: 24,
        ),
      );
    }
    if (item.category == StoreCategory.frame) {
      return Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: AppColors.softYellowDark,
          shape: BoxShape.circle,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.primaryNavy,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.graphic_eq_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  Widget _buildCardFooter(StoreItem item, int currentChips) {
    if (item.status.isEquipped) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'FREE',
            style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 11,
                  color: AppColors.primaryNavy,
                ),
                const SizedBox(width: 3),
                Text(
                  'EQUIPPED',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (item.status.isOwned) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'OWNED',
            style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
          ),
          InkWell(
            onTap: () async {
              await ref.read(storeRepositoryProvider).equipItem(item.id);
            },
            borderRadius: AppRadii.roundedFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: AppRadii.roundedFull,
              ),
              child: Text(
                'EQUIP',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 8.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final hasEnough = currentChips >= item.price;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              '${item.price}',
              style: AppTypography.labelSm.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.token_rounded,
              size: 11,
              color: AppColors.primaryCoral,
            ),
          ],
        ),
        InkWell(
          onTap: hasEnough
              ? () async {
                  await ref.read(storeRepositoryProvider).purchaseItem(item.id);
                }
              : null,
          borderRadius: AppRadii.roundedFull,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: hasEnough
                  ? AppColors.primaryCoral
                  : AppColors.surfaceContainerHigh,
              borderRadius: AppRadii.roundedFull,
            ),
            child: Text(
              hasEnough ? 'BUY' : 'LOCKED',
              style: AppTypography.labelSm.copyWith(
                fontSize: 8.5,
                color: hasEnough ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
