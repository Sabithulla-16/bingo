import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Visual configuration styling a 5x5 BINGO board matrix and its individual cells.
class BoardThemeConfig {
  final String key;
  final String name;
  final Color boardBackground;
  final Color boardBorder;
  final Color headerTextColor;

  // Unmarked cell
  final Color cellAvailableBackground;
  final Color cellAvailableBorder;
  final Color cellAvailableText;

  // Called cell
  final Color cellCalledBackground;
  final Color cellCalledBorder;
  final Color cellCalledText;

  // Completed line (unclaimed)
  final Color cellCompletedBackground;
  final Color cellCompletedBorder;
  final Color cellCompletedText;

  // Claimed line
  final Color cellClaimedBackground;
  final Color cellClaimedBorder;
  final Color cellClaimedText;
  final Color stampRingColor;

  Color get cellAvailableTextColor => cellAvailableText;
  Color get cellCalledTextColor => cellCalledText;
  Color get cellCompletedTextColor => cellCompletedText;
  Color get cellClaimedTextColor => cellClaimedText;

  const BoardThemeConfig({
    required this.key,
    required this.name,
    required this.boardBackground,
    required this.boardBorder,
    required this.headerTextColor,
    required this.cellAvailableBackground,
    required this.cellAvailableBorder,
    required this.cellAvailableText,
    required this.cellCalledBackground,
    required this.cellCalledBorder,
    required this.cellCalledText,
    required this.cellCompletedBackground,
    required this.cellCompletedBorder,
    required this.cellCompletedText,
    required this.cellClaimedBackground,
    required this.cellClaimedBorder,
    required this.cellClaimedText,
    required this.stampRingColor,
  });

  /// Classic Cream theme (Default free theme)
  factory BoardThemeConfig.classic() {
    return const BoardThemeConfig(
      key: 'classic',
      name: 'Classic Cream',
      boardBackground: Color(0xFFF5F3EC),
      boardBorder: Color(0xFFE5E0D3),
      headerTextColor: AppColors.primaryNavy,
      cellAvailableBackground: Colors.white,
      cellAvailableBorder: AppColors.structuralBorder,
      cellAvailableText: AppColors.primaryNavy,
      cellCalledBackground: AppColors.lightLavender,
      cellCalledBorder: AppColors.primaryNavy,
      cellCalledText: AppColors.primaryNavy,
      cellCompletedBackground: AppColors.softYellow,
      cellCompletedBorder: AppColors.primaryCoral,
      cellCompletedText: AppColors.primaryNavy,
      cellClaimedBackground: AppColors.primaryCoral,
      cellClaimedBorder: AppColors.primaryCoral,
      cellClaimedText: Colors.white,
      stampRingColor: Color(0x40FFFFFF),
    );
  }

  /// Lavender Dream theme
  factory BoardThemeConfig.lavender() {
    return const BoardThemeConfig(
      key: 'lavender',
      name: 'Lavender Dream',
      boardBackground: Color(0xFFEBE8F7),
      boardBorder: Color(0xFFD9D3F3),
      headerTextColor: Color(0xFF2E274D),
      cellAvailableBackground: Colors.white,
      cellAvailableBorder: Color(0xFFD9D3F3),
      cellAvailableText: Color(0xFF2E274D),
      cellCalledBackground: Color(0xFFDCD6F7),
      cellCalledBorder: Color(0xFF7C66DC),
      cellCalledText: Color(0xFF2E274D),
      cellCompletedBackground: Color(0xFFFEF3C7),
      cellCompletedBorder: Color(0xFF7C66DC),
      cellCompletedText: Color(0xFF2E274D),
      cellClaimedBackground: Color(0xFF7C66DC),
      cellClaimedBorder: Color(0xFF7C66DC),
      cellClaimedText: Colors.white,
      stampRingColor: Color(0x40FFFFFF),
    );
  }

  /// Midnight Blue theme
  factory BoardThemeConfig.midnight() {
    return const BoardThemeConfig(
      key: 'midnight',
      name: 'Midnight Blue',
      boardBackground: Color(0xFF1E2338),
      boardBorder: Color(0xFF2C3352),
      headerTextColor: Color(0xFFC2C5E2),
      cellAvailableBackground: Color(0xFF242A42),
      cellAvailableBorder: Color(0xFF323B5C),
      cellAvailableText: Color(0xFFC2C5E2),
      cellCalledBackground: Color(0xFF353E63),
      cellCalledBorder: Color(0xFFC2C5E2),
      cellCalledText: Colors.white,
      cellCompletedBackground: Color(0xFF3E361D),
      cellCompletedBorder: Color(0xFFFFD043),
      cellCompletedText: Color(0xFFFFD043),
      cellClaimedBackground: AppColors.primaryCoral,
      cellClaimedBorder: AppColors.primaryCoral,
      cellClaimedText: Colors.white,
      stampRingColor: Color(0x55FFFFFF),
    );
  }

  /// Neon Party theme
  factory BoardThemeConfig.neon() {
    return const BoardThemeConfig(
      key: 'neon',
      name: 'Neon Party',
      boardBackground: Color(0xFF141620),
      boardBorder: Color(0xFF2B3045),
      headerTextColor: Color(0xFFFFD043),
      cellAvailableBackground: Color(0xFF1B1E2B),
      cellAvailableBorder: Color(0xFF2F364E),
      cellAvailableText: Color(0xFFE2E8F0),
      cellCalledBackground: Color(0xFF282F48),
      cellCalledBorder: Color(0xFFFFD043),
      cellCalledText: Color(0xFFFFD043),
      cellCompletedBackground: Color(0xFF3D3212),
      cellCompletedBorder: Color(0xFFFFD043),
      cellCompletedText: Color(0xFFFFD043),
      cellClaimedBackground: Color(0xFFFF4757),
      cellClaimedBorder: Color(0xFFFF4757),
      cellClaimedText: Colors.white,
      stampRingColor: Color(0x60FFFFFF),
    );
  }

  factory BoardThemeConfig.fromKey(String key) {
    switch (key.toLowerCase()) {
      case 'lavender':
        return BoardThemeConfig.lavender();
      case 'midnight':
        return BoardThemeConfig.midnight();
      case 'neon':
        return BoardThemeConfig.neon();
      case 'classic':
      default:
        return BoardThemeConfig.classic();
    }
  }

  factory BoardThemeConfig.fromId(int id) {
    switch (id) {
      case 2:
        return BoardThemeConfig.lavender();
      case 3:
        return BoardThemeConfig.midnight();
      case 4:
        return BoardThemeConfig.neon();
      case 1:
      default:
        return BoardThemeConfig.classic();
    }
  }
}
