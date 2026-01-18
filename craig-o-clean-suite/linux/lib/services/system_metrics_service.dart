import 'dart:io';

import 'package:craig_o_clean/models/system_metrics.dart';
import 'package:craig_o_clean/theme/app_colors.dart';

/// Service for reading system metrics from /proc filesystem
class SystemMetricsService {
  SystemMetricsService();

  // Previous CPU values for calculating usage percentage
  int _prevIdleTime = 0;
  int _prevTotalTime = 0;

  // Per-core previous values
  final Map<int, int> _prevCoreIdleTime = {};
  final Map<int, int> _prevCoreTotalTime = {};

  /// Get current system metrics
  Future<SystemMetrics> getSystemMetrics() async {
    final cpu = await _getCpuMetrics();
    final memory = await _getMemoryMetrics();
    final swap = await _getSwapMetrics();
    final loadAverage = await _getLoadAverage();

    return SystemMetrics(
      timestamp: DateTime.now(),
      cpu: cpu,
      memory: memory,
      swap: swap,
      loadAverage: loadAverage,
    );
  }

  /// Parse /proc/stat for CPU metrics
  Future<CpuMetrics> _getCpuMetrics() async {
    try {
      final statFile = File('/proc/stat');
      final lines = await statFile.readAsLines();

      double totalUsage = 0;
      double? userPercent;
      double? systemPercent;
      double? idlePercent;
      int coreCount = 0;
      final coreUsage = <double>[];

      for (final line in lines) {
        if (line.startsWith('cpu ')) {
          // Total CPU line
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 5) {
            final user = int.parse(parts[1]);
            final nice = int.parse(parts[2]);
            final system = int.parse(parts[3]);
            final idle = int.parse(parts[4]);
            final iowait = parts.length > 5 ? int.parse(parts[5]) : 0;
            final irq = parts.length > 6 ? int.parse(parts[6]) : 0;
            final softirq = parts.length > 7 ? int.parse(parts[7]) : 0;
            final steal = parts.length > 8 ? int.parse(parts[8]) : 0;

            final idleTime = idle + iowait;
            final totalTime =
                user + nice + system + idle + iowait + irq + softirq + steal;

            if (_prevTotalTime > 0) {
              final deltaIdle = idleTime - _prevIdleTime;
              final deltaTotal = totalTime - _prevTotalTime;

              if (deltaTotal > 0) {
                totalUsage = 100.0 * (1.0 - deltaIdle / deltaTotal);
                userPercent = 100.0 * (user + nice) / deltaTotal;
                systemPercent = 100.0 * system / deltaTotal;
                idlePercent = 100.0 * deltaIdle / deltaTotal;
              }
            }

            _prevIdleTime = idleTime;
            _prevTotalTime = totalTime;
          }
        } else if (line.startsWith('cpu') && !line.startsWith('cpu ')) {
          // Per-core CPU line (cpu0, cpu1, etc.)
          final match = RegExp(r'cpu(\d+)').firstMatch(line);
          if (match != null) {
            final coreIndex = int.parse(match.group(1)!);
            coreCount = coreCount > coreIndex ? coreCount : coreIndex + 1;

            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 5) {
              final user = int.parse(parts[1]);
              final nice = int.parse(parts[2]);
              final system = int.parse(parts[3]);
              final idle = int.parse(parts[4]);
              final iowait = parts.length > 5 ? int.parse(parts[5]) : 0;
              final irq = parts.length > 6 ? int.parse(parts[6]) : 0;
              final softirq = parts.length > 7 ? int.parse(parts[7]) : 0;
              final steal = parts.length > 8 ? int.parse(parts[8]) : 0;

              final idleTime = idle + iowait;
              final totalTime =
                  user + nice + system + idle + iowait + irq + softirq + steal;

              final prevIdle = _prevCoreIdleTime[coreIndex] ?? 0;
              final prevTotal = _prevCoreTotalTime[coreIndex] ?? 0;

              if (prevTotal > 0) {
                final deltaIdle = idleTime - prevIdle;
                final deltaTotal = totalTime - prevTotal;

                if (deltaTotal > 0) {
                  coreUsage.add(100.0 * (1.0 - deltaIdle / deltaTotal));
                } else {
                  coreUsage.add(0);
                }
              } else {
                coreUsage.add(0);
              }

              _prevCoreIdleTime[coreIndex] = idleTime;
              _prevCoreTotalTime[coreIndex] = totalTime;
            }
          }
        }
      }

      final frequency = await _getCpuFrequency();

      return CpuMetrics(
        usagePercent: totalUsage.clamp(0, 100),
        userPercent: userPercent?.clamp(0, 100),
        systemPercent: systemPercent?.clamp(0, 100),
        idlePercent: idlePercent?.clamp(0, 100),
        coreCount: coreCount > 0 ? coreCount : null,
        coreUsage: coreUsage.isNotEmpty ? coreUsage : null,
        frequency: frequency,
      );
    } catch (e) {
      return CpuMetrics.empty();
    }
  }

  /// Get CPU frequency from /proc/cpuinfo or /sys/devices/system/cpu
  Future<CpuFrequency?> _getCpuFrequency() async {
    try {
      // Try to read from /sys/devices/system/cpu/cpu0/cpufreq
      final currentFreqFile =
          File('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq');
      final minFreqFile =
          File('/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq');
      final maxFreqFile =
          File('/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq');

      double? current;
      double? min;
      double? max;

      if (await currentFreqFile.exists()) {
        final freqKhz = int.tryParse(
            (await currentFreqFile.readAsString()).trim());
        if (freqKhz != null) {
          current = freqKhz / 1000; // Convert to MHz
        }
      }

      if (await minFreqFile.exists()) {
        final freqKhz =
            int.tryParse((await minFreqFile.readAsString()).trim());
        if (freqKhz != null) {
          min = freqKhz / 1000;
        }
      }

      if (await maxFreqFile.exists()) {
        final freqKhz =
            int.tryParse((await maxFreqFile.readAsString()).trim());
        if (freqKhz != null) {
          max = freqKhz / 1000;
        }
      }

      if (current != null || min != null || max != null) {
        return CpuFrequency(current: current, min: min, max: max);
      }

      // Fallback to /proc/cpuinfo
      final cpuinfoFile = File('/proc/cpuinfo');
      if (await cpuinfoFile.exists()) {
        final contents = await cpuinfoFile.readAsString();
        final match = RegExp(r'cpu MHz\s*:\s*(\d+\.?\d*)').firstMatch(contents);
        if (match != null) {
          current = double.tryParse(match.group(1)!);
          if (current != null) {
            return CpuFrequency(current: current);
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse /proc/meminfo for memory metrics
  Future<MemoryMetrics> _getMemoryMetrics() async {
    try {
      final meminfoFile = File('/proc/meminfo');
      final contents = await meminfoFile.readAsString();

      int? memTotal;
      int? memFree;
      int? memAvailable;
      int? buffers;
      int? cached;
      int? sReclaimable;

      for (final line in contents.split('\n')) {
        final parts = line.split(':');
        if (parts.length != 2) continue;

        final key = parts[0].trim();
        final valueStr = parts[1].trim().replaceAll(' kB', '');
        final value = int.tryParse(valueStr);

        if (value == null) continue;

        switch (key) {
          case 'MemTotal':
            memTotal = value * 1024; // Convert to bytes
          case 'MemFree':
            memFree = value * 1024;
          case 'MemAvailable':
            memAvailable = value * 1024;
          case 'Buffers':
            buffers = value * 1024;
          case 'Cached':
            cached = value * 1024;
          case 'SReclaimable':
            sReclaimable = value * 1024;
        }
      }

      if (memTotal == null || memTotal == 0) {
        return MemoryMetrics.empty();
      }

      // Calculate available memory (prefer MemAvailable if present)
      final available = memAvailable ??
          (memFree ?? 0) + (buffers ?? 0) + (cached ?? 0) + (sReclaimable ?? 0);

      final used = memTotal - available;
      final usagePercent = 100.0 * used / memTotal;

      // Determine memory pressure
      MemoryPressure pressure;
      if (usagePercent < 60) {
        pressure = MemoryPressure.normal;
      } else if (usagePercent < 85) {
        pressure = MemoryPressure.elevated;
      } else {
        pressure = MemoryPressure.critical;
      }

      return MemoryMetrics(
        totalBytes: memTotal,
        usedBytes: used,
        availableBytes: available,
        usagePercent: usagePercent.clamp(0, 100),
        freeBytes: memFree,
        pressure: pressure,
        cached: (cached ?? 0) + (sReclaimable ?? 0),
        buffers: buffers,
      );
    } catch (e) {
      return MemoryMetrics.empty();
    }
  }

  /// Parse /proc/meminfo for swap metrics
  Future<SwapMetrics?> _getSwapMetrics() async {
    try {
      final meminfoFile = File('/proc/meminfo');
      final contents = await meminfoFile.readAsString();

      int? swapTotal;
      int? swapFree;

      for (final line in contents.split('\n')) {
        final parts = line.split(':');
        if (parts.length != 2) continue;

        final key = parts[0].trim();
        final valueStr = parts[1].trim().replaceAll(' kB', '');
        final value = int.tryParse(valueStr);

        if (value == null) continue;

        switch (key) {
          case 'SwapTotal':
            swapTotal = value * 1024;
          case 'SwapFree':
            swapFree = value * 1024;
        }
      }

      if (swapTotal == null || swapTotal == 0) {
        return null;
      }

      final swapUsed = swapTotal - (swapFree ?? 0);
      final usagePercent = 100.0 * swapUsed / swapTotal;

      return SwapMetrics(
        totalBytes: swapTotal,
        usedBytes: swapUsed,
        freeBytes: swapFree,
        usagePercent: usagePercent.clamp(0, 100),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse /proc/loadavg for load average
  Future<LoadAverage?> _getLoadAverage() async {
    try {
      final loadavgFile = File('/proc/loadavg');
      final contents = await loadavgFile.readAsString();
      final parts = contents.trim().split(' ');

      if (parts.length >= 3) {
        return LoadAverage(
          oneMinute: double.tryParse(parts[0]),
          fiveMinute: double.tryParse(parts[1]),
          fifteenMinute: double.tryParse(parts[2]),
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the number of CPU cores
  Future<int> getCoreCount() async {
    try {
      final cpuinfoFile = File('/proc/cpuinfo');
      final contents = await cpuinfoFile.readAsString();
      final matches = RegExp(r'^processor\s*:', multiLine: true)
          .allMatches(contents);
      return matches.length;
    } catch (e) {
      return 1;
    }
  }

  /// Get system uptime
  Future<Duration?> getUptime() async {
    try {
      final uptimeFile = File('/proc/uptime');
      final contents = await uptimeFile.readAsString();
      final parts = contents.trim().split(' ');

      if (parts.isNotEmpty) {
        final seconds = double.tryParse(parts[0]);
        if (seconds != null) {
          return Duration(milliseconds: (seconds * 1000).toInt());
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get hostname
  Future<String> getHostname() async {
    try {
      final hostnameFile = File('/proc/sys/kernel/hostname');
      return (await hostnameFile.readAsString()).trim();
    } catch (e) {
      return Platform.localHostname;
    }
  }

  /// Get kernel version
  Future<String?> getKernelVersion() async {
    try {
      final versionFile = File('/proc/version');
      final contents = await versionFile.readAsString();
      final match = RegExp(r'Linux version ([\d\.\-\w]+)').firstMatch(contents);
      return match?.group(1);
    } catch (e) {
      return null;
    }
  }
}
