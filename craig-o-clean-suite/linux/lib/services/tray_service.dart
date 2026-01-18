import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'package:craig_o_clean/providers/system_metrics_provider.dart';
import 'package:craig_o_clean/providers/entitlement_provider.dart';

/// Provider for the tray service
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService(ref);
});

/// Service for managing the system tray icon using StatusNotifier protocol
class TrayService {
  TrayService(this._ref);

  final Ref _ref;
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;

  /// Initialize the system tray
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize system tray
      await _systemTray.initSystemTray(
        title: 'Craig-O-Clean',
        iconPath: _getIconPath(),
        toolTip: 'Craig-O-Clean - System Resource Manager',
      );

      // Build context menu
      await _buildContextMenu();

      // Register event handlers
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _onTrayClick();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;

      // Start updating tray tooltip with metrics
      _startMetricsUpdate();
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
      rethrow;
    }
  }

  /// Get the appropriate icon path
  String _getIconPath() {
    // Check common icon locations
    final iconPaths = [
      '/usr/share/icons/hicolor/256x256/apps/craig-o-clean.png',
      '/usr/share/pixmaps/craig-o-clean.png',
      '/opt/craig-o-clean/data/flutter_assets/assets/icons/app_icon.png',
      'assets/icons/app_icon.png',
    ];

    for (final path in iconPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // Return default path
    return 'assets/icons/app_icon.png';
  }

  /// Build the context menu
  Future<void> _buildContextMenu() async {
    final menu = Menu();

    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show Craig-O-Clean',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'CPU Usage',
        enabled: false,
        onClicked: (menuItem) {},
      ),
      MenuItemLabel(
        label: 'Memory Usage',
        enabled: false,
        onClicked: (menuItem) {},
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Dashboard',
        onClicked: (menuItem) => _navigateTo('dashboard'),
      ),
      MenuItemLabel(
        label: 'Process Manager',
        onClicked: (menuItem) => _navigateTo('processes'),
      ),
      MenuItemLabel(
        label: 'Settings',
        onClicked: (menuItem) => _navigateTo('settings'),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Quit',
        onClicked: (menuItem) => _quit(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// Handle tray icon click
  void _onTrayClick() {
    _showWindow();
  }

  /// Show the main window
  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Hide the window to tray
  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  /// Navigate to a specific screen
  void _navigateTo(String screen) {
    _showWindow();
    // Navigation will be handled by the app
  }

  /// Quit the application
  Future<void> _quit() async {
    await destroy();
    exit(0);
  }

  /// Start updating the tray tooltip with metrics
  void _startMetricsUpdate() {
    // Listen to metrics updates
    _ref.listen<AsyncValue<dynamic>>(
      systemMetricsProvider,
      (previous, next) {
        next.whenData((metrics) {
          _updateTooltip(metrics);
          _updateContextMenu(metrics);
        });
      },
    );
  }

  /// Update the tooltip with current metrics
  Future<void> _updateTooltip(dynamic metrics) async {
    try {
      final cpuUsage = metrics.cpu.usagePercent.toStringAsFixed(1);
      final memUsage = metrics.memory.usagePercent.toStringAsFixed(1);

      await _systemTray.setToolTip(
        'Craig-O-Clean\nCPU: $cpuUsage%\nMemory: $memUsage%',
      );
    } catch (e) {
      // Ignore tooltip update errors
    }
  }

  /// Update the context menu with current metrics
  Future<void> _updateContextMenu(dynamic metrics) async {
    try {
      final hasPremium = _ref.read(hasPremiumAccessProvider);

      final cpuUsage = metrics.cpu.usagePercent.toStringAsFixed(1);
      final memUsage = metrics.memory.usagePercent.toStringAsFixed(1);
      final memUsed = _formatBytes(metrics.memory.usedBytes);
      final memTotal = _formatBytes(metrics.memory.totalBytes);

      final menu = Menu();

      final items = <MenuItemBase>[
        MenuItemLabel(
          label: 'Show Craig-O-Clean',
          onClicked: (menuItem) => _showWindow(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'CPU: $cpuUsage%',
          enabled: false,
          onClicked: (menuItem) {},
        ),
        MenuItemLabel(
          label: 'Memory: $memUsage% ($memUsed / $memTotal)',
          enabled: false,
          onClicked: (menuItem) {},
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Dashboard',
          onClicked: (menuItem) => _navigateTo('dashboard'),
        ),
        MenuItemLabel(
          label: 'Process Manager',
          onClicked: (menuItem) => _navigateTo('processes'),
        ),
        MenuItemLabel(
          label: 'Settings',
          onClicked: (menuItem) => _navigateTo('settings'),
        ),
      ];

      // Add quick actions for premium users
      if (hasPremium) {
        items.addAll([
          MenuSeparator(),
          SubMenu(
            label: 'Quick Actions',
            children: [
              MenuItemLabel(
                label: 'Kill Top CPU Process',
                onClicked: (menuItem) => _killTopCpuProcess(),
              ),
              MenuItemLabel(
                label: 'Kill Top Memory Process',
                onClicked: (menuItem) => _killTopMemoryProcess(),
              ),
            ],
          ),
        ]);
      }

      items.addAll([
        MenuSeparator(),
        MenuItemLabel(
          label: 'Quit',
          onClicked: (menuItem) => _quit(),
        ),
      ]);

      await menu.buildFrom(items);
      await _systemTray.setContextMenu(menu);
    } catch (e) {
      // Ignore context menu update errors
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Kill the top CPU consuming process
  Future<void> _killTopCpuProcess() async {
    // This would be implemented with the process provider
    _showWindow();
  }

  /// Kill the top memory consuming process
  Future<void> _killTopMemoryProcess() async {
    // This would be implemented with the process provider
    _showWindow();
  }

  /// Update the tray icon (e.g., to show status)
  Future<void> setIcon(String iconPath) async {
    try {
      await _systemTray.setImage(iconPath);
    } catch (e) {
      // Ignore icon update errors
    }
  }

  /// Destroy the system tray
  Future<void> destroy() async {
    if (_isInitialized) {
      await _systemTray.destroy();
      _isInitialized = false;
    }
  }
}
