// File: CraigOClean-vNext/CraigOClean/Platforms/Capabilities/DirectProCapabilities.swift
// Craig-O-Clean - DirectPro Capabilities Provider
// Provides full capabilities for the direct distribution (Pro) edition

import Foundation

/// Capabilities provider for the DirectPro edition.
/// This edition has full access to all features including privileged operations.
public struct DirectProCapabilities: CapabilityProviding {

    public static let shared = DirectProCapabilities()

    public let edition: AppEdition = .directPro

    public var capabilities: Capabilities {
        Capabilities(
            canDeleteSystemWideCaches: true,
            canDeleteUserCaches: true,
            canInspectDiskUsage: true,
            canExportDiagnostics: true,
            canRunPrivilegedOperations: true,
            canInstallHelperTool: true,
            canAutoUpdate: true,
            canUseExternalLicensing: true
        )
    }

    private init() {}

    // MARK: - Runtime Capability Checks

    /// Checks if the privileged helper is currently installed
    public func isHelperInstalled() -> Bool {
        // TODO: Implement actual helper installation check
        // Check if the helper tool exists and is properly registered
        let helperPath = "/Library/PrivilegedHelperTools/com.craigosoft.CraigOClean.Helper"
        return FileManager.default.fileExists(atPath: helperPath)
    }

    /// Checks if we have Full Disk Access permission
    public func hasFullDiskAccess() -> Bool {
        // Check by attempting to read a protected directory
        let testPath = "\(NSHomeDirectory())/Library/Mail"
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    /// Returns a detailed capability status including runtime checks
    public func detailedStatus() -> DirectProStatus {
        DirectProStatus(
            helperInstalled: isHelperInstalled(),
            fullDiskAccess: hasFullDiskAccess(),
            capabilities: capabilities
        )
    }
}

// MARK: - DirectPro Status

/// Detailed status for DirectPro edition including runtime permission checks
public struct DirectProStatus {
    public let helperInstalled: Bool
    public let fullDiskAccess: Bool
    public let capabilities: Capabilities

    public var allPrivilegedFeaturesReady: Bool {
        helperInstalled && fullDiskAccess
    }

    public var setupRecommendations: [String] {
        var recommendations: [String] = []

        if !helperInstalled {
            recommendations.append("Install the privileged helper for system-wide cleanup")
        }

        if !fullDiskAccess {
            recommendations.append("Grant Full Disk Access in System Settings > Privacy & Security")
        }

        return recommendations
    }
}
