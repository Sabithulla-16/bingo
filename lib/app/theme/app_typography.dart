import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typographic styles from the BINGO "Velvet Daub" Stitch design system.
/// Powered by Google Font Outfit with proper fallbacks and tabular figures.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Outfit';

  static TextStyle get displayHero => GoogleFonts.outfit(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 52 / 48,
    letterSpacing: -1.44,
    color: AppColors.primaryNavy,
  );

  static TextStyle get displayHeroMobile => GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 40 / 36,
    letterSpacing: -0.72,
    color: AppColors.primaryNavy,
  );

  static TextStyle get headlineLg => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 38 / 32,
    letterSpacing: -0.64,
    color: AppColors.primaryNavy,
  );

  static TextStyle get headlineLgMobile => GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 32 / 26,
    letterSpacing: -0.26,
    color: AppColors.primaryNavy,
  );

  static TextStyle get headlineMd => GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    color: AppColors.primaryNavy,
  );

  static TextStyle get headlineSm => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: AppColors.primaryNavy,
  );

  static TextStyle get bingoBallCall => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.primaryNavy,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get bingoNumber => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.primaryNavy,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get bodyLg => GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMd => GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySm => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelLg => GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 18 / 14,
    letterSpacing: 0.56,
    color: AppColors.primaryNavy,
  );

  static TextStyle get labelMd => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.60,
    color: AppColors.primaryNavy,
  );

  static TextStyle get labelSm => GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 12 / 10,
    letterSpacing: 0.60,
    color: AppColors.textSecondary,
  );
}
