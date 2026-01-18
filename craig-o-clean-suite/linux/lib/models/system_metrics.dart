import 'package:equatable/equatable.dart';

import 'package:craig_o_clean/theme/app_colors.dart';

/// System metrics data model
class SystemMetrics extends Equatable {
  const SystemMetrics({
    required this.timestamp,
    required this.cpu,
    required this.memory,
    this.swap,
    this.loadAverage,
  });

  final DateTime timestamp;
  final CpuMetrics cpu;
  final MemoryMetrics memory;
  final SwapMetrics? swap;
  final LoadAverage? loadAverage;

  SystemMetrics copyWith({
    DateTime? timestamp,
    CpuMetrics? cpu,
    MemoryMetrics? memory,
    SwapMetrics? swap,
    LoadAverage? loadAverage,
  }) {
    return SystemMetrics(
      timestamp: timestamp ?? this.timestamp,
      cpu: cpu ?? this.cpu,
      memory: memory ?? this.memory,
      swap: swap ?? this.swap,
      loadAverage: loadAverage ?? this.loadAverage,
    );
  }

  factory SystemMetrics.empty() => SystemMetrics(
        timestamp: DateTime.now(),
        cpu: CpuMetrics.empty(),
        memory: MemoryMetrics.empty(),
      );

  @override
  List<Object?> get props => [timestamp, cpu, memory, swap, loadAverage];
}

/// CPU metrics
class CpuMetrics extends Equatable {
  const CpuMetrics({
    required this.usagePercent,
    this.userPercent,
    this.systemPercent,
    this.idlePercent,
    this.coreCount,
    this.coreUsage,
    this.frequency,
  });

  final double usagePercent;
  final double? userPercent;
  final double? systemPercent;
  final double? idlePercent;
  final int? coreCount;
  final List<double>? coreUsage;
  final CpuFrequency? frequency;

  factory CpuMetrics.empty() => const CpuMetrics(usagePercent: 0);

  CpuMetrics copyWith({
    double? usagePercent,
    double? userPercent,
    double? systemPercent,
    double? idlePercent,
    int? coreCount,
    List<double>? coreUsage,
    CpuFrequency? frequency,
  }) {
    return CpuMetrics(
      usagePercent: usagePercent ?? this.usagePercent,
      userPercent: userPercent ?? this.userPercent,
      systemPercent: systemPercent ?? this.systemPercent,
      idlePercent: idlePercent ?? this.idlePercent,
      coreCount: coreCount ?? this.coreCount,
      coreUsage: coreUsage ?? this.coreUsage,
      frequency: frequency ?? this.frequency,
    );
  }

  @override
  List<Object?> get props => [
        usagePercent,
        userPercent,
        systemPercent,
        idlePercent,
        coreCount,
        coreUsage,
        frequency,
      ];
}

/// CPU frequency information
class CpuFrequency extends Equatable {
  const CpuFrequency({
    this.current,
    this.min,
    this.max,
  });

  final double? current;
  final double? min;
  final double? max;

  @override
  List<Object?> get props => [current, min, max];
}

/// Memory metrics
class MemoryMetrics extends Equatable {
  const MemoryMetrics({
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.usagePercent,
    this.freeBytes,
    this.pressure,
    this.cached,
    this.buffers,
  });

  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final double usagePercent;
  final int? freeBytes;
  final MemoryPressure? pressure;
  final int? cached;
  final int? buffers;

  factory MemoryMetrics.empty() => const MemoryMetrics(
        totalBytes: 0,
        usedBytes: 0,
        availableBytes: 0,
        usagePercent: 0,
      );

  MemoryMetrics copyWith({
    int? totalBytes,
    int? usedBytes,
    int? availableBytes,
    double? usagePercent,
    int? freeBytes,
    MemoryPressure? pressure,
    int? cached,
    int? buffers,
  }) {
    return MemoryMetrics(
      totalBytes: totalBytes ?? this.totalBytes,
      usedBytes: usedBytes ?? this.usedBytes,
      availableBytes: availableBytes ?? this.availableBytes,
      usagePercent: usagePercent ?? this.usagePercent,
      freeBytes: freeBytes ?? this.freeBytes,
      pressure: pressure ?? this.pressure,
      cached: cached ?? this.cached,
      buffers: buffers ?? this.buffers,
    );
  }

  @override
  List<Object?> get props => [
        totalBytes,
        usedBytes,
        availableBytes,
        usagePercent,
        freeBytes,
        pressure,
        cached,
        buffers,
      ];
}

/// Swap metrics
class SwapMetrics extends Equatable {
  const SwapMetrics({
    this.totalBytes,
    this.usedBytes,
    this.freeBytes,
    this.usagePercent,
  });

  final int? totalBytes;
  final int? usedBytes;
  final int? freeBytes;
  final double? usagePercent;

  factory SwapMetrics.empty() => const SwapMetrics();

  SwapMetrics copyWith({
    int? totalBytes,
    int? usedBytes,
    int? freeBytes,
    double? usagePercent,
  }) {
    return SwapMetrics(
      totalBytes: totalBytes ?? this.totalBytes,
      usedBytes: usedBytes ?? this.usedBytes,
      freeBytes: freeBytes ?? this.freeBytes,
      usagePercent: usagePercent ?? this.usagePercent,
    );
  }

  @override
  List<Object?> get props => [totalBytes, usedBytes, freeBytes, usagePercent];
}

/// Load average metrics
class LoadAverage extends Equatable {
  const LoadAverage({
    this.oneMinute,
    this.fiveMinute,
    this.fifteenMinute,
  });

  final double? oneMinute;
  final double? fiveMinute;
  final double? fifteenMinute;

  factory LoadAverage.empty() => const LoadAverage();

  @override
  List<Object?> get props => [oneMinute, fiveMinute, fifteenMinute];
}

/// Helper extension for formatting bytes
extension ByteFormatter on int {
  String toHumanReadableBytes() {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String toHumanReadableBytesShort() {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(0)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Helper extension for percentage formatting
extension PercentFormatter on double {
  String toPercentString({int decimals = 1}) {
    return '${toStringAsFixed(decimals)}%';
  }
}
