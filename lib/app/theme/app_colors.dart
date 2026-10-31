import 'package:flutter/material.dart';

/// Design tokens for BINGO's "Velvet Daub" color palette extracted from Google Stitch.
class AppColors {
  const AppColors._();

  // Canvas & Backgrounds
  static const Color background = Color(0xFFFAFAF7);
  static const Color canvas = background;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F4F1);
  static const Color surfaceContainer = Color(0xFFEEEEEB);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E5);
  static const Color surfaceContainerHighest = Color(0xFFE2E3E0);

  // Primary Structure
  static const Color primaryNavy = Color(0xFF20243A);
  static const Color primaryDark = Color(0xFF0B0F24);

  // Interaction Sparks & Accents
  static const Color primaryCoral = Color(0xFFFF6B5E);
  static const Color primaryCoralVariant = Color(0xFFFC695C);
  static const Color softYellow = Color(0xFFFFD166);
  static const Color softYellowDark = Color(0xFFAD8722);
  static const Color lightLavender = Color(0xFFE8E5FF);

  // Semantic & Feedback
  static const Color readyGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFBA1A1A);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF1A1C1B);
  static const Color textSecondary = Color(0xFF46464D);
  static const Color textMuted = Color(0xFF77767D);
  static const Color textTertiary = textMuted;
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textLight = textOnPrimary;

  // Elevation & Border Strokes
  static const Color structuralBorder = Color(0x1420243A); // 8% navy stroke
  static const Color cardShadowColor = Color(0x1F20243A); // 12% navy offset
  static const Color scrimOverlayColor = Color(
    0x6620243A,
  ); // 40% primary navy scrim
}
