// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service interface for system tray functionality.
/// </summary>
public interface ITrayService : IDisposable
{
    /// <summary>
    /// Event raised when the tray icon is clicked.
    /// </summary>
    event EventHandler? TrayIconClicked;

    /// <summary>
    /// Event raised when "Open" is selected from tray menu.
    /// </summary>
    event EventHandler? OpenRequested;

    /// <summary>
    /// Event raised when "Exit" is selected from tray menu.
    /// </summary>
    event EventHandler? ExitRequested;

    /// <summary>
    /// Event raised when "End Top Hog" is selected from tray menu.
    /// </summary>
    event EventHandler<ProcessInfo?>? EndTopHogRequested;

    /// <summary>
    /// Initializes the tray icon.
    /// </summary>
    void Initialize();

    /// <summary>
    /// Shows a balloon notification.
    /// </summary>
    void ShowNotification(string title, string message, bool isWarning = false);

    /// <summary>
    /// Updates the tray tooltip with current metrics.
    /// </summary>
    void UpdateTooltip(SystemMetrics metrics, ProcessInfo? topCpu, ProcessInfo? topMemory);

    /// <summary>
    /// Shows the tray icon.
    /// </summary>
    void Show();

    /// <summary>
    /// Hides the tray icon.
    /// </summary>
    void Hide();

    /// <summary>
    /// Gets whether the tray icon is visible.
    /// </summary>
    bool IsVisible { get; }
}
