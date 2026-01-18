// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CraigOClean.Models;
using CraigOClean.Services;
using System.Collections.ObjectModel;
using System.Diagnostics;

namespace CraigOClean.ViewModels;

/// <summary>
/// ViewModel for the Dashboard page.
/// </summary>
public sealed partial class DashboardViewModel : ObservableObject
{
    private readonly ISystemMetricsService _metricsService;
    private readonly IProcessService _processService;
    private readonly ICleanupService _cleanupService;
    private readonly IEntitlementManager _entitlementManager;

    [ObservableProperty]
    private SystemMetrics _currentMetrics = new();

    [ObservableProperty]
    private double _cpuUsage;

    [ObservableProperty]
    private double _memoryUsage;

    [ObservableProperty]
    private string _memoryUsedText = "0 GB";

    [ObservableProperty]
    private string _memoryTotalText = "0 GB";

    [ObservableProperty]
    private string _cpuStatusColor = "#22C55E";

    [ObservableProperty]
    private string _memoryStatusColor = "#22C55E";

    [ObservableProperty]
    private ObservableCollection<ProcessInfo> _topCpuProcesses = [];

    [ObservableProperty]
    private ObservableCollection<ProcessInfo> _topMemoryProcesses = [];

    [ObservableProperty]
    private CleanupInfo? _cleanupInfo;

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _isScanning;

    [ObservableProperty]
    private string _scanStatus = string.Empty;

    [ObservableProperty]
    private bool _hasPremiumAccess;

    [ObservableProperty]
    private string _cleanableSize = "0 MB";

    /// <summary>
    /// Initializes a new instance of DashboardViewModel.
    /// </summary>
    public DashboardViewModel(
        ISystemMetricsService metricsService,
        IProcessService processService,
        ICleanupService cleanupService,
        IEntitlementManager entitlementManager)
    {
        _metricsService = metricsService;
        _processService = processService;
        _cleanupService = cleanupService;
        _entitlementManager = entitlementManager;

        // Subscribe to metrics updates
        _metricsService.MetricsUpdated += OnMetricsUpdated;

        // Check premium status
        HasPremiumAccess = _entitlementManager.HasPremiumAccess;
    }

    /// <summary>
    /// Loads initial data.
    /// </summary>
    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;

        try
        {
            // Get current metrics
            var metrics = await _metricsService.GetMetricsAsync();
            UpdateMetricsDisplay(metrics);

            // Load top processes
            await LoadTopProcessesAsync();

            // Scan for cleanable files
            await ScanForCleanupAsync();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Dashboard load error: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Refreshes all dashboard data.
    /// </summary>
    [RelayCommand]
    private async Task RefreshAsync()
    {
        await LoadAsync();
    }

    /// <summary>
    /// Loads top CPU and memory processes.
    /// </summary>
    private async Task LoadTopProcessesAsync()
    {
        try
        {
            var topCpu = await _processService.GetTopCpuProcessesAsync(5);
            var topMemory = await _processService.GetTopMemoryProcessesAsync(5);

            TopCpuProcesses.Clear();
            foreach (var process in topCpu)
            {
                TopCpuProcesses.Add(process);
            }

            TopMemoryProcesses.Clear();
            foreach (var process in topMemory)
            {
                TopMemoryProcesses.Add(process);
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error loading top processes: {ex.Message}");
        }
    }

    /// <summary>
    /// Scans for cleanable files.
    /// </summary>
    [RelayCommand]
    private async Task ScanForCleanupAsync()
    {
        if (!HasPremiumAccess && !_entitlementManager.CanUseCoreFeatures)
        {
            return;
        }

        IsScanning = true;
        ScanStatus = "Scanning...";

        try
        {
            var progress = new Progress<string>(status => ScanStatus = status);
            CleanupInfo = await _cleanupService.ScanAsync(progress);
            CleanableSize = CleanupInfo.FormattedTotalSize;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Scan error: {ex.Message}");
            ScanStatus = "Scan failed";
        }
        finally
        {
            IsScanning = false;
            ScanStatus = string.Empty;
        }
    }

    /// <summary>
    /// Performs cleanup of temporary files.
    /// </summary>
    [RelayCommand]
    private async Task CleanupAsync()
    {
        if (!_entitlementManager.CanPerformCleanup)
        {
            // Show paywall
            return;
        }

        IsLoading = true;

        try
        {
            var progress = new Progress<string>(status => ScanStatus = status);
            var result = await _cleanupService.CleanupAsync(CleanupType.All, progress);

            if (result.Success)
            {
                ScanStatus = $"Cleaned {result.FormattedBytesFreed}!";
                await ScanForCleanupAsync();
            }
            else
            {
                ScanStatus = "Cleanup completed with some errors.";
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Cleanup error: {ex.Message}");
            ScanStatus = "Cleanup failed";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Ends a process task.
    /// </summary>
    [RelayCommand]
    private async Task EndProcessAsync(ProcessInfo? process)
    {
        if (process == null || process.IsProtected)
            return;

        try
        {
            var result = await _processService.EndTaskAsync(process.ProcessId);

            if (result.Success)
            {
                await LoadTopProcessesAsync();
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error ending process: {ex.Message}");
        }
    }

    /// <summary>
    /// Opens Windows Disk Cleanup.
    /// </summary>
    [RelayCommand]
    private async Task OpenDiskCleanupAsync()
    {
        await _cleanupService.OpenDiskCleanupAsync();
    }

    /// <summary>
    /// Opens Windows Storage Settings.
    /// </summary>
    [RelayCommand]
    private async Task OpenStorageSettingsAsync()
    {
        await _cleanupService.OpenStorageSettingsAsync();
    }

    /// <summary>
    /// Handles metrics update events.
    /// </summary>
    private void OnMetricsUpdated(object? sender, SystemMetrics metrics)
    {
        UpdateMetricsDisplay(metrics);
    }

    /// <summary>
    /// Updates the metrics display.
    /// </summary>
    private void UpdateMetricsDisplay(SystemMetrics metrics)
    {
        CurrentMetrics = metrics;
        CpuUsage = metrics.CpuUsagePercent;
        MemoryUsage = metrics.MemoryUsagePercent;

        // Format memory text
        var usedGb = metrics.MemoryInUse / (1024.0 * 1024 * 1024);
        var totalGb = metrics.TotalPhysicalMemory / (1024.0 * 1024 * 1024);
        MemoryUsedText = $"{usedGb:F1} GB";
        MemoryTotalText = $"{totalGb:F1} GB";

        // Update status colors based on thresholds
        CpuStatusColor = metrics.CpuUsagePercent switch
        {
            >= 90 => "#DC2626", // Critical red
            >= 80 => "#EF4444", // High red
            >= 60 => "#F59E0B", // Warning yellow
            _ => "#22C55E"      // Good green
        };

        MemoryStatusColor = metrics.PressureLevel switch
        {
            MemoryPressureLevel.Critical => "#DC2626",
            MemoryPressureLevel.High => "#EF4444",
            MemoryPressureLevel.Moderate => "#F59E0B",
            _ => "#22C55E"
        };
    }

    /// <summary>
    /// Cleans up resources.
    /// </summary>
    public void Cleanup()
    {
        _metricsService.MetricsUpdated -= OnMetricsUpdated;
    }
}
