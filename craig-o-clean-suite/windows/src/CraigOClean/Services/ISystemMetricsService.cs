// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service interface for retrieving system metrics.
/// </summary>
public interface ISystemMetricsService : IDisposable
{
    /// <summary>
    /// Event raised when metrics are updated.
    /// </summary>
    event EventHandler<SystemMetrics>? MetricsUpdated;

    /// <summary>
    /// Gets the current system metrics.
    /// </summary>
    SystemMetrics CurrentMetrics { get; }

    /// <summary>
    /// Gets system metrics asynchronously.
    /// </summary>
    Task<SystemMetrics> GetMetricsAsync();

    /// <summary>
    /// Starts continuous metrics monitoring.
    /// </summary>
    void StartMonitoring(int intervalMs = 2000);

    /// <summary>
    /// Stops continuous metrics monitoring.
    /// </summary>
    void StopMonitoring();

    /// <summary>
    /// Gets whether monitoring is currently active.
    /// </summary>
    bool IsMonitoring { get; }
}
