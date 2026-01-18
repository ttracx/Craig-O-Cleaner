// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

namespace CraigOClean.Models;

/// <summary>
/// Represents information about a running process.
/// </summary>
public sealed class ProcessInfo
{
    /// <summary>
    /// Gets or sets the process ID.
    /// </summary>
    public int ProcessId { get; set; }

    /// <summary>
    /// Gets or sets the process name.
    /// </summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the full path to the process executable.
    /// </summary>
    public string? ExecutablePath { get; set; }

    /// <summary>
    /// Gets or sets the CPU usage percentage for this process.
    /// </summary>
    public double CpuUsagePercent { get; set; }

    /// <summary>
    /// Gets or sets the working set memory size in bytes.
    /// </summary>
    public long WorkingSetBytes { get; set; }

    /// <summary>
    /// Gets or sets the private memory size in bytes.
    /// </summary>
    public long PrivateMemoryBytes { get; set; }

    /// <summary>
    /// Gets or sets the number of threads in the process.
    /// </summary>
    public int ThreadCount { get; set; }

    /// <summary>
    /// Gets or sets the number of handles opened by the process.
    /// </summary>
    public int HandleCount { get; set; }

    /// <summary>
    /// Gets or sets the process priority class.
    /// </summary>
    public string PriorityClass { get; set; } = "Normal";

    /// <summary>
    /// Gets or sets when the process started.
    /// </summary>
    public DateTime? StartTime { get; set; }

    /// <summary>
    /// Gets or sets whether the process has a main window.
    /// </summary>
    public bool HasMainWindow { get; set; }

    /// <summary>
    /// Gets or sets the main window title if available.
    /// </summary>
    public string? MainWindowTitle { get; set; }

    /// <summary>
    /// Gets or sets whether this is a system process.
    /// </summary>
    public bool IsSystemProcess { get; set; }

    /// <summary>
    /// Gets or sets whether this process is protected and cannot be terminated.
    /// </summary>
    public bool IsProtected { get; set; }

    /// <summary>
    /// Gets or sets the username running the process.
    /// </summary>
    public string? UserName { get; set; }

    /// <summary>
    /// Gets or sets the process description from file version info.
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    /// Gets or sets the publisher/company from file version info.
    /// </summary>
    public string? Publisher { get; set; }

    /// <summary>
    /// Gets the formatted working set size.
    /// </summary>
    public string FormattedWorkingSet => FormatBytes(WorkingSetBytes);

    /// <summary>
    /// Formats bytes into a human-readable string.
    /// </summary>
    private static string FormatBytes(long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB", "TB"];
        int order = 0;
        double size = bytes;

        while (size >= 1024 && order < sizes.Length - 1)
        {
            order++;
            size /= 1024;
        }

        return $"{size:0.##} {sizes[order]}";
    }
}

/// <summary>
/// Represents the result of a process termination attempt.
/// </summary>
public sealed class ProcessTerminationResult
{
    /// <summary>
    /// Gets or sets whether the termination was successful.
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// Gets or sets the error message if termination failed.
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Gets or sets whether the process required force kill.
    /// </summary>
    public bool WasForceKilled { get; set; }

    /// <summary>
    /// Creates a successful result.
    /// </summary>
    public static ProcessTerminationResult Succeeded(bool wasForceKilled = false) => new()
    {
        Success = true,
        WasForceKilled = wasForceKilled
    };

    /// <summary>
    /// Creates a failed result.
    /// </summary>
    public static ProcessTerminationResult Failed(string errorMessage) => new()
    {
        Success = false,
        ErrorMessage = errorMessage
    };
}
