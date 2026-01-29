// File: CraigOClean-vNext/CraigOClean/Domain/Protocols/DiagnosticsService.swift
// Craig-O-Clean - Diagnostics Service Protocol
// Protocol defining diagnostic collection operations

import Foundation

/// Protocol for diagnostics service implementations
@MainActor
public protocol DiagnosticsService: Sendable {

    /// Collects a full diagnostic report
    /// - Returns: The generated diagnostic report
    func collectReport() async throws -> DiagnosticReport

    /// Collects basic system information
    /// - Returns: System information struct
    func collectSystemInfo() async -> SystemInfo

    /// Collects disk information for the main volume
    /// - Returns: Disk information or nil if not accessible
    func collectDiskInfo() async -> DiskInfo?

    /// Collects cache size information
    /// - Returns: Cache information
    func collectCacheInfo() async -> CacheInfo

    /// Exports a diagnostic report to file
    /// - Parameter report: The report to export
    /// - Parameter url: Destination URL
    func exportReport(_ report: DiagnosticReport, to url: URL) async throws

    /// Returns true if full disk inspection is available
    var canInspectFullDisk: Bool { get }

    /// Returns true if report export is available
    var canExportReports: Bool { get }
}

// MARK: - Diagnostics Errors

public enum DiagnosticsError: Error, LocalizedError, Sendable {
    case notSupportedInEdition(reason: String)
    case collectionFailed(reason: String)
    case exportFailed(reason: String)
    case permissionDenied
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notSupportedInEdition(let reason):
            return "Not supported in this edition: \(reason)"
        case .collectionFailed(let reason):
            return "Failed to collect diagnostics: \(reason)"
        case .exportFailed(let reason):
            return "Failed to export report: \(reason)"
        case .permissionDenied:
            return "Permission denied for diagnostic collection"
        case .cancelled:
            return "Diagnostic collection was cancelled"
        }
    }
}
