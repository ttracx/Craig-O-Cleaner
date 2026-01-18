// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service interface for cleanup operations.
/// </summary>
public interface ICleanupService
{
    /// <summary>
    /// Scans for cleanable files and applications.
    /// </summary>
    Task<CleanupInfo> ScanAsync(IProgress<string>? progress = null);

    /// <summary>
    /// Performs cleanup of specified types.
    /// </summary>
    Task<CleanupResult> CleanupAsync(CleanupType type, IProgress<string>? progress = null);

    /// <summary>
    /// Gets heavy applications using significant resources.
    /// </summary>
    Task<IReadOnlyList<HeavyApplication>> GetHeavyApplicationsAsync(int minMemoryMb = 500);

    /// <summary>
    /// Opens Windows Disk Cleanup utility.
    /// </summary>
    Task OpenDiskCleanupAsync();

    /// <summary>
    /// Opens Windows Storage Settings.
    /// </summary>
    Task OpenStorageSettingsAsync();

    /// <summary>
    /// Opens Windows Apps & Features.
    /// </summary>
    Task OpenAppsSettingsAsync();
}
