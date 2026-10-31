import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radii.dart';

/// Central Material 3 ThemeData customized to the Stitch Velvet Daub design tokens.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryNavy,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryNavy,
        onPrimaryContainer: AppColors.textOnPrimary,
        secondary: AppColors.primaryCoral,
        onSecondary: AppColors.textOnPrimary,
        secondaryContainer: AppColors.primaryCoralVariant,
        onSecondaryContainer: AppColors.textOnPrimary,
        tertiary: AppColors.softYellow,
        onTertiary: AppColors.primaryNavy,
        tertiaryContainer: AppColors.softYellowDark,
        onTertiaryContainer: AppColors.primaryNavy,
        error: AppColors.errorRed,
        onError: AppColors.textOnPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        outline: AppColors.textMuted,
        outlineVariant: AppColors.surfaceContainerHighest,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.primaryNavy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedXl,
          side: const BorderSide(color: AppColors.structuralBorder, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryCoral,
          foregroundColor: AppColors.textOnPrimary,
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.56,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedLg,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedLg,
          borderSide: const BorderSide(
            color: AppColors.primaryNavy,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
      ),
    );
  }
}
