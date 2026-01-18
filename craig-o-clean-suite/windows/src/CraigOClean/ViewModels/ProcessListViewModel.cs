// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CraigOClean.Models;
using CraigOClean.Services;
using System.Collections.ObjectModel;
using System.Diagnostics;

namespace CraigOClean.ViewModels;

/// <summary>
/// ViewModel for the Process List page.
/// </summary>
public sealed partial class ProcessListViewModel : ObservableObject
{
    private readonly IProcessService _processService;
    private readonly IProcessManagerService _processManager;
    private readonly IEntitlementManager _entitlementManager;
    private readonly AppSettings _settings;
    private List<ProcessInfo> _allProcesses = [];

    [ObservableProperty]
    private ObservableCollection<ProcessInfo> _processes = [];

    [ObservableProperty]
    private ProcessInfo? _selectedProcess;

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _isRefreshing;

    [ObservableProperty]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private string _sortBy = "Memory";

    [ObservableProperty]
    private bool _sortDescending = true;

    [ObservableProperty]
    private bool _showSystemProcesses;

    [ObservableProperty]
    private int _totalProcessCount;

    [ObservableProperty]
    private int _filteredProcessCount;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _hasPremiumAccess;

    [ObservableProperty]
    private bool _canTerminateProcesses;

    /// <summary>
    /// Available sort options.
    /// </summary>
    public List<string> SortOptions { get; } = ["Name", "CPU", "Memory", "PID"];

    /// <summary>
    /// Initializes a new instance of ProcessListViewModel.
    /// </summary>
    public ProcessListViewModel(
        IProcessService processService,
        IProcessManagerService processManager,
        IEntitlementManager entitlementManager,
        AppSettings settings)
    {
        _processService = processService;
        _processManager = processManager;
        _entitlementManager = entitlementManager;
        _settings = settings;

        HasPremiumAccess = _entitlementManager.HasPremiumAccess;
        CanTerminateProcesses = _entitlementManager.CanTerminateProcesses;
    }

    /// <summary>
    /// Loads the process list.
    /// </summary>
    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;
        StatusMessage = "Loading processes...";

        try
        {
            _allProcesses = (await _processService.GetProcessesAsync()).ToList();
            TotalProcessCount = _allProcesses.Count;

            ApplyFiltersAndSort();
            StatusMessage = $"Loaded {TotalProcessCount} processes";
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error loading processes: {ex.Message}");
            StatusMessage = "Failed to load processes";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Refreshes the process list.
    /// </summary>
    [RelayCommand]
    private async Task RefreshAsync()
    {
        IsRefreshing = true;

        try
        {
            _allProcesses = (await _processService.GetProcessesAsync()).ToList();
            TotalProcessCount = _allProcesses.Count;
            ApplyFiltersAndSort();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error refreshing processes: {ex.Message}");
        }
        finally
        {
            IsRefreshing = false;
        }
    }

    /// <summary>
    /// Handles search text changes.
    /// </summary>
    partial void OnSearchTextChanged(string value)
    {
        ApplyFiltersAndSort();
    }

    /// <summary>
    /// Handles sort by changes.
    /// </summary>
    partial void OnSortByChanged(string value)
    {
        ApplyFiltersAndSort();
    }

    /// <summary>
    /// Handles sort direction changes.
    /// </summary>
    partial void OnSortDescendingChanged(bool value)
    {
        ApplyFiltersAndSort();
    }

    /// <summary>
    /// Handles show system processes changes.
    /// </summary>
    partial void OnShowSystemProcessesChanged(bool value)
    {
        ApplyFiltersAndSort();
    }

    /// <summary>
    /// Applies filters and sorting to the process list.
    /// </summary>
    private void ApplyFiltersAndSort()
    {
        var filtered = _allProcesses.AsEnumerable();

        // Filter by search text
        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var search = SearchText.ToLowerInvariant();
            filtered = filtered.Where(p =>
                p.Name.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (p.Description?.Contains(search, StringComparison.OrdinalIgnoreCase) ?? false) ||
                (p.MainWindowTitle?.Contains(search, StringComparison.OrdinalIgnoreCase) ?? false) ||
                p.ProcessId.ToString().Contains(search));
        }

        // Filter system processes
        if (!ShowSystemProcesses)
        {
            filtered = filtered.Where(p => !p.IsSystemProcess && !p.IsProtected);
        }

        // Apply sorting
        filtered = SortBy switch
        {
            "Name" => SortDescending
                ? filtered.OrderByDescending(p => p.Name)
                : filtered.OrderBy(p => p.Name),
            "CPU" => SortDescending
                ? filtered.OrderByDescending(p => p.CpuUsagePercent)
                : filtered.OrderBy(p => p.CpuUsagePercent),
            "Memory" => SortDescending
                ? filtered.OrderByDescending(p => p.WorkingSetBytes)
                : filtered.OrderBy(p => p.WorkingSetBytes),
            "PID" => SortDescending
                ? filtered.OrderByDescending(p => p.ProcessId)
                : filtered.OrderBy(p => p.ProcessId),
            _ => filtered.OrderByDescending(p => p.WorkingSetBytes)
        };

        var list = filtered.ToList();
        FilteredProcessCount = list.Count;

        Processes.Clear();
        foreach (var process in list)
        {
            Processes.Add(process);
        }
    }

    /// <summary>
    /// Ends a process gracefully.
    /// </summary>
    [RelayCommand]
    private async Task EndTaskAsync(ProcessInfo? process)
    {
        if (process == null)
            return;

        if (!CanTerminateProcesses)
        {
            StatusMessage = "Upgrade to Pro to terminate processes";
            return;
        }

        if (process.IsProtected)
        {
            StatusMessage = $"Cannot terminate protected process: {process.Name}";
            return;
        }

        if (_settings.ConfirmProcessTermination)
        {
            // In production, this would show a confirmation dialog
            // For now, we proceed with the termination
        }

        IsLoading = true;
        StatusMessage = $"Terminating {process.Name}...";

        try
        {
            var result = await _processManager.EndTaskAsync(process.ProcessId);

            if (result.Success)
            {
                StatusMessage = result.WasForceKilled
                    ? $"Force killed {process.Name}"
                    : $"Terminated {process.Name}";

                // Remove from list
                _allProcesses.RemoveAll(p => p.ProcessId == process.ProcessId);
                Processes.Remove(process);
                TotalProcessCount = _allProcesses.Count;
                FilteredProcessCount = Processes.Count;
            }
            else
            {
                StatusMessage = result.ErrorMessage ?? $"Failed to terminate {process.Name}";
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error terminating process: {ex.Message}");
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Force kills a process.
    /// </summary>
    [RelayCommand]
    private async Task ForceKillAsync(ProcessInfo? process)
    {
        if (process == null)
            return;

        if (!CanTerminateProcesses)
        {
            StatusMessage = "Upgrade to Pro to terminate processes";
            return;
        }

        if (process.IsProtected)
        {
            StatusMessage = $"Cannot terminate protected process: {process.Name}";
            return;
        }

        IsLoading = true;
        StatusMessage = $"Force killing {process.Name}...";

        try
        {
            var result = await _processManager.ForceKillAsync(process.ProcessId);

            if (result.Success)
            {
                StatusMessage = $"Force killed {process.Name}";

                _allProcesses.RemoveAll(p => p.ProcessId == process.ProcessId);
                Processes.Remove(process);
                TotalProcessCount = _allProcesses.Count;
                FilteredProcessCount = Processes.Count;
            }
            else
            {
                StatusMessage = result.ErrorMessage ?? $"Failed to force kill {process.Name}";
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error force killing process: {ex.Message}");
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Opens the file location of the selected process.
    /// </summary>
    [RelayCommand]
    private void OpenFileLocation(ProcessInfo? process)
    {
        if (process?.ExecutablePath == null)
            return;

        try
        {
            var directory = Path.GetDirectoryName(process.ExecutablePath);
            if (directory != null && Directory.Exists(directory))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = $"/select,\"{process.ExecutablePath}\"",
                    UseShellExecute = true
                });
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening file location: {ex.Message}");
            StatusMessage = "Failed to open file location";
        }
    }

    /// <summary>
    /// Searches online for process information.
    /// </summary>
    [RelayCommand]
    private void SearchOnline(ProcessInfo? process)
    {
        if (process == null)
            return;

        try
        {
            var searchQuery = Uri.EscapeDataString($"{process.Name} process Windows");
            Process.Start(new ProcessStartInfo
            {
                FileName = $"https://www.bing.com/search?q={searchQuery}",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening search: {ex.Message}");
        }
    }

    /// <summary>
    /// Toggles the sort direction.
    /// </summary>
    [RelayCommand]
    private void ToggleSortDirection()
    {
        SortDescending = !SortDescending;
    }
}
