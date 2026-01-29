// File: CraigOClean-vNext/CraigOClean/Platforms/Capabilities/AppStoreLiteCapabilities.swift
// Craig-O-Clean - AppStore Lite Capabilities Provider
// Provides restricted capabilities for the App Store (Lite) edition

import Foundation

/// Capabilities provider for the AppStoreLite edition.
/// This edition is sandbox-constrained and only supports user-level operations.
public struct AppStoreLiteCapabilities: CapabilityProviding {

    public static let shared = AppStoreLiteCapabilities()

    public let edition: AppEdition = .appStoreLite

    public var capabilities: Capabilities {
        Capabilities(
            canDeleteSystemWideCaches: false,      // Sandbox restriction
            canDeleteUserCaches: true,             // Allowed within sandbox
            canInspectDiskUsage: false,            // System-wide not allowed
            canExportDiagnostics: false,           // Limited file access
            canRunPrivilegedOperations: false,     // No admin access
            canInstallHelperTool: false,           // No privileged helpers
            canAutoUpdate: false,                  // App Store manages updates
            canUseExternalLicensing: false         // App Store manages licensing
        )
    }

    private init() {}

    // MARK: - Sandbox-Safe Path Validation

    /// Validates that a path is within the sandbox-allowed directories
    public func isPathAllowed(_ path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath

        // Only allow paths within user's home directory
        guard expandedPath.hasPrefix(NSHomeDirectory()) else {
            return false
        }

        // Additional safety: block certain sensitive directories even within home
        let blockedSubpaths = [
            "/Library/Keychains",
            "/Library/Accounts",
            "/.ssh",
            "/.gnupg",
            "/Library/Cookies"
        ]

        for blocked in blockedSubpaths {
            if expandedPath.contains(blocked) {
                return false
            }
        }

        return true
    }

    /// Returns the allowed cache directories for cleanup
    public func allowedCacheDirectories() -> [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/Library/Caches",
            "\(home)/Library/Logs"
        ]
    }

    /// Returns a user-friendly explanation of why a feature is unavailable
    public func unavailabilityReason(for capability: String) -> String {
        switch capability {
        case "systemCaches":
            return "System-wide cache cleanup requires access outside the app sandbox. This feature is available in Craig-O-Clean Pro."
        case "diskUsage":
            return "Full disk inspection requires system-level access. This feature is available in Craig-O-Clean Pro."
        case "privilegedOps":
            return "Privileged operations require admin access which isn't available in sandboxed apps."
        case "helperTool":
            return "Installing system helpers isn't permitted in App Store apps."
        case "autoUpdate":
            return "Updates are managed through the Mac App Store."
        case "externalLicensing":
            return "Licensing is managed through the Mac App Store."
        case "exportDiagnostics":
            return "Exporting to arbitrary locations requires broader file access. This feature is available in Craig-O-Clean Pro."
        default:
            return "This feature is not available in the App Store Lite edition."
        }
    }
}

// MARK: - AppStore Compliance Errors

/// Errors specific to App Store edition restrictions
public enum AppStoreComplianceError: Error, LocalizedError {
    case notSupportedInEdition(reason: String)
    case pathNotAllowed(path: String)
    case operationRequiresPrivileges(operation: String)
    case sandboxViolation(detail: String)

    public var errorDescription: String? {
        switch self {
        case .notSupportedInEdition(let reason):
            return "Feature not available: \(reason)"
        case .pathNotAllowed(let path):
            return "Access to '\(path)' is not permitted in this edition"
        case .operationRequiresPrivileges(let operation):
            return "'\(operation)' requires admin privileges not available in this edition"
        case .sandboxViolation(let detail):
            return "Operation blocked by sandbox: \(detail)"
        }
    }
}
