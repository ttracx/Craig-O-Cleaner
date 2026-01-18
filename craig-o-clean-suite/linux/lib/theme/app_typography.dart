import 'package:flutter/material.dart';

import 'package:craig_o_clean/theme/app_colors.dart';

/// Typography configuration for Craig-O-Clean
class AppTypography {
  AppTypography._();

  // Font Families
  static const String primaryFontFamily = 'Ubuntu';
  static const String monospaceFontFamily = 'UbuntuMono';

  // Font Fallbacks for Linux
  static const List<String> primaryFontFallback = [
    'Ubuntu',
    'Cantarell',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> monospaceFontFallback = [
    'Ubuntu Mono',
    'Cascadia Code',
    'Consolas',
    'monospace',
  ];

  // Text Styles for Light Theme
  static TextTheme get lightTextTheme => _baseTextTheme.apply(
        bodyColor: AppColors.lightOnSurface,
        displayColor: AppColors.lightOnBackground,
      );

  // Text Styles for Dark Theme
  static TextTheme get darkTextTheme => _baseTextTheme.apply(
        bodyColor: AppColors.darkOnSurface,
        displayColor: AppColors.darkOnBackground,
      );

  static TextTheme get _baseTextTheme => const TextTheme(
        // Display Styles
        displayLarge: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 36,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 30,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.25,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.25,
        ),

        // Headline Styles
        headlineLarge: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 0,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.35,
        ),
        headlineSmall: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.4,
        ),

        // Title Styles
        titleLarge: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          height: 1.45,
        ),
        titleSmall: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.5,
        ),

        // Body Styles
        bodyLarge: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.15,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.25,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.4,
          height: 1.5,
        ),

        // Label Styles
        labelLarge: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          fontFamily: primaryFontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.4,
        ),
      );

  // Monospace Text Style for metrics and technical data
  static TextStyle get monoMedium => const TextStyle(
        fontFamily: monospaceFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0,
        height: 1.4,
      );

  static TextStyle get monoLarge => const TextStyle(
        fontFamily: monospaceFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      );

  static TextStyle get monoSmall => const TextStyle(
        fontFamily: monospaceFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0,
        height: 1.4,
      );

  static TextStyle get monoXLarge => const TextStyle(
        fontFamily: monospaceFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        height: 1.2,
      );
}
