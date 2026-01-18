import 'package:equatable/equatable.dart';

/// Process state enumeration
enum ProcessState {
  running,
  sleeping,
  stopped,
  zombie,
  unknown,
}

/// Process category enumeration
enum ProcessCategory {
  userApp,
  backgroundService,
  systemProcess,
  systemService,
  unknown,
}

/// Process information model
class ProcessInfo extends Equatable {
  const ProcessInfo({
    required this.pid,
    required this.name,
    this.displayName,
    this.cpuPercent,
    this.memoryBytes,
    this.memoryPercent,
    this.threadCount,
    this.state,
    this.user,
    this.startTime,
    this.executablePath,
    this.commandLine,
    this.parentPid,
    this.priority,
    this.isSystemProcess = false,
    this.canTerminate = true,
    this.category = ProcessCategory.unknown,
  });

  final int pid;
  final String name;
  final String? displayName;
  final double? cpuPercent;
  final int? memoryBytes;
  final double? memoryPercent;
  final int? threadCount;
  final ProcessState? state;
  final String? user;
  final DateTime? startTime;
  final String? executablePath;
  final String? commandLine;
  final int? parentPid;
  final int? priority;
  final bool isSystemProcess;
  final bool canTerminate;
  final ProcessCategory category;

  /// Get display name or fall back to process name
  String get effectiveDisplayName => displayName ?? name;

  /// Check if this is a critical system process that should be protected
  bool get isProtected => isSystemProcess || !canTerminate;

  ProcessInfo copyWith({
    int? pid,
    String? name,
    String? displayName,
    double? cpuPercent,
    int? memoryBytes,
    double? memoryPercent,
    int? threadCount,
    ProcessState? state,
    String? user,
    DateTime? startTime,
    String? executablePath,
    String? commandLine,
    int? parentPid,
    int? priority,
    bool? isSystemProcess,
    bool? canTerminate,
    ProcessCategory? category,
  }) {
    return ProcessInfo(
      pid: pid ?? this.pid,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      cpuPercent: cpuPercent ?? this.cpuPercent,
      memoryBytes: memoryBytes ?? this.memoryBytes,
      memoryPercent: memoryPercent ?? this.memoryPercent,
      threadCount: threadCount ?? this.threadCount,
      state: state ?? this.state,
      user: user ?? this.user,
      startTime: startTime ?? this.startTime,
      executablePath: executablePath ?? this.executablePath,
      commandLine: commandLine ?? this.commandLine,
      parentPid: parentPid ?? this.parentPid,
      priority: priority ?? this.priority,
      isSystemProcess: isSystemProcess ?? this.isSystemProcess,
      canTerminate: canTerminate ?? this.canTerminate,
      category: category ?? this.category,
    );
  }

  @override
  List<Object?> get props => [
        pid,
        name,
        displayName,
        cpuPercent,
        memoryBytes,
        memoryPercent,
        threadCount,
        state,
        user,
        startTime,
        executablePath,
        commandLine,
        parentPid,
        priority,
        isSystemProcess,
        canTerminate,
        category,
      ];
}

/// Sort options for process list
enum ProcessSortField {
  name,
  cpu,
  memory,
  pid,
}

/// Sort order
enum SortOrder {
  ascending,
  descending,
}

/// Extension for sorting processes
extension ProcessListSorting on List<ProcessInfo> {
  List<ProcessInfo> sortBy(ProcessSortField field, SortOrder order) {
    final sorted = List<ProcessInfo>.from(this);

    sorted.sort((a, b) {
      int comparison;
      switch (field) {
        case ProcessSortField.name:
          comparison = a.effectiveDisplayName
              .toLowerCase()
              .compareTo(b.effectiveDisplayName.toLowerCase());
        case ProcessSortField.cpu:
          comparison = (a.cpuPercent ?? 0).compareTo(b.cpuPercent ?? 0);
        case ProcessSortField.memory:
          comparison = (a.memoryBytes ?? 0).compareTo(b.memoryBytes ?? 0);
        case ProcessSortField.pid:
          comparison = a.pid.compareTo(b.pid);
      }

      return order == SortOrder.ascending ? comparison : -comparison;
    });

    return sorted;
  }
}

/// Protected processes list for Linux
class ProtectedProcesses {
  ProtectedProcesses._();

  /// List of process names that should not be terminated
  static const Set<String> protectedNames = {
    'init',
    'systemd',
    'kthreadd',
    'dbus-daemon',
    'gdm',
    'gdm3',
    'sddm',
    'lightdm',
    'Xorg',
    'Xwayland',
    'gnome-shell',
    'plasmashell',
    'kwin_wayland',
    'kwin_x11',
    'mutter',
    'cinnamon',
    'mate-panel',
    'xfce4-panel',
    'pulseaudio',
    'pipewire',
    'pipewire-pulse',
    'wireplumber',
    'NetworkManager',
    'wpa_supplicant',
    'polkitd',
    'udisksd',
    'upowerd',
    'accounts-daemon',
    'colord',
    'cupsd',
    'avahi-daemon',
    'rsyslogd',
    'cron',
    'atd',
    'dbus-broker',
    'journald',
    'udevd',
    'thermald',
  };

  /// Protected PIDs (always protect PID 1 and 2)
  static const Set<int> protectedPids = {1, 2};

  /// Check if a process is protected
  static bool isProtected(ProcessInfo process) {
    if (protectedPids.contains(process.pid)) {
      return true;
    }

    if (protectedNames.contains(process.name)) {
      return true;
    }

    // Also protect kernel threads (typically owned by root with PID < 100)
    if (process.pid < 100 && process.user == 'root') {
      return true;
    }

    return false;
  }
}
