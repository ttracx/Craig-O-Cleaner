import 'dart:io';

import 'package:craig_o_clean/models/process_info.dart';

/// Service for managing processes on Linux
class ProcessService {
  ProcessService();

  // Cache for total system memory
  int? _totalMemory;

  // Previous CPU times for calculating process CPU usage
  final Map<int, _ProcessCpuTime> _prevCpuTimes = {};

  // System clock tick rate (usually 100 Hz on Linux)
  static const int _clockTicks = 100;

  /// Get list of all running processes
  Future<List<ProcessInfo>> getProcessList() async {
    final processes = <ProcessInfo>[];
    final totalMemory = await _getTotalMemory();
    final currentTime = DateTime.now();

    try {
      final procDir = Directory('/proc');
      final entities = await procDir.list().toList();

      for (final entity in entities) {
        if (entity is! Directory) continue;

        final name = entity.path.split('/').last;
        final pid = int.tryParse(name);
        if (pid == null) continue;

        try {
          final processInfo = await _getProcessInfo(pid, totalMemory, currentTime);
          if (processInfo != null) {
            processes.add(processInfo);
          }
        } catch (e) {
          // Process may have exited, skip it
          continue;
        }
      }
    } catch (e) {
      // Handle error
    }

    // Clean up stale CPU time entries
    _cleanupStaleCpuTimes(processes.map((p) => p.pid).toSet());

    return processes;
  }

  /// Get information for a specific process
  Future<ProcessInfo?> _getProcessInfo(
      int pid, int totalMemory, DateTime currentTime) async {
    try {
      // Read /proc/[pid]/stat
      final statFile = File('/proc/$pid/stat');
      if (!await statFile.exists()) return null;

      final statContent = await statFile.readAsString();
      final statInfo = _parseStatFile(statContent);
      if (statInfo == null) return null;

      // Read /proc/[pid]/status for additional info
      final statusFile = File('/proc/$pid/status');
      Map<String, String>? statusInfo;
      if (await statusFile.exists()) {
        statusInfo = await _parseStatusFile(statusFile);
      }

      // Read /proc/[pid]/cmdline
      String? commandLine;
      final cmdlineFile = File('/proc/$pid/cmdline');
      if (await cmdlineFile.exists()) {
        try {
          final cmdlineBytes = await cmdlineFile.readAsBytes();
          commandLine = String.fromCharCodes(cmdlineBytes)
              .replaceAll('\x00', ' ')
              .trim();
        } catch (e) {
          // Ignore
        }
      }

      // Read /proc/[pid]/exe for executable path
      String? executablePath;
      try {
        final exeLink = Link('/proc/$pid/exe');
        if (await exeLink.exists()) {
          executablePath = await exeLink.target();
        }
      } catch (e) {
        // Permission denied or link doesn't exist
      }

      // Calculate CPU usage
      final cpuPercent = _calculateCpuUsage(pid, statInfo, currentTime);

      // Calculate memory usage
      final memoryBytes = statInfo.rss * 4096; // Page size is typically 4KB
      final memoryPercent =
          totalMemory > 0 ? 100.0 * memoryBytes / totalMemory : 0.0;

      // Determine process state
      final state = _parseProcessState(statInfo.state);

      // Get user name
      final user = statusInfo?['Uid']?.split('\t').first;
      String? userName;
      if (user != null) {
        userName = await _getUsername(int.tryParse(user));
      }

      // Determine if it's a system process
      final isSystemProcess = _isSystemProcess(
        pid,
        statInfo.name,
        userName,
        statInfo.ppid,
      );

      // Determine category
      final category = _categorizeProcess(
        statInfo.name,
        executablePath,
        isSystemProcess,
      );

      // Check if process can be terminated
      final canTerminate = !ProtectedProcesses.isProtected(ProcessInfo(
        pid: pid,
        name: statInfo.name,
        user: userName,
      ));

      return ProcessInfo(
        pid: pid,
        name: statInfo.name,
        displayName: _getDisplayName(statInfo.name, commandLine),
        cpuPercent: cpuPercent,
        memoryBytes: memoryBytes,
        memoryPercent: memoryPercent,
        threadCount: statInfo.threads,
        state: state,
        user: userName,
        startTime: _getStartTime(statInfo.starttime),
        executablePath: executablePath,
        commandLine: commandLine,
        parentPid: statInfo.ppid,
        priority: statInfo.priority,
        isSystemProcess: isSystemProcess,
        canTerminate: canTerminate,
        category: category,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse /proc/[pid]/stat file
  _StatInfo? _parseStatFile(String content) {
    try {
      // The format is: pid (comm) state ppid ...
      // comm can contain spaces and parentheses, so we need to find the last )
      final lastParen = content.lastIndexOf(')');
      if (lastParen == -1) return null;

      final firstParen = content.indexOf('(');
      if (firstParen == -1) return null;

      final name = content.substring(firstParen + 1, lastParen);
      final rest = content.substring(lastParen + 2).split(' ');

      if (rest.length < 20) return null;

      return _StatInfo(
        name: name,
        state: rest[0],
        ppid: int.tryParse(rest[1]) ?? 0,
        utime: int.tryParse(rest[11]) ?? 0,
        stime: int.tryParse(rest[12]) ?? 0,
        priority: int.tryParse(rest[15]) ?? 0,
        threads: int.tryParse(rest[17]) ?? 1,
        starttime: int.tryParse(rest[19]) ?? 0,
        rss: int.tryParse(rest[21]) ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse /proc/[pid]/status file
  Future<Map<String, String>> _parseStatusFile(File file) async {
    final result = <String, String>{};

    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        final colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          final key = line.substring(0, colonIndex);
          final value = line.substring(colonIndex + 1).trim();
          result[key] = value;
        }
      }
    } catch (e) {
      // Ignore
    }

    return result;
  }

  /// Calculate CPU usage for a process
  double _calculateCpuUsage(
      int pid, _StatInfo statInfo, DateTime currentTime) {
    final currentCpuTime = statInfo.utime + statInfo.stime;

    final prevTime = _prevCpuTimes[pid];
    if (prevTime == null) {
      _prevCpuTimes[pid] = _ProcessCpuTime(
        cpuTime: currentCpuTime,
        wallTime: currentTime,
      );
      return 0;
    }

    final cpuDelta = currentCpuTime - prevTime.cpuTime;
    final wallDelta =
        currentTime.difference(prevTime.wallTime).inMilliseconds / 1000.0;

    _prevCpuTimes[pid] = _ProcessCpuTime(
      cpuTime: currentCpuTime,
      wallTime: currentTime,
    );

    if (wallDelta <= 0) return 0;

    // CPU time is in clock ticks, convert to percentage
    final cpuPercent = 100.0 * (cpuDelta / _clockTicks) / wallDelta;
    return cpuPercent.clamp(0, 100 * _getCoreCount());
  }

  int _getCoreCount() {
    try {
      return Platform.numberOfProcessors;
    } catch (e) {
      return 1;
    }
  }

  /// Clean up CPU time entries for processes that no longer exist
  void _cleanupStaleCpuTimes(Set<int> activePids) {
    _prevCpuTimes.removeWhere((pid, _) => !activePids.contains(pid));
  }

  /// Parse process state character
  ProcessState _parseProcessState(String state) {
    switch (state.toUpperCase()) {
      case 'R':
        return ProcessState.running;
      case 'S':
      case 'D':
      case 'I':
        return ProcessState.sleeping;
      case 'T':
        return ProcessState.stopped;
      case 'Z':
        return ProcessState.zombie;
      default:
        return ProcessState.unknown;
    }
  }

  /// Get total system memory
  Future<int> _getTotalMemory() async {
    if (_totalMemory != null) return _totalMemory!;

    try {
      final meminfoFile = File('/proc/meminfo');
      final contents = await meminfoFile.readAsString();

      for (final line in contents.split('\n')) {
        if (line.startsWith('MemTotal:')) {
          final valueStr =
              line.replaceAll('MemTotal:', '').replaceAll('kB', '').trim();
          final value = int.tryParse(valueStr);
          if (value != null) {
            _totalMemory = value * 1024;
            return _totalMemory!;
          }
        }
      }
    } catch (e) {
      // Ignore
    }

    return 0;
  }

  /// Get username for a UID
  Future<String?> _getUsername(int? uid) async {
    if (uid == null) return null;

    try {
      final passwdFile = File('/etc/passwd');
      final lines = await passwdFile.readAsLines();

      for (final line in lines) {
        final parts = line.split(':');
        if (parts.length >= 3) {
          final lineUid = int.tryParse(parts[2]);
          if (lineUid == uid) {
            return parts[0];
          }
        }
      }
    } catch (e) {
      // Ignore
    }

    return uid.toString();
  }

  /// Get display name for a process
  String _getDisplayName(String name, String? commandLine) {
    // Try to get a better display name from the command line
    if (commandLine != null && commandLine.isNotEmpty) {
      final parts = commandLine.split(' ');
      if (parts.isNotEmpty) {
        final cmd = parts[0].split('/').last;
        if (cmd.isNotEmpty && cmd != name) {
          return cmd;
        }
      }
    }
    return name;
  }

  /// Get process start time
  DateTime? _getStartTime(int starttime) {
    try {
      // starttime is in clock ticks since boot
      // We need to get the boot time to calculate the actual start time
      final uptimeFile = File('/proc/uptime');
      final uptime = uptimeFile.readAsStringSync();
      final uptimeSeconds = double.tryParse(uptime.split(' ')[0]);

      if (uptimeSeconds != null) {
        final bootTime = DateTime.now()
            .subtract(Duration(seconds: uptimeSeconds.toInt()));
        final processStartSeconds = starttime / _clockTicks;
        return bootTime.add(Duration(seconds: processStartSeconds.toInt()));
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  /// Check if a process is a system process
  bool _isSystemProcess(int pid, String name, String? user, int ppid) {
    // PIDs below 1000 are typically system processes
    if (pid < 1000) return true;

    // Root-owned processes are often system processes
    if (user == 'root') return true;

    // Check if it's a kernel thread (parent is 2)
    if (ppid == 2) return true;

    // Check common system process names
    if (ProtectedProcesses.protectedNames.contains(name)) return true;

    return false;
  }

  /// Categorize a process
  ProcessCategory _categorizeProcess(
      String name, String? executablePath, bool isSystemProcess) {
    if (isSystemProcess) {
      // Check if it's a system service
      if (name.endsWith('d') ||
          name.contains('daemon') ||
          name.contains('service')) {
        return ProcessCategory.systemService;
      }
      return ProcessCategory.systemProcess;
    }

    // Check for common user applications
    if (executablePath != null) {
      if (executablePath.contains('/usr/bin') ||
          executablePath.contains('/usr/local/bin') ||
          executablePath.contains('/opt')) {
        return ProcessCategory.userApp;
      }
    }

    // Check for background services
    if (name.endsWith('d') || name.contains('-daemon')) {
      return ProcessCategory.backgroundService;
    }

    return ProcessCategory.userApp;
  }

  /// Terminate a process gracefully (SIGTERM)
  Future<bool> terminateProcess(int pid) async {
    try {
      final result = await Process.run('kill', ['-TERM', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Force kill a process (SIGKILL)
  Future<bool> forceKillProcess(int pid) async {
    try {
      final result = await Process.run('kill', ['-KILL', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Send a signal to a process
  Future<bool> sendSignal(int pid, int signal) async {
    try {
      final result =
          await Process.run('kill', ['-$signal', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if a process is running
  Future<bool> isProcessRunning(int pid) async {
    try {
      final procDir = Directory('/proc/$pid');
      return await procDir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get process details
  Future<ProcessInfo?> getProcessDetails(int pid) async {
    final totalMemory = await _getTotalMemory();
    return _getProcessInfo(pid, totalMemory, DateTime.now());
  }
}

/// Internal class for parsing /proc/[pid]/stat
class _StatInfo {
  const _StatInfo({
    required this.name,
    required this.state,
    required this.ppid,
    required this.utime,
    required this.stime,
    required this.priority,
    required this.threads,
    required this.starttime,
    required this.rss,
  });

  final String name;
  final String state;
  final int ppid;
  final int utime;
  final int stime;
  final int priority;
  final int threads;
  final int starttime;
  final int rss;
}

/// Internal class for tracking CPU time
class _ProcessCpuTime {
  const _ProcessCpuTime({
    required this.cpuTime,
    required this.wallTime,
  });

  final int cpuTime;
  final DateTime wallTime;
}
