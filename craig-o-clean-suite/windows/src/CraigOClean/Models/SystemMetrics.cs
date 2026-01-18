// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

namespace CraigOClean.Models;

/// <summary>
/// Represents current system metrics including CPU and memory usage.
/// </summary>
public sealed class SystemMetrics
{
    /// <summary>
    /// Gets or sets the current CPU usage percentage (0-100).
    /// </summary>
    public double CpuUsagePercent { get; set; }

    /// <summary>
    /// Gets or sets the total physical memory in bytes.
    /// </summary>
    public ulong TotalPhysicalMemory { get; set; }

    /// <summary>
    /// Gets or sets the available physical memory in bytes.
    /// </summary>
    public ulong AvailablePhysicalMemory { get; set; }

    /// <summary>
    /// Gets or sets the memory in use in bytes.
    /// </summary>
    public ulong MemoryInUse => TotalPhysicalMemory - AvailablePhysicalMemory;

    /// <summary>
    /// Gets the memory usage percentage (0-100).
    /// </summary>
    public double MemoryUsagePercent => TotalPhysicalMemory > 0
        ? (double)MemoryInUse / TotalPhysicalMemory * 100
        : 0;

    /// <summary>
    /// Gets or sets the total commit charge limit in bytes.
    /// </summary>
    public ulong CommitLimit { get; set; }

    /// <summary>
    /// Gets or sets the current commit charge in bytes.
    /// </summary>
    public ulong CommitTotal { get; set; }

    /// <summary>
    /// Gets the commit charge usage percentage.
    /// </summary>
    public double CommitUsagePercent => CommitLimit > 0
        ? (double)CommitTotal / CommitLimit * 100
        : 0;

    /// <summary>
    /// Gets or sets the total virtual memory in bytes.
    /// </summary>
    public ulong TotalVirtualMemory { get; set; }

    /// <summary>
    /// Gets or sets the available virtual memory in bytes.
    /// </summary>
    public ulong AvailableVirtualMemory { get; set; }

    /// <summary>
    /// Gets or sets the memory pressure level.
    /// </summary>
    public MemoryPressureLevel PressureLevel { get; set; }

    /// <summary>
    /// Gets or sets the timestamp when these metrics were captured.
    /// </summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Creates a copy of this metrics instance.
    /// </summary>
    public SystemMetrics Clone() => new()
    {
        CpuUsagePercent = CpuUsagePercent,
        TotalPhysicalMemory = TotalPhysicalMemory,
        AvailablePhysicalMemory = AvailablePhysicalMemory,
        CommitLimit = CommitLimit,
        CommitTotal = CommitTotal,
        TotalVirtualMemory = TotalVirtualMemory,
        AvailableVirtualMemory = AvailableVirtualMemory,
        PressureLevel = PressureLevel,
        Timestamp = Timestamp
    };
}

/// <summary>
/// Indicates the current memory pressure level.
/// </summary>
public enum MemoryPressureLevel
{
    /// <summary>
    /// Memory usage is low (below 60%).
    /// </summary>
    Low,

    /// <summary>
    /// Memory usage is moderate (60-80%).
    /// </summary>
    Moderate,

    /// <summary>
    /// Memory usage is high (80-90%).
    /// </summary>
    High,

    /// <summary>
    /// Memory usage is critical (above 90%).
    /// </summary>
    Critical
}
