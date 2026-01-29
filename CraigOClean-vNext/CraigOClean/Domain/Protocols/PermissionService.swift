// File: CraigOClean-vNext/CraigOClean/Domain/Protocols/PermissionService.swift
// Craig-O-Clean - Permission Service Protocol
// Protocol defining permission checking and requesting operations

import Foundation

/// Protocol for permission service implementations
@MainActor
public protocol PermissionService: Sendable {

    /// Checks if admin privileges are needed for an operation
    /// - Parameter operation: The operation to check
    /// - Returns: True if admin is required
    func needsAdmin(for operation: PermissionOperation) -> Bool

    /// Requests admin privileges if needed
    /// - Parameter operation: The operation requiring privileges
    /// - Returns: True if privileges were granted or not needed
    func requestAdminIfNeeded(for operation: PermissionOperation) async throws -> Bool

    /// Checks current Full Disk Access status
    /// - Returns: The current FDA status
    func checkFullDiskAccess() -> FullDiskAccessStatus

    /// Opens System Settings to Full Disk Access pane
    func openFullDiskAccessSettings()

    /// Checks if the privileged helper is installed (DirectPro only)
    /// - Returns: Helper installation status
    func checkHelperStatus() -> HelperStatus

    /// Installs the privileged helper tool (DirectPro only)
    func installHelper() async throws

    /// Returns the current edition's permission capabilities
    var capabilities: Capabilities { get }
}

// MARK: - Permission Operation

/// Operations that may require special permissions
public enum PermissionOperation: String, Sendable {
    case deleteUserCaches = "delete_user_caches"
    case deleteSystemCaches = "delete_system_caches"
    case inspectDiskUsage = "inspect_disk_usage"
    case exportDiagnostics = "export_diagnostics"
    case installHelper = "install_helper"

    public var displayName: String {
        switch self {
        case .deleteUserCaches: return "Delete User Caches"
        case .deleteSystemCaches: return "Delete System Caches"
        case .inspectDiskUsage: return "Inspect Disk Usage"
        case .exportDiagnostics: return "Export Diagnostics"
        case .installHelper: return "Install Helper Tool"
        }
    }

    public var requiresAdmin: Bool {
        switch self {
        case .deleteUserCaches, .exportDiagnostics:
            return false
        case .deleteSystemCaches, .inspectDiskUsage, .installHelper:
            return true
        }
    }
}

// MARK: - Full Disk Access Status

public enum FullDiskAccessStatus: Sendable {
    case granted
    case denied
    case unknown
    case notRequired  // For sandbox edition

    public var displayName: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Not Granted"
        case .unknown: return "Unknown"
        case .notRequired: return "Not Required"
        }
    }

    public var isGranted: Bool {
        self == .granted || self == .notRequired
    }
}

// MARK: - Helper Status

public enum HelperStatus: Sendable {
    case installed(version: String)
    case notInstalled
    case needsUpdate(currentVersion: String, requiredVersion: String)
    case notAvailable  // For sandbox edition

    public var isReady: Bool {
        if case .installed = self {
            return true
        }
        return false
    }

    public var displayName: String {
        switch self {
        case .installed(let version):
            return "Installed (v\(version))"
        case .notInstalled:
            return "Not Installed"
        case .needsUpdate(_, let required):
            return "Update Required (v\(required))"
        case .notAvailable:
            return "Not Available"
        }
    }
}

// MARK: - Permission Errors

public enum PermissionError: Error, LocalizedError, Sendable {
    case adminRequired
    case adminDenied
    case fullDiskAccessRequired
    case helperInstallationFailed(reason: String)
    case notSupportedInEdition
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .adminRequired:
            return "Administrator privileges are required for this operation"
        case .adminDenied:
            return "Administrator authorization was denied"
        case .fullDiskAccessRequired:
            return "Full Disk Access is required. Please grant access in System Settings."
        case .helperInstallationFailed(let reason):
            return "Failed to install helper tool: \(reason)"
        case .notSupportedInEdition:
            return "This operation is not supported in the current edition"
        case .cancelled:
            return "Permission request was cancelled"
        }
    }
}
