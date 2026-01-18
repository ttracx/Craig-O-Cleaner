// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.UI.Xaml;
using CraigOClean.Models;
using CraigOClean.Services;
using CraigOClean.ViewModels;
using CraigOClean.Views;
using System.Diagnostics;
using WinUIEx;

namespace CraigOClean;

/// <summary>
/// Application entry point with dependency injection configuration.
/// </summary>
public partial class App : Application
{
    private readonly IHost _host;
    private Window? _mainWindow;

    /// <summary>
    /// Gets the current application instance.
    /// </summary>
    public static new App Current => (App)Application.Current;

    /// <summary>
    /// Gets the service provider for dependency injection.
    /// </summary>
    public IServiceProvider Services => _host.Services;

    /// <summary>
    /// Gets the application settings.
    /// </summary>
    public AppSettings Settings { get; }

    /// <summary>
    /// Gets the main window instance.
    /// </summary>
    public Window? MainWindow => _mainWindow;

    /// <summary>
    /// Initializes a new instance of the application.
    /// </summary>
    public App()
    {
        InitializeComponent();

        // Load settings
        Settings = AppSettings.Load();

        // Configure host with dependency injection
        _host = Host.CreateDefaultBuilder()
            .ConfigureServices((context, services) =>
            {
                // Register settings
                services.AddSingleton(Settings);

                // Register services
                services.AddSingleton<ISystemMetricsService, SystemMetricsService>();
                services.AddSingleton<IProcessService, ProcessService>();
                services.AddSingleton<ICleanupService, CleanupService>();
                services.AddSingleton<IBillingService, BillingService>();
                services.AddSingleton<IProcessManagerService, ProcessManagerService>();
                services.AddSingleton<IEntitlementManager, EntitlementManager>();
                services.AddSingleton<ITrayService, TrayService>();

                // Register ViewModels
                services.AddTransient<MainViewModel>();
                services.AddTransient<DashboardViewModel>();
                services.AddTransient<ProcessListViewModel>();
                services.AddTransient<SettingsViewModel>();
                services.AddTransient<PaywallViewModel>();

                // Register Views
                services.AddTransient<MainWindow>();
                services.AddTransient<DashboardPage>();
                services.AddTransient<ProcessListPage>();
                services.AddTransient<SettingsPage>();
                services.AddTransient<PaywallPage>();
            })
            .Build();

        // Handle unhandled exceptions
        UnhandledException += OnUnhandledException;
    }

    /// <summary>
    /// Handles application launch.
    /// </summary>
    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Initialize billing service
        var billingService = Services.GetRequiredService<IBillingService>();
        await billingService.InitializeAsync();

        // Start trial if first launch
        var entitlementManager = Services.GetRequiredService<IEntitlementManager>();
        if (billingService.CurrentSubscription.Status == SubscriptionStatus.None)
        {
            await billingService.StartTrialAsync();
        }

        // Create and activate main window
        _mainWindow = Services.GetRequiredService<MainWindow>();

        // Configure window
        if (_mainWindow is WindowEx windowEx)
        {
            windowEx.MinWidth = 900;
            windowEx.MinHeight = 600;
            windowEx.Title = "Craig-O-Clean";

            // Set window icon
            try
            {
                var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "craig-o-clean.ico");
                if (File.Exists(iconPath))
                {
                    windowEx.SetIcon(iconPath);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to set window icon: {ex.Message}");
            }
        }

        // Check if should start minimized
        if (Settings.StartMinimizedToTray)
        {
            var trayService = Services.GetRequiredService<ITrayService>();
            trayService.Initialize();
            trayService.Show();
        }
        else
        {
            _mainWindow.Activate();
        }

        // Start system metrics monitoring
        var metricsService = Services.GetRequiredService<ISystemMetricsService>();
        metricsService.StartMonitoring(Settings.RefreshIntervalMs);
    }

    /// <summary>
    /// Gets a service of the specified type.
    /// </summary>
    public static T GetService<T>() where T : class
    {
        return Current.Services.GetRequiredService<T>();
    }

    /// <summary>
    /// Handles unhandled exceptions.
    /// </summary>
    private void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        Debug.WriteLine($"Unhandled exception: {e.Exception}");
        e.Handled = true;

        // Log to file for troubleshooting
        try
        {
            var logDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CraigOClean",
                "Logs");

            if (!Directory.Exists(logDir))
            {
                Directory.CreateDirectory(logDir);
            }

            var logFile = Path.Combine(logDir, $"crash_{DateTime.Now:yyyyMMdd_HHmmss}.log");
            File.WriteAllText(logFile, $"Unhandled Exception:\n{e.Exception}");
        }
        catch
        {
            // Ignore logging errors
        }
    }

    /// <summary>
    /// Shows the main window.
    /// </summary>
    public void ShowMainWindow()
    {
        if (_mainWindow != null)
        {
            _mainWindow.Activate();
            if (_mainWindow is WindowEx windowEx)
            {
                windowEx.BringToFront();
            }
        }
    }

    /// <summary>
    /// Exits the application.
    /// </summary>
    public void ExitApplication()
    {
        // Stop monitoring
        var metricsService = Services.GetRequiredService<ISystemMetricsService>();
        metricsService.StopMonitoring();
        metricsService.Dispose();

        // Hide tray
        var trayService = Services.GetRequiredService<ITrayService>();
        trayService.Hide();
        trayService.Dispose();

        // Save settings
        Settings.Save();

        // Exit
        Exit();
    }
}
