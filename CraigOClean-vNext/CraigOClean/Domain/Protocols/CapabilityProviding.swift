// File: CraigOClean-vNext/CraigOClean/Domain/Protocols/CapabilityProviding.swift
// Craig-O-Clean - Capability Providing Protocol
// Protocol for capability providers across different editions

import Foundation

/// Protocol for types that provide capability information for an app edition.
public protocol CapabilityProviding: Sendable {

    /// The app edition this provider represents
    var edition: AppEdition { get }

    /// The capabilities available in this edition
    var capabilities: Capabilities { get }
}

// MARK: - Default Implementations

extension CapabilityProviding {

    /// Convenience check for system-wide cache deletion capability
    public var canDeleteSystemWideCaches: Bool {
        capabilities.canDeleteSystemWideCaches
    }

    /// Convenience check for user cache deletion capability
    public var canDeleteUserCaches: Bool {
        capabilities.canDeleteUserCaches
    }

    /// Convenience check for privileged operations capability
    public var canRunPrivilegedOperations: Bool {
        capabilities.canRunPrivilegedOperations
    }

    /// Convenience check for auto-update capability
    public var canAutoUpdate: Bool {
        capabilities.canAutoUpdate
    }
}

// MARK: - Capability Provider Factory

/// Factory for obtaining the appropriate capability provider for the current edition
public enum CapabilityProviderFactory {

    /// Returns the capability provider for the current app edition
    public static func current() -> any CapabilityProviding {
        switch AppEdition.current {
        case .directPro:
            return DirectProCapabilities.shared
        case .appStoreLite:
            return AppStoreLiteCapabilities.shared
        }
    }

    /// Returns the capability provider for a specific edition
    public static func provider(for edition: AppEdition) -> any CapabilityProviding {
        switch edition {
        case .directPro:
            return DirectProCapabilities.shared
        case .appStoreLite:
            return AppStoreLiteCapabilities.shared
        }
    }
}
