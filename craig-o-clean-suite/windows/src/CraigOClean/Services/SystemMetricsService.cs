// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using System.Diagnostics;
using System.Runtime.InteropServices;
using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service for retrieving system metrics using Windows APIs.
/// </summary>
public sealed class SystemMetricsService : ISystemMetricsService
{
    private readonly PerformanceCounter? _cpuCounter;
    private readonly object _lock = new();
    private Timer? _monitoringTimer;
    private bool _isMonitoring;
    private bool _disposed;

    /// <inheritdoc/>
    public event EventHandler<SystemMetrics>? MetricsUpdated;

    /// <inheritdoc/>
    public SystemMetrics CurrentMetrics { get; private set; } = new();

    /// <inheritdoc/>
    public bool IsMonitoring => _isMonitoring;

    /// <summary>
    /// Initializes a new instance of the SystemMetricsService.
    /// </summary>
    public SystemMetricsService()
    {
        try
        {
            _cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total", true);
            // Warm up the counter - first call returns 0
            _cpuCounter.NextValue();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to initialize CPU counter: {ex.Message}");
        }
    }

    /// <inheritdoc/>
    public async Task<SystemMetrics> GetMetricsAsync()
    {
        return await Task.Run(() =>
        {
            var metrics = new SystemMetrics();

            // Get CPU usage
            try
            {
                if (_cpuCounter != null)
                {
                    metrics.CpuUsagePercent = Math.Round(_cpuCounter.NextValue(), 1);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to get CPU usage: {ex.Message}");
            }

            // Get memory information using GlobalMemoryStatusEx
            try
            {
                var memStatus = new MEMORYSTATUSEX { dwLength = (uint)Marshal.SizeOf<MEMORYSTATUSEX>() };
                if (GlobalMemoryStatusEx(ref memStatus))
                {
                    metrics.TotalPhysicalMemory = memStatus.ullTotalPhys;
                    metrics.AvailablePhysicalMemory = memStatus.ullAvailPhys;
                    metrics.TotalVirtualMemory = memStatus.ullTotalVirtual;
                    metrics.AvailableVirtualMemory = memStatus.ullAvailVirtual;
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to get memory info: {ex.Message}");
            }

            // Get commit charge using GetPerformanceInfo
            try
            {
                var perfInfo = new PERFORMANCE_INFORMATION { cb = (uint)Marshal.SizeOf<PERFORMANCE_INFORMATION>() };
                if (GetPerformanceInfo(ref perfInfo, perfInfo.cb))
                {
                    var pageSize = (long)perfInfo.PageSize;
                    metrics.CommitTotal = (ulong)(perfInfo.CommitTotal * pageSize);
                    metrics.CommitLimit = (ulong)(perfInfo.CommitLimit * pageSize);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to get performance info: {ex.Message}");
            }

            // Calculate memory pressure level
            metrics.PressureLevel = CalculatePressureLevel(metrics.MemoryUsagePercent);
            metrics.Timestamp = DateTime.UtcNow;

            lock (_lock)
            {
                CurrentMetrics = metrics;
            }

            return metrics;
        });
    }

    /// <inheritdoc/>
    public void StartMonitoring(int intervalMs = 2000)
    {
        if (_isMonitoring) return;

        _isMonitoring = true;
        _monitoringTimer = new Timer(async _ =>
        {
            try
            {
                var metrics = await GetMetricsAsync();
                MetricsUpdated?.Invoke(this, metrics);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Monitoring error: {ex.Message}");
            }
        }, null, 0, intervalMs);
    }

    /// <inheritdoc/>
    public void StopMonitoring()
    {
        _isMonitoring = false;
        _monitoringTimer?.Dispose();
        _monitoringTimer = null;
    }

    private static MemoryPressureLevel CalculatePressureLevel(double usagePercent)
    {
        return usagePercent switch
        {
            >= 90 => MemoryPressureLevel.Critical,
            >= 80 => MemoryPressureLevel.High,
            >= 60 => MemoryPressureLevel.Moderate,
            _ => MemoryPressureLevel.Low
        };
    }

    /// <inheritdoc/>
    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        StopMonitoring();
        _cpuCounter?.Dispose();
    }

    #region Native Interop

    [StructLayout(LayoutKind.Sequential)]
    private struct MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PERFORMANCE_INFORMATION
    {
        public uint cb;
        public UIntPtr CommitTotal;
        public UIntPtr CommitLimit;
        public UIntPtr CommitPeak;
        public UIntPtr PhysicalTotal;
        public UIntPtr PhysicalAvailable;
        public UIntPtr SystemCache;
        public UIntPtr KernelTotal;
        public UIntPtr KernelPaged;
        public UIntPtr KernelNonpaged;
        public UIntPtr PageSize;
        public uint HandleCount;
        public uint ProcessCount;
        public uint ThreadCount;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    [DllImport("psapi.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetPerformanceInfo(ref PERFORMANCE_INFORMATION pPerformanceInformation, uint cb);

    #endregion
}
