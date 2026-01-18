import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craig_o_clean/models/process_info.dart';
import 'package:craig_o_clean/services/process_service.dart';
import 'package:craig_o_clean/providers/entitlement_provider.dart';

/// Provider for the process service
final processServiceProvider = Provider<ProcessService>((ref) {
  return ProcessService();
});

/// Provider for the current process list
final processListProvider =
    StateNotifierProvider<ProcessListNotifier, AsyncValue<List<ProcessInfo>>>(
        (ref) {
  final service = ref.watch(processServiceProvider);
  return ProcessListNotifier(service);
});

/// Provider for sort field
final processSortFieldProvider = StateProvider<ProcessSortField>((ref) {
  return ProcessSortField.cpu;
});

/// Provider for sort order
final processSortOrderProvider = StateProvider<SortOrder>((ref) {
  return SortOrder.descending;
});

/// Provider for search/filter query
final processSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

/// Provider for showing system processes
final showSystemProcessesProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for filtered and sorted process list
final filteredProcessListProvider = Provider<List<ProcessInfo>>((ref) {
  final processesAsync = ref.watch(processListProvider);
  final sortField = ref.watch(processSortFieldProvider);
  final sortOrder = ref.watch(processSortOrderProvider);
  final searchQuery = ref.watch(processSearchQueryProvider);
  final showSystem = ref.watch(showSystemProcessesProvider);

  return processesAsync.whenOrNull(
        data: (processes) {
          var filtered = processes.where((p) {
            // Filter by system process
            if (!showSystem && p.isSystemProcess) {
              return false;
            }

            // Filter by search query
            if (searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              final name = p.effectiveDisplayName.toLowerCase();
              final cmd = (p.commandLine ?? '').toLowerCase();
              if (!name.contains(query) && !cmd.contains(query)) {
                return false;
              }
            }

            return true;
          }).toList();

          // Sort
          filtered = filtered.sortBy(sortField, sortOrder);

          return filtered;
        },
      ) ??
      [];
});

/// Provider for selected process
final selectedProcessProvider = StateProvider<ProcessInfo?>((ref) {
  return null;
});

/// Provider for total CPU usage from processes
final totalProcessCpuProvider = Provider<double>((ref) {
  final processesAsync = ref.watch(processListProvider);
  return processesAsync.whenOrNull(
        data: (processes) {
          return processes.fold<double>(
            0,
            (sum, p) => sum + (p.cpuPercent ?? 0),
          );
        },
      ) ??
      0;
});

/// Provider for total memory usage from processes
final totalProcessMemoryProvider = Provider<int>((ref) {
  final processesAsync = ref.watch(processListProvider);
  return processesAsync.whenOrNull(
        data: (processes) {
          return processes.fold<int>(
            0,
            (sum, p) => sum + (p.memoryBytes ?? 0),
          );
        },
      ) ??
      0;
});

/// Provider for process count
final processCountProvider = Provider<int>((ref) {
  final processesAsync = ref.watch(processListProvider);
  return processesAsync.whenOrNull(data: (p) => p.length) ?? 0;
});

/// Provider for top CPU consuming processes
final topCpuProcessesProvider = Provider<List<ProcessInfo>>((ref) {
  final processesAsync = ref.watch(processListProvider);
  return processesAsync.whenOrNull(
        data: (processes) {
          final sorted =
              processes.sortBy(ProcessSortField.cpu, SortOrder.descending);
          return sorted.take(5).toList();
        },
      ) ??
      [];
});

/// Provider for top memory consuming processes
final topMemoryProcessesProvider = Provider<List<ProcessInfo>>((ref) {
  final processesAsync = ref.watch(processListProvider);
  return processesAsync.whenOrNull(
        data: (processes) {
          final sorted =
              processes.sortBy(ProcessSortField.memory, SortOrder.descending);
          return sorted.take(5).toList();
        },
      ) ??
      [];
});

/// Result type for process operations
class ProcessOperationResult {
  const ProcessOperationResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

/// State notifier for process list
class ProcessListNotifier
    extends StateNotifier<AsyncValue<List<ProcessInfo>>> {
  ProcessListNotifier(this._service) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final ProcessService _service;
  Timer? _refreshTimer;

  Future<void> _initialize() async {
    await refresh();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      refresh();
    });
  }

  /// Refresh the process list
  Future<void> refresh() async {
    try {
      final processes = await _service.getProcessList();
      state = AsyncValue.data(processes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Terminate a process gracefully (SIGTERM)
  Future<ProcessOperationResult> terminateProcess(int pid) async {
    try {
      final result = await _service.terminateProcess(pid);
      if (result) {
        // Refresh after termination
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await refresh();
        return const ProcessOperationResult(success: true);
      }
      return const ProcessOperationResult(
        success: false,
        errorMessage: 'Failed to terminate process',
      );
    } catch (e) {
      return ProcessOperationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Force kill a process (SIGKILL)
  Future<ProcessOperationResult> forceKillProcess(int pid) async {
    try {
      final result = await _service.forceKillProcess(pid);
      if (result) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await refresh();
        return const ProcessOperationResult(success: true);
      }
      return const ProcessOperationResult(
        success: false,
        errorMessage: 'Failed to kill process',
      );
    } catch (e) {
      return ProcessOperationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Terminate multiple processes
  Future<Map<int, ProcessOperationResult>> terminateProcesses(
      List<int> pids) async {
    final results = <int, ProcessOperationResult>{};

    for (final pid in pids) {
      results[pid] = await terminateProcess(pid);
    }

    return results;
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

  /// Set custom refresh interval
  void setRefreshInterval(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Provider to check if process can be terminated by current entitlement
final canTerminateProcessProvider =
    Provider.family<bool, ProcessInfo>((ref, process) {
  final entitlement = ref.watch(entitlementProvider);

  return entitlement.whenOrNull(
        data: (e) {
          if (process.isProtected) return false;
          return e.effectiveFeatures.canEndProcesses;
        },
      ) ??
      false;
});

/// Provider to check if process can be force killed
final canForceKillProcessProvider =
    Provider.family<bool, ProcessInfo>((ref, process) {
  final entitlement = ref.watch(entitlementProvider);

  return entitlement.whenOrNull(
        data: (e) {
          if (process.isProtected) return false;
          return e.effectiveFeatures.canForceKillProcesses;
        },
      ) ??
      false;
});
