// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using CraigOClean.Models;
using CraigOClean.Services;
using CraigOClean.ViewModels;
using CraigOClean.Views;
using System.Diagnostics;
using WinUIEx;

namespace CraigOClean;

/// <summary>
/// Main window with navigation shell.
/// </summary>
public sealed partial class MainWindow : WindowEx
{
    private readonly MainViewModel _viewModel;
    private readonly ISystemMetricsService _metricsService;
    private readonly IBillingService _billingService;
    private readonly ITrayService _trayService;
    private readonly AppSettings _settings;

    /// <summary>
    /// Initializes a new instance of the MainWindow.
    /// </summary>
    public MainWindow()
    {
        InitializeComponent();

        // Get services
        _viewModel = App.GetService<MainViewModel>();
        _metricsService = App.GetService<ISystemMetricsService>();
        _billingService = App.GetService<IBillingService>();
        _trayService = App.GetService<ITrayService>();
        _settings = App.Current.Settings;

        // Set up title bar
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        // Subscribe to events
        _metricsService.MetricsUpdated += OnMetricsUpdated;
        _billingService.SubscriptionChanged += OnSubscriptionChanged;

        // Initialize tray service
        _trayService.Initialize();
        _trayService.OpenRequested += OnTrayOpenRequested;
        _trayService.ExitRequested += OnTrayExitRequested;

        // Handle window close
        Closed += OnWindowClosed;

        // Update subscription display
        UpdateSubscriptionDisplay(_billingService.CurrentSubscription);
    }

    /// <summary>
    /// Handles NavigationView loaded event.
    /// </summary>
    private void NavView_Loaded(object sender, RoutedEventArgs e)
    {
        // Navigate to dashboard by default
        NavView.SelectedItem = NavView.MenuItems[0];
        ContentFrame.Navigate(typeof(DashboardPage));

        // Update paywall visibility based on subscription
        UpdatePaywallVisibility();
    }

    /// <summary>
    /// Handles navigation selection changes.
    /// </summary>
    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {
            ContentFrame.Navigate(typeof(SettingsPage));
            return;
        }

        if (args.SelectedItem is NavigationViewItem item)
        {
            var tag = item.Tag?.ToString();
            NavigateToPage(tag);
        }
    }

    /// <summary>
    /// Navigates to the specified page by tag.
    /// </summary>
    private void NavigateToPage(string? tag)
    {
        Type? pageType = tag switch
        {
            "dashboard" => typeof(DashboardPage),
            "processes" => typeof(ProcessListPage),
            "paywall" => typeof(PaywallPage),
            "help" => typeof(DashboardPage), // Could be a help page
            _ => null
        };

        if (pageType != null && ContentFrame.CurrentSourcePageType != pageType)
        {
            ContentFrame.Navigate(pageType);
        }
    }

    /// <summary>
    /// Handles navigation failures.
    /// </summary>
    private void ContentFrame_NavigationFailed(object sender, NavigationFailedEventArgs e)
    {
        Debug.WriteLine($"Navigation failed: {e.Exception}");
        e.Handled = true;
    }

    /// <summary>
    /// Handles metrics updates from the service.
    /// </summary>
    private void OnMetricsUpdated(object? sender, SystemMetrics metrics)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            CpuStatusText.Text = $"CPU: {metrics.CpuUsagePercent:F0}%";
            MemoryStatusText.Text = $"RAM: {metrics.MemoryUsagePercent:F0}%";

            // Update dashboard badge if high usage
            if (metrics.PressureLevel >= MemoryPressureLevel.High ||
                metrics.CpuUsagePercent >= _settings.CpuWarningThreshold)
            {
                DashboardBadge.Visibility = Visibility.Visible;
            }
            else
            {
                DashboardBadge.Visibility = Visibility.Collapsed;
            }

            // Update tray icon
            _trayService.UpdateTooltip(metrics, null, null);
        });
    }

    /// <summary>
    /// Handles subscription changes.
    /// </summary>
    private void OnSubscriptionChanged(object? sender, SubscriptionInfo subscription)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            UpdateSubscriptionDisplay(subscription);
            UpdatePaywallVisibility();
        });
    }

    /// <summary>
    /// Updates the subscription badge display.
    /// </summary>
    private void UpdateSubscriptionDisplay(SubscriptionInfo subscription)
    {
        SubscriptionText.Text = subscription.Status switch
        {
            SubscriptionStatus.Active => subscription.Plan == SubscriptionPlan.Yearly ? "Pro (Yearly)" : "Pro",
            SubscriptionStatus.Trial => $"Trial ({subscription.TrialDaysRemaining}d left)",
            SubscriptionStatus.Expired => "Expired",
            SubscriptionStatus.GracePeriod => "Grace Period",
            _ => "Free"
        };

        // Update badge color based on status
        SubscriptionBadge.Background = subscription.Status switch
        {
            SubscriptionStatus.Active => new Microsoft.UI.Xaml.Media.SolidColorBrush(
                Microsoft.UI.Colors.Green with { A = 80 }),
            SubscriptionStatus.Trial => new Microsoft.UI.Xaml.Media.SolidColorBrush(
                Microsoft.UI.Colors.Orange with { A = 80 }),
            _ => new Microsoft.UI.Xaml.Media.SolidColorBrush(
                Microsoft.UI.Colors.White with { A = 34 })
        };
    }

    /// <summary>
    /// Updates the paywall navigation item visibility.
    /// </summary>
    private void UpdatePaywallVisibility()
    {
        var subscription = _billingService.CurrentSubscription;
        PaywallNavItem.Visibility = subscription.Status == SubscriptionStatus.Active
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    /// <summary>
    /// Handles tray open request.
    /// </summary>
    private void OnTrayOpenRequested(object? sender, EventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            Activate();
            BringToFront();
        });
    }

    /// <summary>
    /// Handles tray exit request.
    /// </summary>
    private void OnTrayExitRequested(object? sender, EventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            App.Current.ExitApplication();
        });
    }

    /// <summary>
    /// Handles window close event.
    /// </summary>
    private void OnWindowClosed(object sender, WindowEventArgs args)
    {
        if (_settings.MinimizeToTrayOnClose)
        {
            args.Handled = true;
            _trayService.Show();
            Hide();
        }
        else
        {
            // Unsubscribe from events
            _metricsService.MetricsUpdated -= OnMetricsUpdated;
            _billingService.SubscriptionChanged -= OnSubscriptionChanged;
            _trayService.OpenRequested -= OnTrayOpenRequested;
            _trayService.ExitRequested -= OnTrayExitRequested;

            App.Current.ExitApplication();
        }
    }

    /// <summary>
    /// Shows the loading overlay.
    /// </summary>
    public void ShowLoading(string message = "Loading...")
    {
        LoadingText.Text = message;
        LoadingOverlay.Visibility = Visibility.Visible;
    }

    /// <summary>
    /// Hides the loading overlay.
    /// </summary>
    public void HideLoading()
    {
        LoadingOverlay.Visibility = Visibility.Collapsed;
    }

    /// <summary>
    /// Navigates to the paywall page.
    /// </summary>
    public void NavigateToPaywall()
    {
        NavView.SelectedItem = PaywallNavItem;
        ContentFrame.Navigate(typeof(PaywallPage));
    }

    /// <summary>
    /// Shows a dialog message.
    /// </summary>
    public async Task ShowMessageAsync(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = Content.XamlRoot
        };

        await dialog.ShowAsync();
    }

    /// <summary>
    /// Shows a confirmation dialog.
    /// </summary>
    public async Task<bool> ShowConfirmationAsync(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            PrimaryButtonText = "Yes",
            CloseButtonText = "No",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = Content.XamlRoot
        };

        var result = await dialog.ShowAsync();
        return result == ContentDialogResult.Primary;
    }
}
