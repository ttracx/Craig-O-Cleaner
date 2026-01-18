// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CraigOClean.Models;
using CraigOClean.Services;
using System.Diagnostics;

namespace CraigOClean.ViewModels;

/// <summary>
/// ViewModel for the main window.
/// </summary>
public sealed partial class MainViewModel : ObservableObject
{
    private readonly ISystemMetricsService _metricsService;
    private readonly IBillingService _billingService;
    private readonly IEntitlementManager _entitlementManager;
    private readonly ITrayService _trayService;
    private readonly AppSettings _settings;

    [ObservableProperty]
    private SystemMetrics _currentMetrics = new();

    [ObservableProperty]
    private SubscriptionInfo _currentSubscription = new();

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _isPremiumUser;

    [ObservableProperty]
    private bool _showUpgradePrompt;

    /// <summary>
    /// Initializes a new instance of MainViewModel.
    /// </summary>
    public MainViewModel(
        ISystemMetricsService metricsService,
        IBillingService billingService,
        IEntitlementManager entitlementManager,
        ITrayService trayService,
        AppSettings settings)
    {
        _metricsService = metricsService;
        _billingService = billingService;
        _entitlementManager = entitlementManager;
        _trayService = trayService;
        _settings = settings;

        // Subscribe to events
        _metricsService.MetricsUpdated += OnMetricsUpdated;
        _billingService.SubscriptionChanged += OnSubscriptionChanged;

        // Initialize state
        CurrentMetrics = _metricsService.CurrentMetrics;
        CurrentSubscription = _billingService.CurrentSubscription;
        UpdatePremiumStatus();
    }

    /// <summary>
    /// Initializes the ViewModel.
    /// </summary>
    [RelayCommand]
    private async Task InitializeAsync()
    {
        IsLoading = true;
        StatusMessage = "Initializing...";

        try
        {
            // Refresh subscription status
            await _billingService.GetSubscriptionStatusAsync();
            UpdatePremiumStatus();

            // Get initial metrics
            CurrentMetrics = await _metricsService.GetMetricsAsync();

            StatusMessage = string.Empty;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Initialization error: {ex.Message}");
            StatusMessage = "Failed to initialize. Some features may be unavailable.";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Handles metrics updates.
    /// </summary>
    private void OnMetricsUpdated(object? sender, SystemMetrics metrics)
    {
        CurrentMetrics = metrics;

        // Check for high usage warnings
        if (metrics.PressureLevel >= MemoryPressureLevel.High &&
            _settings.ShowTrayNotifications)
        {
            _trayService.ShowNotification(
                "High Memory Usage",
                $"Memory usage is at {metrics.MemoryUsagePercent:F0}%. Consider closing some applications.",
                true);
        }

        if (metrics.CpuUsagePercent >= _settings.CpuWarningThreshold &&
            _settings.ShowTrayNotifications)
        {
            _trayService.ShowNotification(
                "High CPU Usage",
                $"CPU usage is at {metrics.CpuUsagePercent:F0}%.",
                true);
        }
    }

    /// <summary>
    /// Handles subscription changes.
    /// </summary>
    private void OnSubscriptionChanged(object? sender, SubscriptionInfo subscription)
    {
        CurrentSubscription = subscription;
        UpdatePremiumStatus();
    }

    /// <summary>
    /// Updates premium user status.
    /// </summary>
    private void UpdatePremiumStatus()
    {
        IsPremiumUser = _entitlementManager.HasPremiumAccess;
        ShowUpgradePrompt = !IsPremiumUser && CurrentSubscription.Status != SubscriptionStatus.Trial;
    }

    /// <summary>
    /// Opens subscription management.
    /// </summary>
    [RelayCommand]
    private async Task ManageSubscriptionAsync()
    {
        await _billingService.ManageSubscriptionAsync();
    }

    /// <summary>
    /// Refreshes current data.
    /// </summary>
    [RelayCommand]
    private async Task RefreshAsync()
    {
        IsLoading = true;
        try
        {
            CurrentMetrics = await _metricsService.GetMetricsAsync();
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Cleans up resources.
    /// </summary>
    public void Cleanup()
    {
        _metricsService.MetricsUpdated -= OnMetricsUpdated;
        _billingService.SubscriptionChanged -= OnSubscriptionChanged;
    }
}
