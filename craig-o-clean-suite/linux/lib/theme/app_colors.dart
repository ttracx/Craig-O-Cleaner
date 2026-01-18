import 'package:flutter/material.dart';

/// VibeCaaS color palette for Craig-O-Clean
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color vibePurple = Color(0xFF6D4AFF);
  static const Color aquaTeal = Color(0xFF14B8A6);
  static const Color signalAmber = Color(0xFFFF8C00);

  // Semantic Colors
  static const Color success = aquaTeal;
  static const Color warning = signalAmber;
  static const Color error = Color(0xFFEF4444);
  static const Color info = vibePurple;

  // Memory Pressure Colors
  static const Color pressureNormal = aquaTeal;
  static const Color pressureElevated = signalAmber;
  static const Color pressureCritical = error;

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color black = Color(0xFF000000);

  // Light Theme Colors
  static const Color lightBackground = gray50;
  static const Color lightSurface = white;
  static const Color lightSurfaceVariant = gray100;
  static const Color lightOnBackground = gray900;
  static const Color lightOnSurface = gray800;
  static const Color lightOnSurfaceVariant = gray600;
  static const Color lightOutline = gray300;

  // Dark Theme Colors
  static const Color darkBackground = gray900;
  static const Color darkSurface = gray800;
  static const Color darkSurfaceVariant = gray700;
  static const Color darkOnBackground = gray50;
  static const Color darkOnSurface = gray100;
  static const Color darkOnSurfaceVariant = gray400;
  static const Color darkOutline = gray600;

  // Brand Gradient
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [vibePurple, aquaTeal],
  );

  // Surface Gradient (Light)
  static const LinearGradient lightSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gray50, white],
  );

  // Surface Gradient (Dark)
  static const LinearGradient darkSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gray900, gray800],
  );

  /// Get color for memory pressure level
  static Color getPressureColor(MemoryPressure pressure) {
    switch (pressure) {
      case MemoryPressure.normal:
        return pressureNormal;
      case MemoryPressure.elevated:
        return pressureElevated;
      case MemoryPressure.critical:
        return pressureCritical;
    }
  }

  /// Get color for CPU usage percentage
  static Color getCpuUsageColor(double percentage) {
    if (percentage < 50) {
      return success;
    } else if (percentage < 80) {
      return warning;
    } else {
      return error;
    }
  }

  /// Get color for memory usage percentage
  static Color getMemoryUsageColor(double percentage) {
    if (percentage < 60) {
      return success;
    } else if (percentage < 85) {
      return warning;
    } else {
      return error;
    }
  }
}

/// Memory pressure levels
enum MemoryPressure {
  normal,
  elevated,
  critical,
}
