// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using System.Text.Json;

namespace CraigOClean.Models;

/// <summary>
/// Application settings that persist across sessions.
/// </summary>
public sealed class AppSettings
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CraigOClean",
        "settings.json");

    /// <summary>
    /// Gets or sets whether to start with Windows.
    /// </summary>
    public bool StartWithWindows { get; set; }

    /// <summary>
    /// Gets or sets whether to start minimized to tray.
    /// </summary>
    public bool StartMinimizedToTray { get; set; }

    /// <summary>
    /// Gets or sets whether to show system tray notifications.
    /// </summary>
    public bool ShowTrayNotifications { get; set; } = true;

    /// <summary>
    /// Gets or sets the memory warning threshold percentage.
    /// </summary>
    public int MemoryWarningThreshold { get; set; } = 80;

    /// <summary>
    /// Gets or sets the CPU warning threshold percentage.
    /// </summary>
    public int CpuWarningThreshold { get; set; } = 90;

    /// <summary>
    /// Gets or sets the metrics refresh interval in milliseconds.
    /// </summary>
    public int RefreshIntervalMs { get; set; } = 2000;

    /// <summary>
    /// Gets or sets the app theme (0=System, 1=Light, 2=Dark).
    /// </summary>
    public int Theme { get; set; }

    /// <summary>
    /// Gets or sets whether to show process descriptions.
    /// </summary>
    public bool ShowProcessDescriptions { get; set; } = true;

    /// <summary>
    /// Gets or sets whether to confirm before terminating processes.
    /// </summary>
    public bool ConfirmProcessTermination { get; set; } = true;

    /// <summary>
    /// Gets or sets whether to minimize to tray on close.
    /// </summary>
    public bool MinimizeToTrayOnClose { get; set; } = true;

    /// <summary>
    /// Gets or sets the Stripe API key for direct billing (if applicable).
    /// </summary>
    public string? StripePublishableKey { get; set; }

    /// <summary>
    /// Gets or sets the last known subscription state for offline access.
    /// </summary>
    public SubscriptionInfo? CachedSubscription { get; set; }

    /// <summary>
    /// Loads settings from disk.
    /// </summary>
    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var json = File.ReadAllText(SettingsPath);
                return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            }
        }
        catch
        {
            // Ignore errors, return defaults
        }

        return new AppSettings();
    }

    /// <summary>
    /// Saves settings to disk.
    /// </summary>
    public void Save()
    {
        try
        {
            var directory = Path.GetDirectoryName(SettingsPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions
            {
                WriteIndented = true
            });
            File.WriteAllText(SettingsPath, json);
        }
        catch
        {
            // Ignore save errors
        }
    }
}
