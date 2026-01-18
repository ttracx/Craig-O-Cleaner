// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CraigOClean.Models;
using CraigOClean.Services;
using Microsoft.UI.Xaml;
using System.Diagnostics;
using System.Reflection;

namespace CraigOClean.ViewModels;

/// <summary>
/// ViewModel for the Settings page.
/// </summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly AppSettings _settings;
    private readonly IBillingService _billingService;
    private readonly IEntitlementManager _entitlementManager;

    [ObservableProperty]
    private bool _startWithWindows;

    [ObservableProperty]
    private bool _startMinimizedToTray;

    [ObservableProperty]
    private bool _showTrayNotifications;

    [ObservableProperty]
    private bool _minimizeToTrayOnClose;

    [ObservableProperty]
    private bool _confirmProcessTermination;

    [ObservableProperty]
    private bool _showProcessDescriptions;

    [ObservableProperty]
    private int _memoryWarningThreshold;

    [ObservableProperty]
    private int _cpuWarningThreshold;

    [ObservableProperty]
    private int _refreshIntervalMs;

    [ObservableProperty]
    private int _selectedThemeIndex;

    [ObservableProperty]
    private SubscriptionInfo _subscription = new();

    [ObservableProperty]
    private string _subscriptionStatusText = string.Empty;

    [ObservableProperty]
    private string _appVersion = string.Empty;

    [ObservableProperty]
    private bool _hasPremiumAccess;

    [ObservableProperty]
    private bool _isLoading;

    /// <summary>
    /// Available theme options.
    /// </summary>
    public List<string> ThemeOptions { get; } = ["System Default", "Light", "Dark"];

    /// <summary>
    /// Available refresh intervals.
    /// </summary>
    public List<KeyValuePair<string, int>> RefreshIntervalOptions { get; } =
    [
        new("1 second", 1000),
        new("2 seconds", 2000),
        new("5 seconds", 5000),
        new("10 seconds", 10000)
    ];

    /// <summary>
    /// Initializes a new instance of SettingsViewModel.
    /// </summary>
    public SettingsViewModel(
        AppSettings settings,
        IBillingService billingService,
        IEntitlementManager entitlementManager)
    {
        _settings = settings;
        _billingService = billingService;
        _entitlementManager = entitlementManager;

        // Load settings
        LoadSettings();

        // Subscribe to subscription changes
        _billingService.SubscriptionChanged += OnSubscriptionChanged;
    }

    /// <summary>
    /// Loads settings from the settings object.
    /// </summary>
    private void LoadSettings()
    {
        StartWithWindows = _settings.StartWithWindows;
        StartMinimizedToTray = _settings.StartMinimizedToTray;
        ShowTrayNotifications = _settings.ShowTrayNotifications;
        MinimizeToTrayOnClose = _settings.MinimizeToTrayOnClose;
        ConfirmProcessTermination = _settings.ConfirmProcessTermination;
        ShowProcessDescriptions = _settings.ShowProcessDescriptions;
        MemoryWarningThreshold = _settings.MemoryWarningThreshold;
        CpuWarningThreshold = _settings.CpuWarningThreshold;
        RefreshIntervalMs = _settings.RefreshIntervalMs;
        SelectedThemeIndex = _settings.Theme;

        // Get subscription info
        Subscription = _billingService.CurrentSubscription;
        HasPremiumAccess = _entitlementManager.HasPremiumAccess;
        UpdateSubscriptionStatusText();

        // Get app version
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        AppVersion = version != null ? $"Version {version.Major}.{version.Minor}.{version.Build}" : "Version 1.0.0";
    }

    /// <summary>
    /// Updates subscription status text.
    /// </summary>
    private void UpdateSubscriptionStatusText()
    {
        SubscriptionStatusText = Subscription.Status switch
        {
            SubscriptionStatus.Active => Subscription.Plan == SubscriptionPlan.Yearly
                ? $"Pro (Yearly) - Renews {Subscription.ExpirationDate:MMM d, yyyy}"
                : $"Pro (Monthly) - Renews {Subscription.ExpirationDate:MMM d, yyyy}",
            SubscriptionStatus.Trial => $"Trial - {Subscription.TrialDaysRemaining} days remaining",
            SubscriptionStatus.Expired => "Subscription expired",
            SubscriptionStatus.GracePeriod => "Payment issue - grace period",
            SubscriptionStatus.Cancelled => "Subscription cancelled",
            _ => "Free version"
        };
    }

    /// <summary>
    /// Handles subscription changes.
    /// </summary>
    private void OnSubscriptionChanged(object? sender, SubscriptionInfo subscription)
    {
        Subscription = subscription;
        HasPremiumAccess = _entitlementManager.HasPremiumAccess;
        UpdateSubscriptionStatusText();
    }

    /// <summary>
    /// Saves settings when StartWithWindows changes.
    /// </summary>
    partial void OnStartWithWindowsChanged(bool value)
    {
        _settings.StartWithWindows = value;
        SaveSettings();
        UpdateStartupTask(value);
    }

    /// <summary>
    /// Saves settings when StartMinimizedToTray changes.
    /// </summary>
    partial void OnStartMinimizedToTrayChanged(bool value)
    {
        _settings.StartMinimizedToTray = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when ShowTrayNotifications changes.
    /// </summary>
    partial void OnShowTrayNotificationsChanged(bool value)
    {
        _settings.ShowTrayNotifications = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when MinimizeToTrayOnClose changes.
    /// </summary>
    partial void OnMinimizeToTrayOnCloseChanged(bool value)
    {
        _settings.MinimizeToTrayOnClose = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when ConfirmProcessTermination changes.
    /// </summary>
    partial void OnConfirmProcessTerminationChanged(bool value)
    {
        _settings.ConfirmProcessTermination = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when ShowProcessDescriptions changes.
    /// </summary>
    partial void OnShowProcessDescriptionsChanged(bool value)
    {
        _settings.ShowProcessDescriptions = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when MemoryWarningThreshold changes.
    /// </summary>
    partial void OnMemoryWarningThresholdChanged(int value)
    {
        _settings.MemoryWarningThreshold = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when CpuWarningThreshold changes.
    /// </summary>
    partial void OnCpuWarningThresholdChanged(int value)
    {
        _settings.CpuWarningThreshold = value;
        SaveSettings();
    }

    /// <summary>
    /// Saves settings when RefreshIntervalMs changes.
    /// </summary>
    partial void OnRefreshIntervalMsChanged(int value)
    {
        _settings.RefreshIntervalMs = value;
        SaveSettings();

        // Restart monitoring with new interval
        var metricsService = App.GetService<ISystemMetricsService>();
        metricsService.StopMonitoring();
        metricsService.StartMonitoring(value);
    }

    /// <summary>
    /// Saves settings when SelectedThemeIndex changes.
    /// </summary>
    partial void OnSelectedThemeIndexChanged(int value)
    {
        _settings.Theme = value;
        SaveSettings();
        ApplyTheme(value);
    }

    /// <summary>
    /// Saves settings to disk.
    /// </summary>
    private void SaveSettings()
    {
        try
        {
            _settings.Save();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error saving settings: {ex.Message}");
        }
    }

    /// <summary>
    /// Updates the Windows startup task.
    /// </summary>
    private async void UpdateStartupTask(bool enable)
    {
        try
        {
            var startupTask = await Windows.ApplicationModel.StartupTask.GetAsync("CraigOCleanStartup");

            if (enable)
            {
                var state = await startupTask.RequestEnableAsync();
                if (state != Windows.ApplicationModel.StartupTaskState.Enabled)
                {
                    Debug.WriteLine($"Failed to enable startup task: {state}");
                }
            }
            else
            {
                startupTask.Disable();
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error updating startup task: {ex.Message}");
        }
    }

    /// <summary>
    /// Applies the selected theme.
    /// </summary>
    private void ApplyTheme(int themeIndex)
    {
        if (App.Current.MainWindow?.Content is FrameworkElement rootElement)
        {
            rootElement.RequestedTheme = themeIndex switch
            {
                1 => ElementTheme.Light,
                2 => ElementTheme.Dark,
                _ => ElementTheme.Default
            };
        }
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
    /// Restores purchases.
    /// </summary>
    [RelayCommand]
    private async Task RestorePurchasesAsync()
    {
        IsLoading = true;

        try
        {
            var restored = await _billingService.RestorePurchasesAsync();

            if (restored)
            {
                Debug.WriteLine("Purchases restored successfully");
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error restoring purchases: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Opens the feedback/support page.
    /// </summary>
    [RelayCommand]
    private void OpenFeedback()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "mailto:support@craigoclean.com?subject=Craig-O-Clean%20Feedback",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening feedback: {ex.Message}");
        }
    }

    /// <summary>
    /// Opens the privacy policy.
    /// </summary>
    [RelayCommand]
    private void OpenPrivacyPolicy()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://www.craigoclean.com/privacy",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening privacy policy: {ex.Message}");
        }
    }

    /// <summary>
    /// Opens the terms of service.
    /// </summary>
    [RelayCommand]
    private void OpenTermsOfService()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://www.craigoclean.com/terms",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening terms: {ex.Message}");
        }
    }

    /// <summary>
    /// Resets all settings to defaults.
    /// </summary>
    [RelayCommand]
    private void ResetSettings()
    {
        // Reset to defaults
        StartWithWindows = false;
        StartMinimizedToTray = false;
        ShowTrayNotifications = true;
        MinimizeToTrayOnClose = true;
        ConfirmProcessTermination = true;
        ShowProcessDescriptions = true;
        MemoryWarningThreshold = 80;
        CpuWarningThreshold = 90;
        RefreshIntervalMs = 2000;
        SelectedThemeIndex = 0;
    }

    /// <summary>
    /// Cleans up resources.
    /// </summary>
    public void Cleanup()
    {
        _billingService.SubscriptionChanged -= OnSubscriptionChanged;
    }
}
