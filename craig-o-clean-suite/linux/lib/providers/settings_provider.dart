import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// App settings model
class AppSettings {
  const AppSettings({
    this.refreshInterval = 2,
    this.startMinimized = false,
    this.minimizeToTray = true,
    this.showNotifications = true,
    this.cpuWarningThreshold = 80,
    this.memoryWarningThreshold = 85,
    this.autoStartOnLogin = false,
    this.showSystemProcesses = false,
    this.confirmBeforeKill = true,
    this.enableMetricsHistory = true,
    this.metricsHistoryDuration = 60,
    this.defaultProcessSortField = 'cpu',
    this.defaultProcessSortOrder = 'descending',
  });

  final int refreshInterval; // seconds
  final bool startMinimized;
  final bool minimizeToTray;
  final bool showNotifications;
  final int cpuWarningThreshold;
  final int memoryWarningThreshold;
  final bool autoStartOnLogin;
  final bool showSystemProcesses;
  final bool confirmBeforeKill;
  final bool enableMetricsHistory;
  final int metricsHistoryDuration; // seconds
  final String defaultProcessSortField;
  final String defaultProcessSortOrder;

  AppSettings copyWith({
    int? refreshInterval,
    bool? startMinimized,
    bool? minimizeToTray,
    bool? showNotifications,
    int? cpuWarningThreshold,
    int? memoryWarningThreshold,
    bool? autoStartOnLogin,
    bool? showSystemProcesses,
    bool? confirmBeforeKill,
    bool? enableMetricsHistory,
    int? metricsHistoryDuration,
    String? defaultProcessSortField,
    String? defaultProcessSortOrder,
  }) {
    return AppSettings(
      refreshInterval: refreshInterval ?? this.refreshInterval,
      startMinimized: startMinimized ?? this.startMinimized,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      showNotifications: showNotifications ?? this.showNotifications,
      cpuWarningThreshold: cpuWarningThreshold ?? this.cpuWarningThreshold,
      memoryWarningThreshold:
          memoryWarningThreshold ?? this.memoryWarningThreshold,
      autoStartOnLogin: autoStartOnLogin ?? this.autoStartOnLogin,
      showSystemProcesses: showSystemProcesses ?? this.showSystemProcesses,
      confirmBeforeKill: confirmBeforeKill ?? this.confirmBeforeKill,
      enableMetricsHistory: enableMetricsHistory ?? this.enableMetricsHistory,
      metricsHistoryDuration:
          metricsHistoryDuration ?? this.metricsHistoryDuration,
      defaultProcessSortField:
          defaultProcessSortField ?? this.defaultProcessSortField,
      defaultProcessSortOrder:
          defaultProcessSortOrder ?? this.defaultProcessSortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'refreshInterval': refreshInterval,
        'startMinimized': startMinimized,
        'minimizeToTray': minimizeToTray,
        'showNotifications': showNotifications,
        'cpuWarningThreshold': cpuWarningThreshold,
        'memoryWarningThreshold': memoryWarningThreshold,
        'autoStartOnLogin': autoStartOnLogin,
        'showSystemProcesses': showSystemProcesses,
        'confirmBeforeKill': confirmBeforeKill,
        'enableMetricsHistory': enableMetricsHistory,
        'metricsHistoryDuration': metricsHistoryDuration,
        'defaultProcessSortField': defaultProcessSortField,
        'defaultProcessSortOrder': defaultProcessSortOrder,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      refreshInterval: json['refreshInterval'] as int? ?? 2,
      startMinimized: json['startMinimized'] as bool? ?? false,
      minimizeToTray: json['minimizeToTray'] as bool? ?? true,
      showNotifications: json['showNotifications'] as bool? ?? true,
      cpuWarningThreshold: json['cpuWarningThreshold'] as int? ?? 80,
      memoryWarningThreshold: json['memoryWarningThreshold'] as int? ?? 85,
      autoStartOnLogin: json['autoStartOnLogin'] as bool? ?? false,
      showSystemProcesses: json['showSystemProcesses'] as bool? ?? false,
      confirmBeforeKill: json['confirmBeforeKill'] as bool? ?? true,
      enableMetricsHistory: json['enableMetricsHistory'] as bool? ?? true,
      metricsHistoryDuration: json['metricsHistoryDuration'] as int? ?? 60,
      defaultProcessSortField:
          json['defaultProcessSortField'] as String? ?? 'cpu',
      defaultProcessSortOrder:
          json['defaultProcessSortOrder'] as String? ?? 'descending',
    );
  }
}

/// Provider for app settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// Provider for refresh interval as Duration
final refreshIntervalDurationProvider = Provider<Duration>((ref) {
  final settings = ref.watch(settingsProvider);
  return Duration(seconds: settings.refreshInterval);
});

/// Provider for CPU warning threshold
final cpuWarningThresholdProvider = Provider<int>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.cpuWarningThreshold;
});

/// Provider for memory warning threshold
final memoryWarningThresholdProvider = Provider<int>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.memoryWarningThreshold;
});

/// State notifier for settings management
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _settingsFileName = 'settings.json';

  Future<String> _getSettingsFilePath() async {
    final appDir = await getApplicationSupportDirectory();
    final settingsDir =
        Directory(path.join(appDir.path, 'craig-o-clean'));
    if (!settingsDir.existsSync()) {
      await settingsDir.create(recursive: true);
    }
    return path.join(settingsDir.path, _settingsFileName);
  }

  Future<void> _loadSettings() async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        state = AppSettings.fromJson(json);
      }
    } catch (e) {
      // Keep default settings on error
    }
  }

  Future<void> _saveSettings() async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);
      final json = jsonEncode(state.toJson());
      await file.writeAsString(json);
    } catch (e) {
      // Silently fail
    }
  }

  /// Update refresh interval
  void setRefreshInterval(int seconds) {
    state = state.copyWith(refreshInterval: seconds);
    _saveSettings();
  }

  /// Update start minimized setting
  void setStartMinimized(bool value) {
    state = state.copyWith(startMinimized: value);
    _saveSettings();
  }

  /// Update minimize to tray setting
  void setMinimizeToTray(bool value) {
    state = state.copyWith(minimizeToTray: value);
    _saveSettings();
  }

  /// Update show notifications setting
  void setShowNotifications(bool value) {
    state = state.copyWith(showNotifications: value);
    _saveSettings();
  }

  /// Update CPU warning threshold
  void setCpuWarningThreshold(int value) {
    state = state.copyWith(cpuWarningThreshold: value);
    _saveSettings();
  }

  /// Update memory warning threshold
  void setMemoryWarningThreshold(int value) {
    state = state.copyWith(memoryWarningThreshold: value);
    _saveSettings();
  }

  /// Update auto start on login
  void setAutoStartOnLogin(bool value) {
    state = state.copyWith(autoStartOnLogin: value);
    _saveSettings();
    _updateAutoStart(value);
  }

  /// Update show system processes
  void setShowSystemProcesses(bool value) {
    state = state.copyWith(showSystemProcesses: value);
    _saveSettings();
  }

  /// Update confirm before kill
  void setConfirmBeforeKill(bool value) {
    state = state.copyWith(confirmBeforeKill: value);
    _saveSettings();
  }

  /// Update enable metrics history
  void setEnableMetricsHistory(bool value) {
    state = state.copyWith(enableMetricsHistory: value);
    _saveSettings();
  }

  /// Update metrics history duration
  void setMetricsHistoryDuration(int seconds) {
    state = state.copyWith(metricsHistoryDuration: seconds);
    _saveSettings();
  }

  /// Update default process sort field
  void setDefaultProcessSortField(String field) {
    state = state.copyWith(defaultProcessSortField: field);
    _saveSettings();
  }

  /// Update default process sort order
  void setDefaultProcessSortOrder(String order) {
    state = state.copyWith(defaultProcessSortOrder: order);
    _saveSettings();
  }

  /// Reset all settings to default
  void resetToDefaults() {
    state = const AppSettings();
    _saveSettings();
  }

  Future<void> _updateAutoStart(bool enabled) async {
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) return;

      final autostartDir = Directory(path.join(homeDir, '.config', 'autostart'));
      if (!autostartDir.existsSync()) {
        await autostartDir.create(recursive: true);
      }

      final desktopFile =
          File(path.join(autostartDir.path, 'craig-o-clean.desktop'));

      if (enabled) {
        final content = '''[Desktop Entry]
Type=Application
Name=Craig-O-Clean
Comment=System resource manager
Exec=craig-o-clean
Icon=craig-o-clean
Terminal=false
Categories=System;Monitor;
StartupNotify=false
X-GNOME-Autostart-enabled=true
''';
        await desktopFile.writeAsString(content);
      } else {
        if (desktopFile.existsSync()) {
          await desktopFile.delete();
        }
      }
    } catch (e) {
      // Silently fail
    }
  }
}
