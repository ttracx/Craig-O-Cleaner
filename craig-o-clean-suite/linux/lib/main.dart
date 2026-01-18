import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:craig_o_clean/app.dart';
import 'package:craig_o_clean/services/tray_service.dart';
import 'package:craig_o_clean/services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for Linux desktop
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1024, 768),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Craig-O-Clean',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Create a provider container for services initialization
  final container = ProviderContainer();

  // Initialize system tray (optional, graceful degradation)
  try {
    final trayService = container.read(trayServiceProvider);
    await trayService.initialize();
  } catch (e) {
    // Tray not supported in this DE, continue without it
    debugPrint('System tray initialization failed: $e');
  }

  // Initialize deep link handling
  try {
    final deepLinkService = container.read(deepLinkServiceProvider);
    await deepLinkService.initialize();
  } catch (e) {
    debugPrint('Deep link initialization failed: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CraigOCleanApp(),
    ),
  );
}

/// Check if running under Wayland
bool isWayland() {
  return Platform.environment['XDG_SESSION_TYPE'] == 'wayland' ||
      Platform.environment['WAYLAND_DISPLAY'] != null;
}

/// Check if running under X11
bool isX11() {
  return Platform.environment['XDG_SESSION_TYPE'] == 'x11' ||
      Platform.environment['DISPLAY'] != null;
}
