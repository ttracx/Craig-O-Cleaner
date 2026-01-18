import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Provider for theme mode
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Provider for checking if dark mode is active
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  return themeMode == ThemeMode.dark;
});

/// State notifier for theme mode management
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  static const _themeFileName = 'theme.json';

  Future<String> _getThemeFilePath() async {
    final appDir = await getApplicationSupportDirectory();
    final settingsDir =
        Directory(path.join(appDir.path, 'craig-o-clean'));
    if (!settingsDir.existsSync()) {
      await settingsDir.create(recursive: true);
    }
    return path.join(settingsDir.path, _themeFileName);
  }

  Future<void> _loadThemeMode() async {
    try {
      final filePath = await _getThemeFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        final themeName = json['themeMode'] as String?;

        if (themeName != null) {
          state = ThemeMode.values.firstWhere(
            (mode) => mode.name == themeName,
            orElse: () => ThemeMode.system,
          );
        }
      }
    } catch (e) {
      // Keep default theme on error
    }
  }

  Future<void> _saveThemeMode() async {
    try {
      final filePath = await _getThemeFilePath();
      final file = File(filePath);
      final json = jsonEncode({'themeMode': state.name});
      await file.writeAsString(json);
    } catch (e) {
      // Silently fail
    }
  }

  /// Set theme mode
  void setThemeMode(ThemeMode mode) {
    state = mode;
    _saveThemeMode();
  }

  /// Toggle between light and dark mode
  void toggleTheme() {
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
    _saveThemeMode();
  }

  /// Set light mode
  void setLightMode() {
    state = ThemeMode.light;
    _saveThemeMode();
  }

  /// Set dark mode
  void setDarkMode() {
    state = ThemeMode.dark;
    _saveThemeMode();
  }

  /// Set system mode
  void setSystemMode() {
    state = ThemeMode.system;
    _saveThemeMode();
  }
}
