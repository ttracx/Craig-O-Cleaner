// File: CraigOClean-vNext/CraigOClean/Platforms/Capabilities/Capabilities.swift
// Craig-O-Clean - Capabilities Model
// Defines the feature capabilities available in each edition

import Foundation

/// Represents the set of capabilities available in the current app edition.
/// This is the central model for feature gating across DirectPro and AppStoreLite.
public struct Capabilities: Equatable, Sendable {

    // MARK: - Cleanup Capabilities

    /// Can delete system-wide caches (requires privileged helper in DirectPro)
    public let canDeleteSystemWideCaches: Bool

    /// Can delete user-level caches (available in both editions)
    public let canDeleteUserCaches: Bool

    // MARK: - Diagnostics Capabilities

    /// Can inspect full disk usage across the system
    public let canInspectDiskUsage: Bool

    /// Can export diagnostic reports to file
    public let canExportDiagnostics: Bool

    // MARK: - Privileged Operations

    /// Can run operations requiring admin privileges
    public let canRunPrivilegedOperations: Bool

    /// Can install/manage the privileged helper tool
    public let canInstallHelperTool: Bool

    // MARK: - Updates & Licensing

    /// Can auto-update via Sparkle or similar
    public let canAutoUpdate: Bool

    /// Can use external licensing system (not In-App Purchase)
    public let canUseExternalLicensing: Bool

    // MARK: - Initialization

    public init(
        canDeleteSystemWideCaches: Bool,
        canDeleteUserCaches: Bool,
        canInspectDiskUsage: Bool,
        canExportDiagnostics: Bool,
        canRunPrivilegedOperations: Bool,
        canInstallHelperTool: Bool,
        canAutoUpdate: Bool,
        canUseExternalLicensing: Bool
    ) {
        self.canDeleteSystemWideCaches = canDeleteSystemWideCaches
        self.canDeleteUserCaches = canDeleteUserCaches
        self.canInspectDiskUsage = canInspectDiskUsage
        self.canExportDiagnostics = canExportDiagnostics
        self.canRunPrivilegedOperations = canRunPrivilegedOperations
        self.canInstallHelperTool = canInstallHelperTool
        self.canAutoUpdate = canAutoUpdate
        self.canUseExternalLicensing = canUseExternalLicensing
    }
}

// MARK: - Capability Descriptions

extension Capabilities {

    /// Human-readable descriptions for each capability
    public struct CapabilityInfo: Identifiable {
        public let id: String
        public let name: String
        public let description: String
        public let isEnabled: Bool
        public let unavailableReason: String?

        public init(id: String, name: String, description: String, isEnabled: Bool, unavailableReason: String? = nil) {
            self.id = id
            self.name = name
            self.description = description
            self.isEnabled = isEnabled
            self.unavailableReason = unavailableReason
        }
    }

    /// Returns all capabilities with their descriptions and availability status
    public func allCapabilities(edition: AppEdition) -> [CapabilityInfo] {
        let liteReason = "Not available in App Store Lite edition due to sandbox restrictions."

        return [
            CapabilityInfo(
                id: "systemCaches",
                name: "System-Wide Caches",
                description: "Clean caches from system directories",
                isEnabled: canDeleteSystemWideCaches,
                unavailableReason: canDeleteSystemWideCaches ? nil : liteReason
            ),
            CapabilityInfo(
                id: "userCaches",
                name: "User Caches",
                description: "Clean caches from your user directory",
                isEnabled: canDeleteUserCaches,
                unavailableReason: nil
            ),
            CapabilityInfo(
                id: "diskUsage",
                name: "Full Disk Inspection",
                description: "Analyze disk usage across the entire system",
                isEnabled: canInspectDiskUsage,
                unavailableReason: canInspectDiskUsage ? nil : liteReason
            ),
            CapabilityInfo(
                id: "exportDiagnostics",
                name: "Export Diagnostics",
                description: "Export diagnostic reports to files",
                isEnabled: canExportDiagnostics,
                unavailableReason: canExportDiagnostics ? nil : liteReason
            ),
            CapabilityInfo(
                id: "privilegedOps",
                name: "Privileged Operations",
                description: "Run operations requiring admin access",
                isEnabled: canRunPrivilegedOperations,
                unavailableReason: canRunPrivilegedOperations ? nil : liteReason
            ),
            CapabilityInfo(
                id: "helperTool",
                name: "Helper Tool",
                description: "Install and manage privileged helper",
                isEnabled: canInstallHelperTool,
                unavailableReason: canInstallHelperTool ? nil : liteReason
            ),
            CapabilityInfo(
                id: "autoUpdate",
                name: "Auto-Update",
                description: "Automatic updates via Sparkle",
                isEnabled: canAutoUpdate,
                unavailableReason: canAutoUpdate ? nil : "Updates managed by App Store"
            ),
            CapabilityInfo(
                id: "externalLicensing",
                name: "External Licensing",
                description: "License activation via external system",
                isEnabled: canUseExternalLicensing,
                unavailableReason: canUseExternalLicensing ? nil : "Licensing managed by App Store"
            )
        ]
    }
}

// MARK: - App Edition

/// Represents the application edition/variant
public enum AppEdition: String, Sendable, CaseIterable {
    case directPro = "DirectPro"
    case appStoreLite = "AppStoreLite"

    public var displayName: String {
        switch self {
        case .directPro:
            return "Craig-O-Clean Pro"
        case .appStoreLite:
            return "Craig-O-Clean Lite"
        }
    }

    public var shortName: String {
        switch self {
        case .directPro:
            return "Pro"
        case .appStoreLite:
            return "Lite"
        }
    }

    public var description: String {
        switch self {
        case .directPro:
            return "Full-featured edition with system-wide cleanup and advanced diagnostics"
        case .appStoreLite:
            return "App Store edition with user-level cleanup and basic diagnostics"
        }
    }

    /// Detects the current edition at runtime
    public static var current: AppEdition {
        #if APPSTORE_LITE
        return .appStoreLite
        #elseif DIRECT_PRO
        return .directPro
        #else
        // Default to Lite for safety if no flag is set
        return .appStoreLite
        #endif
    }
}
