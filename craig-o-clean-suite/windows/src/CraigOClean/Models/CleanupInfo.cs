// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

namespace CraigOClean.Models;

/// <summary>
/// Represents information about cleanable items.
/// </summary>
public sealed class CleanupInfo
{
    /// <summary>
    /// Gets or sets the total size of temporary files in bytes.
    /// </summary>
    public long TempFilesSize { get; set; }

    /// <summary>
    /// Gets or sets the number of temporary files.
    /// </summary>
    public int TempFilesCount { get; set; }

    /// <summary>
    /// Gets or sets the total size of application logs in bytes.
    /// </summary>
    public long LogFilesSize { get; set; }

    /// <summary>
    /// Gets or sets the number of log files.
    /// </summary>
    public int LogFilesCount { get; set; }

    /// <summary>
    /// Gets or sets the total size of cache files in bytes.
    /// </summary>
    public long CacheFilesSize { get; set; }

    /// <summary>
    /// Gets or sets the number of cache files.
    /// </summary>
    public int CacheFilesCount { get; set; }

    /// <summary>
    /// Gets or sets the list of heavy applications that could be closed.
    /// </summary>
    public List<HeavyApplication> HeavyApplications { get; set; } = [];

    /// <summary>
    /// Gets the total cleanable size in bytes.
    /// </summary>
    public long TotalCleanableSize => TempFilesSize + LogFilesSize + CacheFilesSize;

    /// <summary>
    /// Gets the total cleanable file count.
    /// </summary>
    public int TotalCleanableCount => TempFilesCount + LogFilesCount + CacheFilesCount;

    /// <summary>
    /// Gets the formatted total cleanable size.
    /// </summary>
    public string FormattedTotalSize => FormatBytes(TotalCleanableSize);

    /// <summary>
    /// Formats bytes into a human-readable string.
    /// </summary>
    private static string FormatBytes(long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB", "TB"];
        int order = 0;
        double size = bytes;

        while (size >= 1024 && order < sizes.Length - 1)
        {
            order++;
            size /= 1024;
        }

        return $"{size:0.##} {sizes[order]}";
    }
}

/// <summary>
/// Represents an application using significant resources.
/// </summary>
public sealed class HeavyApplication
{
    /// <summary>
    /// Gets or sets the process ID.
    /// </summary>
    public int ProcessId { get; set; }

    /// <summary>
    /// Gets or sets the application name.
    /// </summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the memory usage in bytes.
    /// </summary>
    public long MemoryUsage { get; set; }

    /// <summary>
    /// Gets or sets the CPU usage percentage.
    /// </summary>
    public double CpuUsage { get; set; }

    /// <summary>
    /// Gets or sets whether the app has unsaved work (if detectable).
    /// </summary>
    public bool MayHaveUnsavedWork { get; set; }

    /// <summary>
    /// Gets or sets the main window title.
    /// </summary>
    public string? WindowTitle { get; set; }

    /// <summary>
    /// Gets the formatted memory usage.
    /// </summary>
    public string FormattedMemory => FormatBytes(MemoryUsage);

    /// <summary>
    /// Formats bytes into a human-readable string.
    /// </summary>
    private static string FormatBytes(long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB", "TB"];
        int order = 0;
        double size = bytes;

        while (size >= 1024 && order < sizes.Length - 1)
        {
            order++;
            size /= 1024;
        }

        return $"{size:0.##} {sizes[order]}";
    }
}

/// <summary>
/// Represents the result of a cleanup operation.
/// </summary>
public sealed class CleanupResult
{
    /// <summary>
    /// Gets or sets whether the cleanup was successful.
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// Gets or sets the number of files deleted.
    /// </summary>
    public int FilesDeleted { get; set; }

    /// <summary>
    /// Gets or sets the total bytes freed.
    /// </summary>
    public long BytesFreed { get; set; }

    /// <summary>
    /// Gets or sets any errors that occurred.
    /// </summary>
    public List<string> Errors { get; set; } = [];

    /// <summary>
    /// Gets the formatted bytes freed.
    /// </summary>
    public string FormattedBytesFreed => FormatBytes(BytesFreed);

    /// <summary>
    /// Formats bytes into a human-readable string.
    /// </summary>
    private static string FormatBytes(long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB", "TB"];
        int order = 0;
        double size = bytes;

        while (size >= 1024 && order < sizes.Length - 1)
        {
            order++;
            size /= 1024;
        }

        return $"{size:0.##} {sizes[order]}";
    }
}

/// <summary>
/// Types of cleanup operations available.
/// </summary>
public enum CleanupType
{
    /// <summary>
    /// Clean temporary files.
    /// </summary>
    TempFiles,

    /// <summary>
    /// Clean log files.
    /// </summary>
    LogFiles,

    /// <summary>
    /// Clean cache files.
    /// </summary>
    CacheFiles,

    /// <summary>
    /// All cleanup types.
    /// </summary>
    All
}
