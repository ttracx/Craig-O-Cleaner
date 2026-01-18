// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service interface for process management operations.
/// </summary>
public interface IProcessService
{
    /// <summary>
    /// Gets all running processes with their information.
    /// </summary>
    Task<IReadOnlyList<ProcessInfo>> GetProcessesAsync();

    /// <summary>
    /// Gets information about a specific process.
    /// </summary>
    Task<ProcessInfo?> GetProcessAsync(int processId);

    /// <summary>
    /// Gets the top processes by CPU usage.
    /// </summary>
    Task<IReadOnlyList<ProcessInfo>> GetTopCpuProcessesAsync(int count = 5);

    /// <summary>
    /// Gets the top processes by memory usage.
    /// </summary>
    Task<IReadOnlyList<ProcessInfo>> GetTopMemoryProcessesAsync(int count = 5);

    /// <summary>
    /// Attempts to gracefully close a process.
    /// </summary>
    Task<ProcessTerminationResult> EndTaskAsync(int processId);

    /// <summary>
    /// Force terminates a process.
    /// </summary>
    Task<ProcessTerminationResult> ForceKillAsync(int processId);

    /// <summary>
    /// Checks if a process is protected and cannot be terminated.
    /// </summary>
    bool IsProtectedProcess(int processId);

    /// <summary>
    /// Checks if a process is protected and cannot be terminated.
    /// </summary>
    bool IsProtectedProcess(string processName);
}
