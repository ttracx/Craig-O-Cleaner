// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using System.Diagnostics;
using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service for performing cleanup operations.
/// </summary>
public sealed class CleanupService : ICleanupService
{
    private readonly IProcessService _processService;

    /// <summary>
    /// Directories to scan for temporary files.
    /// </summary>
    private static readonly string[] TempDirectories =
    [
        Path.GetTempPath(),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Temp"),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Temp")
    ];

    /// <summary>
    /// App data directory for Craig-O-Clean logs.
    /// </summary>
    private static readonly string AppLogDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CraigOClean",
        "Logs");

    /// <summary>
    /// App cache directory.
    /// </summary>
    private static readonly string AppCacheDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CraigOClean",
        "Cache");

    /// <summary>
    /// Initializes a new instance of CleanupService.
    /// </summary>
    public CleanupService(IProcessService processService)
    {
        _processService = processService;
    }

    /// <inheritdoc/>
    public async Task<CleanupInfo> ScanAsync(IProgress<string>? progress = null)
    {
        return await Task.Run(async () =>
        {
            var info = new CleanupInfo();

            // Scan temp directories
            progress?.Report("Scanning temporary files...");
            foreach (var dir in TempDirectories)
            {
                if (Directory.Exists(dir))
                {
                    var (count, size) = ScanDirectory(dir, TimeSpan.FromDays(7));
                    info.TempFilesCount += count;
                    info.TempFilesSize += size;
                }
            }

            // Scan app log files
            progress?.Report("Scanning log files...");
            if (Directory.Exists(AppLogDirectory))
            {
                var (count, size) = ScanDirectory(AppLogDirectory, TimeSpan.FromDays(30));
                info.LogFilesCount = count;
                info.LogFilesSize = size;
            }

            // Scan app cache
            progress?.Report("Scanning cache files...");
            if (Directory.Exists(AppCacheDirectory))
            {
                var (count, size) = ScanDirectory(AppCacheDirectory, TimeSpan.FromDays(7));
                info.CacheFilesCount = count;
                info.CacheFilesSize = size;
            }

            // Get heavy applications
            progress?.Report("Analyzing running applications...");
            info.HeavyApplications = (await GetHeavyApplicationsAsync()).ToList();

            return info;
        });
    }

    /// <inheritdoc/>
    public async Task<CleanupResult> CleanupAsync(CleanupType type, IProgress<string>? progress = null)
    {
        return await Task.Run(() =>
        {
            var result = new CleanupResult { Success = true };

            try
            {
                if (type == CleanupType.TempFiles || type == CleanupType.All)
                {
                    progress?.Report("Cleaning temporary files...");
                    foreach (var dir in TempDirectories)
                    {
                        if (Directory.Exists(dir))
                        {
                            var (deleted, freed, errors) = CleanDirectory(dir, TimeSpan.FromDays(7));
                            result.FilesDeleted += deleted;
                            result.BytesFreed += freed;
                            result.Errors.AddRange(errors);
                        }
                    }
                }

                if (type == CleanupType.LogFiles || type == CleanupType.All)
                {
                    progress?.Report("Cleaning log files...");
                    if (Directory.Exists(AppLogDirectory))
                    {
                        var (deleted, freed, errors) = CleanDirectory(AppLogDirectory, TimeSpan.FromDays(30));
                        result.FilesDeleted += deleted;
                        result.BytesFreed += freed;
                        result.Errors.AddRange(errors);
                    }
                }

                if (type == CleanupType.CacheFiles || type == CleanupType.All)
                {
                    progress?.Report("Cleaning cache files...");
                    if (Directory.Exists(AppCacheDirectory))
                    {
                        var (deleted, freed, errors) = CleanDirectory(AppCacheDirectory, TimeSpan.FromDays(7));
                        result.FilesDeleted += deleted;
                        result.BytesFreed += freed;
                        result.Errors.AddRange(errors);
                    }
                }
            }
            catch (Exception ex)
            {
                result.Errors.Add($"Cleanup failed: {ex.Message}");
                result.Success = result.FilesDeleted > 0;
            }

            return result;
        });
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<HeavyApplication>> GetHeavyApplicationsAsync(int minMemoryMb = 500)
    {
        var processes = await _processService.GetProcessesAsync();
        var minMemoryBytes = minMemoryMb * 1024L * 1024L;

        return processes
            .Where(p => p.HasMainWindow &&
                       !p.IsSystemProcess &&
                       !p.IsProtected &&
                       p.WorkingSetBytes >= minMemoryBytes)
            .OrderByDescending(p => p.WorkingSetBytes)
            .Select(p => new HeavyApplication
            {
                ProcessId = p.ProcessId,
                Name = p.Name,
                MemoryUsage = p.WorkingSetBytes,
                CpuUsage = p.CpuUsagePercent,
                WindowTitle = p.MainWindowTitle,
                MayHaveUnsavedWork = MayHaveUnsavedWork(p)
            })
            .ToList();
    }

    /// <inheritdoc/>
    public async Task OpenDiskCleanupAsync()
    {
        await Task.Run(() =>
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "cleanmgr.exe",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to open Disk Cleanup: {ex.Message}");
            }
        });
    }

    /// <inheritdoc/>
    public async Task OpenStorageSettingsAsync()
    {
        await Task.Run(() =>
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "ms-settings:storagesense",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to open Storage Settings: {ex.Message}");
            }
        });
    }

    /// <inheritdoc/>
    public async Task OpenAppsSettingsAsync()
    {
        await Task.Run(() =>
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "ms-settings:appsfeatures",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to open Apps Settings: {ex.Message}");
            }
        });
    }

    private static (int Count, long Size) ScanDirectory(string path, TimeSpan maxAge)
    {
        int count = 0;
        long size = 0;
        var cutoff = DateTime.UtcNow - maxAge;

        try
        {
            var files = Directory.EnumerateFiles(path, "*", new EnumerationOptions
            {
                IgnoreInaccessible = true,
                RecurseSubdirectories = true
            });

            foreach (var file in files)
            {
                try
                {
                    var info = new FileInfo(file);
                    if (info.LastAccessTimeUtc < cutoff)
                    {
                        count++;
                        size += info.Length;
                    }
                }
                catch
                {
                    // Skip files we can't access
                }
            }
        }
        catch
        {
            // Ignore directory access errors
        }

        return (count, size);
    }

    private static (int Deleted, long Freed, List<string> Errors) CleanDirectory(string path, TimeSpan maxAge)
    {
        int deleted = 0;
        long freed = 0;
        var errors = new List<string>();
        var cutoff = DateTime.UtcNow - maxAge;

        try
        {
            var files = Directory.EnumerateFiles(path, "*", new EnumerationOptions
            {
                IgnoreInaccessible = true,
                RecurseSubdirectories = true
            });

            foreach (var file in files)
            {
                try
                {
                    var info = new FileInfo(file);
                    if (info.LastAccessTimeUtc < cutoff)
                    {
                        var length = info.Length;
                        info.Delete();
                        deleted++;
                        freed += length;
                    }
                }
                catch (Exception ex)
                {
                    errors.Add($"Could not delete {Path.GetFileName(file)}: {ex.Message}");
                }
            }

            // Try to remove empty directories
            try
            {
                foreach (var dir in Directory.EnumerateDirectories(path, "*", SearchOption.AllDirectories)
                    .OrderByDescending(d => d.Length))
                {
                    try
                    {
                        if (!Directory.EnumerateFileSystemEntries(dir).Any())
                        {
                            Directory.Delete(dir);
                        }
                    }
                    catch
                    {
                        // Ignore
                    }
                }
            }
            catch
            {
                // Ignore
            }
        }
        catch (Exception ex)
        {
            errors.Add($"Error accessing directory: {ex.Message}");
        }

        return (deleted, freed, errors);
    }

    private static bool MayHaveUnsavedWork(ProcessInfo process)
    {
        // Check for common indicators of unsaved work
        if (string.IsNullOrEmpty(process.MainWindowTitle))
            return false;

        var title = process.MainWindowTitle.ToLowerInvariant();

        // Common patterns indicating unsaved changes
        return title.Contains("*") ||
               title.Contains("unsaved") ||
               title.Contains("modified") ||
               title.Contains("untitled");
    }
}
