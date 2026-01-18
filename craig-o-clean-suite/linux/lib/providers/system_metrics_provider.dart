import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craig_o_clean/models/system_metrics.dart';
import 'package:craig_o_clean/services/system_metrics_service.dart';

/// Provider for the system metrics service
final systemMetricsServiceProvider = Provider<SystemMetricsService>((ref) {
  return SystemMetricsService();
});

/// Provider for live system metrics with automatic refresh
final systemMetricsProvider =
    StateNotifierProvider<SystemMetricsNotifier, AsyncValue<SystemMetrics>>(
        (ref) {
  final service = ref.watch(systemMetricsServiceProvider);
  return SystemMetricsNotifier(service);
});

/// Provider for CPU usage history (for charts)
final cpuHistoryProvider = Provider<List<CpuDataPoint>>((ref) {
  final notifier = ref.watch(systemMetricsProvider.notifier);
  return notifier.cpuHistory;
});

/// Provider for memory usage history (for charts)
final memoryHistoryProvider = Provider<List<MemoryDataPoint>>((ref) {
  final notifier = ref.watch(systemMetricsProvider.notifier);
  return notifier.memoryHistory;
});

/// Provider for current CPU usage percentage
final cpuUsageProvider = Provider<double>((ref) {
  final metrics = ref.watch(systemMetricsProvider);
  return metrics.whenOrNull(data: (m) => m.cpu.usagePercent) ?? 0;
});

/// Provider for current memory usage percentage
final memoryUsageProvider = Provider<double>((ref) {
  final metrics = ref.watch(systemMetricsProvider);
  return metrics.whenOrNull(data: (m) => m.memory.usagePercent) ?? 0;
});

/// Provider for refresh interval setting
final metricsRefreshIntervalProvider = StateProvider<Duration>((ref) {
  return const Duration(seconds: 2);
});

/// Data point for CPU history chart
class CpuDataPoint {
  const CpuDataPoint({
    required this.timestamp,
    required this.usage,
    this.userUsage,
    this.systemUsage,
  });

  final DateTime timestamp;
  final double usage;
  final double? userUsage;
  final double? systemUsage;
}

/// Data point for memory history chart
class MemoryDataPoint {
  const MemoryDataPoint({
    required this.timestamp,
    required this.usagePercent,
    required this.usedBytes,
    required this.totalBytes,
  });

  final DateTime timestamp;
  final double usagePercent;
  final int usedBytes;
  final int totalBytes;
}

/// State notifier for system metrics
class SystemMetricsNotifier extends StateNotifier<AsyncValue<SystemMetrics>> {
  SystemMetricsNotifier(this._service) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final SystemMetricsService _service;
  Timer? _refreshTimer;

  static const int _maxHistorySize = 60;
  final List<CpuDataPoint> _cpuHistory = [];
  final List<MemoryDataPoint> _memoryHistory = [];

  List<CpuDataPoint> get cpuHistory => List.unmodifiable(_cpuHistory);
  List<MemoryDataPoint> get memoryHistory => List.unmodifiable(_memoryHistory);

  Future<void> _initialize() async {
    await refresh();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refresh();
    });
  }

  /// Refresh metrics data
  Future<void> refresh() async {
    try {
      final metrics = await _service.getSystemMetrics();
      _addToHistory(metrics);
      state = AsyncValue.data(metrics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _addToHistory(SystemMetrics metrics) {
    // Add CPU data point
    _cpuHistory.add(CpuDataPoint(
      timestamp: metrics.timestamp,
      usage: metrics.cpu.usagePercent,
      userUsage: metrics.cpu.userPercent,
      systemUsage: metrics.cpu.systemPercent,
    ));

    // Trim to max size
    while (_cpuHistory.length > _maxHistorySize) {
      _cpuHistory.removeAt(0);
    }

    // Add memory data point
    _memoryHistory.add(MemoryDataPoint(
      timestamp: metrics.timestamp,
      usagePercent: metrics.memory.usagePercent,
      usedBytes: metrics.memory.usedBytes,
      totalBytes: metrics.memory.totalBytes,
    ));

    // Trim to max size
    while (_memoryHistory.length > _maxHistorySize) {
      _memoryHistory.removeAt(0);
    }
  }

  /// Set custom refresh interval
  void setRefreshInterval(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      refresh();
    });
  }

  /// Pause automatic refresh
  void pause() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Resume automatic refresh
  void resume() {
    if (_refreshTimer == null) {
      _startAutoRefresh();
    }
  }

  /// Clear history data
  void clearHistory() {
    _cpuHistory.clear();
    _memoryHistory.clear();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
