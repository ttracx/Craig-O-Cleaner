// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.Security.Principal;
using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service for managing system processes.
/// </summary>
public sealed class ProcessService : IProcessService
{
    /// <summary>
    /// List of protected system processes that cannot be terminated.
    /// </summary>
    private static readonly HashSet<string> ProtectedProcessNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "System",
        "Idle",
        "Registry",
        "smss",
        "csrss",
        "wininit",
        "services",
        "lsass",
        "lsaiso",
        "svchost",
        "fontdrvhost",
        "dwm",
        "Memory Compression",
        "WmiPrvSE",
        "SecurityHealthService",
        "MsMpEng",
        "NisSrv",
        "spoolsv",
        "winlogon",
        "LogonUI",
        "sihost",
        "conhost",
        "RuntimeBroker",
        "SearchIndexer",
        "StartMenuExperienceHost",
        "ShellExperienceHost",
        "TextInputHost",
        "ctfmon",
        "SystemSettings",
        "SettingsHelper"
    };

    private readonly Dictionary<int, PerformanceCounter> _cpuCounters = new();
    private readonly Dictionary<int, DateTime> _lastCpuTime = new();
    private readonly Dictionary<int, TimeSpan> _lastTotalProcessorTime = new();
    private readonly object _counterLock = new();

    /// <inheritdoc/>
    public async Task<IReadOnlyList<ProcessInfo>> GetProcessesAsync()
    {
        return await Task.Run(() =>
        {
            var processes = Process.GetProcesses();
            var processInfos = new List<ProcessInfo>(processes.Length);
            var processorCount = Environment.ProcessorCount;

            foreach (var process in processes)
            {
                try
                {
                    var info = CreateProcessInfo(process, processorCount);
                    if (info != null)
                    {
                        processInfos.Add(info);
                    }
                }
                catch
                {
                    // Skip processes we can't access
                }
                finally
                {
                    process.Dispose();
                }
            }

            return processInfos.OrderByDescending(p => p.WorkingSetBytes).ToList();
        });
    }

    /// <inheritdoc/>
    public async Task<ProcessInfo?> GetProcessAsync(int processId)
    {
        return await Task.Run(() =>
        {
            try
            {
                using var process = Process.GetProcessById(processId);
                return CreateProcessInfo(process, Environment.ProcessorCount);
            }
            catch
            {
                return null;
            }
        });
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<ProcessInfo>> GetTopCpuProcessesAsync(int count = 5)
    {
        var processes = await GetProcessesAsync();
        return processes
            .Where(p => !p.IsSystemProcess && !p.IsProtected)
            .OrderByDescending(p => p.CpuUsagePercent)
            .Take(count)
            .ToList();
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<ProcessInfo>> GetTopMemoryProcessesAsync(int count = 5)
    {
        var processes = await GetProcessesAsync();
        return processes
            .Where(p => !p.IsSystemProcess && !p.IsProtected)
            .OrderByDescending(p => p.WorkingSetBytes)
            .Take(count)
            .ToList();
    }

    /// <inheritdoc/>
    public async Task<ProcessTerminationResult> EndTaskAsync(int processId)
    {
        return await Task.Run(() =>
        {
            try
            {
                using var process = Process.GetProcessById(processId);

                if (IsProtectedProcess(process.ProcessName))
                {
                    return ProcessTerminationResult.Failed(
                        $"'{process.ProcessName}' is a protected system process and cannot be terminated.");
                }

                // Try graceful close if it has a main window
                if (process.MainWindowHandle != IntPtr.Zero)
                {
                    if (process.CloseMainWindow())
                    {
                        // Wait up to 5 seconds for graceful close
                        if (process.WaitForExit(5000))
                        {
                            return ProcessTerminationResult.Succeeded(false);
                        }
                    }

                    // Graceful close didn't work, fall through to kill
                    process.Kill();
                    process.WaitForExit(3000);
                    return ProcessTerminationResult.Succeeded(true);
                }
                else
                {
                    // No window, just terminate
                    process.Kill();
                    process.WaitForExit(3000);
                    return ProcessTerminationResult.Succeeded(true);
                }
            }
            catch (ArgumentException)
            {
                return ProcessTerminationResult.Failed("Process no longer exists.");
            }
            catch (InvalidOperationException ex)
            {
                return ProcessTerminationResult.Failed($"Cannot terminate process: {ex.Message}");
            }
            catch (System.ComponentModel.Win32Exception ex)
            {
                return ProcessTerminationResult.Failed($"Access denied: {ex.Message}");
            }
            catch (Exception ex)
            {
                return ProcessTerminationResult.Failed($"Failed to terminate process: {ex.Message}");
            }
        });
    }

    /// <inheritdoc/>
    public async Task<ProcessTerminationResult> ForceKillAsync(int processId)
    {
        return await Task.Run(() =>
        {
            try
            {
                using var process = Process.GetProcessById(processId);

                if (IsProtectedProcess(process.ProcessName))
                {
                    return ProcessTerminationResult.Failed(
                        $"'{process.ProcessName}' is a protected system process and cannot be terminated.");
                }

                // Use TerminateProcess via P/Invoke for more forceful termination
                var handle = OpenProcess(PROCESS_TERMINATE, false, (uint)processId);
                if (handle == IntPtr.Zero)
                {
                    var error = Marshal.GetLastWin32Error();
                    return ProcessTerminationResult.Failed($"Cannot open process for termination. Error code: {error}");
                }

                try
                {
                    if (!TerminateProcess(handle, 1))
                    {
                        var error = Marshal.GetLastWin32Error();
                        return ProcessTerminationResult.Failed($"TerminateProcess failed. Error code: {error}");
                    }

                    return ProcessTerminationResult.Succeeded(true);
                }
                finally
                {
                    CloseHandle(handle);
                }
            }
            catch (ArgumentException)
            {
                return ProcessTerminationResult.Failed("Process no longer exists.");
            }
            catch (Exception ex)
            {
                return ProcessTerminationResult.Failed($"Failed to force kill process: {ex.Message}");
            }
        });
    }

    /// <inheritdoc/>
    public bool IsProtectedProcess(int processId)
    {
        try
        {
            using var process = Process.GetProcessById(processId);
            return IsProtectedProcess(process.ProcessName);
        }
        catch
        {
            return true; // Err on the side of caution
        }
    }

    /// <inheritdoc/>
    public bool IsProtectedProcess(string processName)
    {
        return ProtectedProcessNames.Contains(processName);
    }

    private ProcessInfo? CreateProcessInfo(Process process, int processorCount)
    {
        try
        {
            var info = new ProcessInfo
            {
                ProcessId = process.Id,
                Name = process.ProcessName,
                IsProtected = IsProtectedProcess(process.ProcessName)
            };

            // Get basic info that's always available
            try
            {
                info.ThreadCount = process.Threads.Count;
            }
            catch { }

            try
            {
                info.HandleCount = process.HandleCount;
            }
            catch { }

            // Try to get extended info
            try
            {
                info.WorkingSetBytes = process.WorkingSet64;
            }
            catch { }

            try
            {
                info.PrivateMemoryBytes = process.PrivateMemorySize64;
            }
            catch { }

            try
            {
                info.HasMainWindow = process.MainWindowHandle != IntPtr.Zero;
                info.MainWindowTitle = process.MainWindowTitle;
            }
            catch { }

            try
            {
                info.StartTime = process.StartTime;
            }
            catch { }

            try
            {
                info.PriorityClass = process.PriorityClass.ToString();
            }
            catch { }

            // Calculate CPU usage
            try
            {
                info.CpuUsagePercent = CalculateCpuUsage(process, processorCount);
            }
            catch { }

            // Try to get path and file info
            try
            {
                info.ExecutablePath = process.MainModule?.FileName;
                if (!string.IsNullOrEmpty(info.ExecutablePath))
                {
                    var versionInfo = FileVersionInfo.GetVersionInfo(info.ExecutablePath);
                    info.Description = versionInfo.FileDescription;
                    info.Publisher = versionInfo.CompanyName;
                }
            }
            catch { }

            // Determine if system process
            info.IsSystemProcess = IsSystemProcess(process);

            // Try to get username
            try
            {
                info.UserName = GetProcessOwner(process.Id);
            }
            catch { }

            return info;
        }
        catch
        {
            return null;
        }
    }

    private double CalculateCpuUsage(Process process, int processorCount)
    {
        lock (_counterLock)
        {
            var now = DateTime.UtcNow;
            TimeSpan currentTotalTime;

            try
            {
                currentTotalTime = process.TotalProcessorTime;
            }
            catch
            {
                return 0;
            }

            if (_lastCpuTime.TryGetValue(process.Id, out var lastTime) &&
                _lastTotalProcessorTime.TryGetValue(process.Id, out var lastTotalTime))
            {
                var elapsedTime = (now - lastTime).TotalMilliseconds;
                if (elapsedTime > 0)
                {
                    var cpuTime = (currentTotalTime - lastTotalTime).TotalMilliseconds;
                    var cpuUsage = (cpuTime / (elapsedTime * processorCount)) * 100;

                    _lastCpuTime[process.Id] = now;
                    _lastTotalProcessorTime[process.Id] = currentTotalTime;

                    return Math.Round(Math.Min(100, Math.Max(0, cpuUsage)), 1);
                }
            }

            _lastCpuTime[process.Id] = now;
            _lastTotalProcessorTime[process.Id] = currentTotalTime;
            return 0;
        }
    }

    private static bool IsSystemProcess(Process process)
    {
        try
        {
            // Check if running under SYSTEM account
            var owner = GetProcessOwner(process.Id);
            if (string.IsNullOrEmpty(owner)) return true;

            return owner.Contains("SYSTEM", StringComparison.OrdinalIgnoreCase) ||
                   owner.Contains("LOCAL SERVICE", StringComparison.OrdinalIgnoreCase) ||
                   owner.Contains("NETWORK SERVICE", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return ProtectedProcessNames.Contains(process.ProcessName);
        }
    }

    private static string? GetProcessOwner(int processId)
    {
        try
        {
            var query = $"SELECT * FROM Win32_Process WHERE ProcessId = {processId}";
            using var searcher = new ManagementObjectSearcher(query);
            using var collection = searcher.Get();

            foreach (ManagementObject item in collection)
            {
                var ownerInfo = new string[2];
                var result = (uint)item.InvokeMethod("GetOwner", ownerInfo);
                if (result == 0 && ownerInfo[0] != null)
                {
                    return $"{ownerInfo[1]}\\{ownerInfo[0]}";
                }
            }
        }
        catch
        {
            // Ignore WMI errors
        }

        return null;
    }

    #region Native Interop

    private const uint PROCESS_TERMINATE = 0x0001;

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool TerminateProcess(IntPtr hProcess, uint uExitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr hObject);

    #endregion
}
