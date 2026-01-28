// MARK: - CraigOCleanError.swift
// Craig-O-Clean - Structured Error Types
// Provides comprehensive, user-friendly error handling for all operations

import Foundation

/// Main error type for Craig-O-Clean operations
enum CraigOCleanError: Error, LocalizedError {
    // MARK: - Permission Errors
    case permissionDenied(PermissionType)
    case permissionNotDetermined(PermissionType)
    case permissionRevoked(PermissionType)

    // MARK: - File Access Errors
    case accessDenied(URL)
    case bookmarkStale(URL)
    case bookmarkCreationFailed(URL, underlying: Error?)
    case fileNotFound(URL)
    case fileOperationFailed(URL, operation: FileOperation, underlying: Error?)

    // MARK: - Operation Errors
    case operationCancelled
    case operationFailed(description: String, underlying: Error?)
    case operationNotConfirmed
    case operationTimeout(TimeInterval)

    // MARK: - Script Execution Errors
    case scriptExecutionFailed(errorCode: Int, description: String)
    case scriptCompilationFailed(description: String)
    case appleScriptPermissionDenied(targetApp: String)

    // MARK: - Process Errors
    case processNotFound(identifier: String)
    case processTerminationFailed(name: String, reason: String)
    case processProtected(name: String)

    // MARK: - Feature Availability Errors
    case featureUnavailable(feature: String, reason: String)
    case featureRequiresDevID(feature: String)
    case featureRequiresPermission(feature: String, permission: PermissionType)

    // MARK: - Configuration Errors
    case invalidConfiguration(description: String)
    case missingResource(name: String)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "Permission denied: \(type.displayName)"

        case .permissionNotDetermined(let type):
            return "\(type.displayName) permission has not been requested yet"

        case .permissionRevoked(let type):
            return "\(type.displayName) permission was revoked"

        case .accessDenied(let url):
            return "Access denied to \(url.lastPathComponent)"

        case .bookmarkStale(let url):
            return "Access to \(url.lastPathComponent) has expired. Please re-authorize."

        case .bookmarkCreationFailed(let url, _):
            return "Failed to save access permission for \(url.lastPathComponent)"

        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"

        case .fileOperationFailed(let url, let operation, _):
            return "Failed to \(operation.rawValue) \(url.lastPathComponent)"

        case .operationCancelled:
            return "Operation was cancelled"

        case .operationFailed(let description, _):
            return description

        case .operationNotConfirmed:
            return "Operation requires confirmation"

        case .operationTimeout(let interval):
            return "Operation timed out after \(Int(interval)) seconds"

        case .scriptExecutionFailed(let code, let description):
            return "Script failed (error \(code)): \(description)"

        case .scriptCompilationFailed(let description):
            return "Script compilation failed: \(description)"

        case .appleScriptPermissionDenied(let app):
            return "Automation permission denied for \(app). Enable in System Settings > Privacy & Security > Automation."

        case .processNotFound(let identifier):
            return "Process not found: \(identifier)"

        case .processTerminationFailed(let name, let reason):
            return "Failed to terminate \(name): \(reason)"

        case .processProtected(let name):
            return "Cannot terminate protected system process: \(name)"

        case .featureUnavailable(let feature, let reason):
            return "\(feature) is unavailable: \(reason)"

        case .featureRequiresDevID(let feature):
            return "\(feature) is only available in the Developer ID version"

        case .featureRequiresPermission(let feature, let permission):
            return "\(feature) requires \(permission.displayName) permission"

        case .invalidConfiguration(let description):
            return "Invalid configuration: \(description)"

        case .missingResource(let name):
            return "Missing resource: \(name)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied(let type), .permissionRevoked(let type):
            return "Open System Settings > Privacy & Security > \(type.settingsSection) to enable this permission."

        case .bookmarkStale:
            return "Click 'Authorize' to select the folder again."

        case .appleScriptPermissionDenied(let app):
            return "Open System Settings > Privacy & Security > Automation, then enable Craig-O-Clean for \(app)."

        case .featureRequiresDevID:
            return "Download the Developer ID version from our website for this feature."

        case .featureRequiresPermission(_, let permission):
            return "Open System Settings > Privacy & Security > \(permission.settingsSection) to enable this permission."

        default:
            return nil
        }
    }

    var failureReason: String? {
        switch self {
        case .operationFailed(_, let underlying),
             .fileOperationFailed(_, _, let underlying),
             .bookmarkCreationFailed(_, let underlying):
            return underlying?.localizedDescription
        default:
            return nil
        }
    }
}

// MARK: - Supporting Types

/// Types of permissions that can be requested
enum PermissionType: Equatable, Hashable {
    case automation(bundleId: String)
    case accessibility
    case fullDiskAccess
    case fileAccess(URL)
    case notifications

    var displayName: String {
        switch self {
        case .automation(let bundleId):
            return "Automation (\(appNameForBundleId(bundleId)))"
        case .accessibility:
            return "Accessibility"
        case .fullDiskAccess:
            return "Full Disk Access"
        case .fileAccess(let url):
            return "Access to \(url.lastPathComponent)"
        case .notifications:
            return "Notifications"
        }
    }

    var settingsSection: String {
        switch self {
        case .automation:
            return "Automation"
        case .accessibility:
            return "Accessibility"
        case .fullDiskAccess:
            return "Full Disk Access"
        case .fileAccess:
            return "Files and Folders"
        case .notifications:
            return "Notifications"
        }
    }

    private func appNameForBundleId(_ bundleId: String) -> String {
        let knownApps: [String: String] = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Chrome",
            "com.microsoft.edgemac": "Edge",
            "com.brave.Browser": "Brave",
            "company.thebrowser.Browser": "Arc",
            "org.mozilla.firefox": "Firefox",
            "com.apple.systemevents": "System Events",
            "com.apple.finder": "Finder"
        ]
        return knownApps[bundleId] ?? bundleId
    }
}

/// File operations that can fail
enum FileOperation: String {
    case read
    case write
    case delete
    case move
    case copy
    case enumerate
    case createDirectory = "create directory"
}

// MARK: - Error Context

/// Provides additional context for error handling and logging
struct ErrorContext {
    let error: CraigOCleanError
    let source: String
    let additionalInfo: [String: String]
    let timestamp: Date

    init(error: CraigOCleanError, source: String, additionalInfo: [String: String] = [:]) {
        self.error = error
        self.source = source
        self.additionalInfo = additionalInfo
        self.timestamp = Date()
    }

    var logDescription: String {
        var parts = ["[\(source)] \(error.localizedDescription)"]
        if !additionalInfo.isEmpty {
            parts.append("Context: \(additionalInfo)")
        }
        return parts.joined(separator: " | ")
    }
}

// MARK: - Error Helpers

extension CraigOCleanError {
    /// Returns true if this error is recoverable by the user
    var isUserRecoverable: Bool {
        switch self {
        case .permissionDenied, .permissionRevoked, .permissionNotDetermined,
             .bookmarkStale, .appleScriptPermissionDenied,
             .featureRequiresPermission, .operationNotConfirmed:
            return true
        default:
            return false
        }
    }

    /// Returns true if this error should be shown to the user
    var shouldShowToUser: Bool {
        switch self {
        case .operationCancelled:
            return false
        default:
            return true
        }
    }

    /// Returns the AppleScript error code if this is a script error
    var appleScriptErrorCode: Int? {
        switch self {
        case .scriptExecutionFailed(let code, _):
            return code
        case .appleScriptPermissionDenied:
            return -1743
        default:
            return nil
        }
    }
}
