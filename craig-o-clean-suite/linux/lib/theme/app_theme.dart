import 'package:flutter/material.dart';

import 'package:craig_o_clean/theme/app_colors.dart';
import 'package:craig_o_clean/theme/app_typography.dart';

/// Application theme configuration using Material 3 with VibeCaaS branding
class AppTheme {
  AppTheme._();

  // Border Radius
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radius2xl = 24;

  // Spacing
  static const double spacing1 = 4;
  static const double spacing2 = 8;
  static const double spacing3 = 12;
  static const double spacing4 = 16;
  static const double spacing5 = 20;
  static const double spacing6 = 24;
  static const double spacing8 = 32;
  static const double spacing10 = 40;
  static const double spacing12 = 48;

  // Card dimensions
  static const double cardPadding = 16;
  static const double cardRadius = 12;

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightColorScheme,
        textTheme: AppTypography.lightTextTheme,
        scaffoldBackgroundColor: AppColors.lightBackground,
        cardTheme: _lightCardTheme,
        appBarTheme: _lightAppBarTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme,
        textButtonTheme: _textButtonTheme,
        filledButtonTheme: _filledButtonTheme,
        iconButtonTheme: _iconButtonTheme,
        inputDecorationTheme: _lightInputDecorationTheme,
        dividerTheme: _lightDividerTheme,
        dialogTheme: _lightDialogTheme,
        snackBarTheme: _lightSnackBarTheme,
        progressIndicatorTheme: _progressIndicatorTheme,
        sliderTheme: _sliderTheme,
        switchTheme: _switchTheme,
        checkboxTheme: _checkboxTheme,
        chipTheme: _lightChipTheme,
        tooltipTheme: _lightTooltipTheme,
        navigationRailTheme: _lightNavigationRailTheme,
        listTileTheme: _lightListTileTheme,
      );

  // Dark Theme
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        textTheme: AppTypography.darkTextTheme,
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardTheme: _darkCardTheme,
        appBarTheme: _darkAppBarTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme,
        textButtonTheme: _textButtonTheme,
        filledButtonTheme: _filledButtonTheme,
        iconButtonTheme: _iconButtonTheme,
        inputDecorationTheme: _darkInputDecorationTheme,
        dividerTheme: _darkDividerTheme,
        dialogTheme: _darkDialogTheme,
        snackBarTheme: _darkSnackBarTheme,
        progressIndicatorTheme: _progressIndicatorTheme,
        sliderTheme: _sliderTheme,
        switchTheme: _switchTheme,
        checkboxTheme: _checkboxTheme,
        chipTheme: _darkChipTheme,
        tooltipTheme: _darkTooltipTheme,
        navigationRailTheme: _darkNavigationRailTheme,
        listTileTheme: _darkListTileTheme,
      );

  // Light Color Scheme
  static ColorScheme get _lightColorScheme => const ColorScheme.light(
        primary: AppColors.vibePurple,
        onPrimary: AppColors.white,
        primaryContainer: Color(0xFFE8E0FF),
        onPrimaryContainer: Color(0xFF21005D),
        secondary: AppColors.aquaTeal,
        onSecondary: AppColors.white,
        secondaryContainer: Color(0xFFB2F5EA),
        onSecondaryContainer: Color(0xFF00201C),
        tertiary: AppColors.signalAmber,
        onTertiary: AppColors.white,
        tertiaryContainer: Color(0xFFFFDDB3),
        onTertiaryContainer: Color(0xFF2E1500),
        error: AppColors.error,
        onError: AppColors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF7F1D1D),
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightOnSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurfaceVariant: AppColors.lightOnSurfaceVariant,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.gray200,
        shadow: AppColors.black,
        scrim: AppColors.black,
        inverseSurface: AppColors.gray800,
        onInverseSurface: AppColors.gray100,
        inversePrimary: Color(0xFFCFBCFF),
      );

  // Dark Color Scheme
  static ColorScheme get _darkColorScheme => const ColorScheme.dark(
        primary: AppColors.vibePurple,
        onPrimary: AppColors.white,
        primaryContainer: Color(0xFF4A3280),
        onPrimaryContainer: Color(0xFFE8E0FF),
        secondary: AppColors.aquaTeal,
        onSecondary: AppColors.white,
        secondaryContainer: Color(0xFF0D6F63),
        onSecondaryContainer: Color(0xFFB2F5EA),
        tertiary: AppColors.signalAmber,
        onTertiary: AppColors.white,
        tertiaryContainer: Color(0xFF7A4F00),
        onTertiaryContainer: Color(0xFFFFDDB3),
        error: AppColors.error,
        onError: AppColors.white,
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: Color(0xFFFEE2E2),
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.gray700,
        shadow: AppColors.black,
        scrim: AppColors.black,
        inverseSurface: AppColors.gray100,
        onInverseSurface: AppColors.gray800,
        inversePrimary: AppColors.vibePurple,
      );

  // Card Themes
  static CardTheme get _lightCardTheme => CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.gray200),
        ),
        color: AppColors.lightSurface,
        margin: EdgeInsets.zero,
      );

  static CardTheme get _darkCardTheme => CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.gray700),
        ),
        color: AppColors.darkSurface,
        margin: EdgeInsets.zero,
      );

  // AppBar Themes
  static AppBarTheme get _lightAppBarTheme => const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightOnBackground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      );

  static AppBarTheme get _darkAppBarTheme => const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkOnBackground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      );

  // Button Themes
  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vibePurple,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          minimumSize: const Size(64, 40),
        ),
      );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.vibePurple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: AppColors.vibePurple),
          minimumSize: const Size(64, 40),
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.vibePurple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          minimumSize: const Size(64, 40),
        ),
      );

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.vibePurple,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          minimumSize: const Size(64, 40),
        ),
      );

  static IconButtonThemeData get _iconButtonTheme => IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      );

  // Input Decoration Themes
  static InputDecorationTheme get _lightInputDecorationTheme =>
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.vibePurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  static InputDecorationTheme get _darkInputDecorationTheme =>
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.gray800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.gray600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.gray600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.vibePurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  // Divider Themes
  static DividerThemeData get _lightDividerTheme => const DividerThemeData(
        color: AppColors.gray200,
        thickness: 1,
        space: 1,
      );

  static DividerThemeData get _darkDividerTheme => const DividerThemeData(
        color: AppColors.gray700,
        thickness: 1,
        space: 1,
      );

  // Dialog Themes
  static DialogTheme get _lightDialogTheme => DialogTheme(
        backgroundColor: AppColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      );

  static DialogTheme get _darkDialogTheme => DialogTheme(
        backgroundColor: AppColors.gray800,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      );

  // SnackBar Themes
  static SnackBarThemeData get _lightSnackBarTheme => SnackBarThemeData(
        backgroundColor: AppColors.gray800,
        contentTextStyle: const TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      );

  static SnackBarThemeData get _darkSnackBarTheme => SnackBarThemeData(
        backgroundColor: AppColors.gray100,
        contentTextStyle: const TextStyle(color: AppColors.gray900),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      );

  // Progress Indicator Theme
  static ProgressIndicatorThemeData get _progressIndicatorTheme =>
      const ProgressIndicatorThemeData(
        color: AppColors.vibePurple,
        linearTrackColor: AppColors.gray200,
        circularTrackColor: AppColors.gray200,
      );

  // Slider Theme
  static SliderThemeData get _sliderTheme => SliderThemeData(
        activeTrackColor: AppColors.vibePurple,
        inactiveTrackColor: AppColors.gray300,
        thumbColor: AppColors.vibePurple,
        overlayColor: AppColors.vibePurple.withValues(alpha: 0.12),
        trackHeight: 4,
      );

  // Switch Theme
  static SwitchThemeData get _switchTheme => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.vibePurple;
          }
          return AppColors.gray400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.vibePurple.withValues(alpha: 0.5);
          }
          return AppColors.gray300;
        }),
      );

  // Checkbox Theme
  static CheckboxThemeData get _checkboxTheme => CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.vibePurple;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.white),
        side: const BorderSide(color: AppColors.gray400, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      );

  // Chip Themes
  static ChipThemeData get _lightChipTheme => ChipThemeData(
        backgroundColor: AppColors.gray100,
        selectedColor: AppColors.vibePurple.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: AppColors.gray700),
        secondaryLabelStyle: const TextStyle(color: AppColors.vibePurple),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  static ChipThemeData get _darkChipTheme => ChipThemeData(
        backgroundColor: AppColors.gray700,
        selectedColor: AppColors.vibePurple.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: AppColors.gray200),
        secondaryLabelStyle: const TextStyle(color: AppColors.vibePurple),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  // Tooltip Themes
  static TooltipThemeData get _lightTooltipTheme => TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.gray800,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(color: AppColors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  static TooltipThemeData get _darkTooltipTheme => TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(color: AppColors.gray900, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  // Navigation Rail Themes
  static NavigationRailThemeData get _lightNavigationRailTheme =>
      const NavigationRailThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedIconTheme: IconThemeData(color: AppColors.vibePurple),
        unselectedIconTheme: IconThemeData(color: AppColors.gray500),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.vibePurple,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: TextStyle(color: AppColors.gray500),
        indicatorColor: Color(0xFFE8E0FF),
      );

  static NavigationRailThemeData get _darkNavigationRailTheme =>
      const NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedIconTheme: IconThemeData(color: AppColors.vibePurple),
        unselectedIconTheme: IconThemeData(color: AppColors.gray400),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.vibePurple,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: TextStyle(color: AppColors.gray400),
        indicatorColor: Color(0xFF4A3280),
      );

  // List Tile Themes
  static ListTileThemeData get _lightListTileTheme => ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.vibePurple.withValues(alpha: 0.1),
      );

  static ListTileThemeData get _darkListTileTheme => ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.vibePurple.withValues(alpha: 0.2),
      );
}
