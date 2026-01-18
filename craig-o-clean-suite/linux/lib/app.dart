import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craig_o_clean/theme/app_theme.dart';
import 'package:craig_o_clean/screens/main_screen.dart';
import 'package:craig_o_clean/providers/theme_provider.dart';

/// The main application widget for Craig-O-Clean
class CraigOCleanApp extends ConsumerWidget {
  const CraigOCleanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Craig-O-Clean',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
