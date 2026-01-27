// MARK: - CatalogValidator.swift
// Craig-O-Clean - Capability Catalog Validator
// Validates catalog schema and integrity at runtime and in tests

import Foundation

enum CatalogValidator {

    /// Validate the entire catalog data, returning an array of error messages.
    /// An empty array means the catalog is valid.
    static func validate(_ catalog: CapabilityCatalogData) -> [String] {
        var errors: [String] = []

        if catalog.version.isEmpty {
            errors.append("Catalog version is empty")
        }

        if catalog.capabilities.isEmpty {
            errors.append("Catalog has no capabilities")
        }

        // Check for duplicate IDs
        var seenIds = Set<String>()
        for cap in catalog.capabilities {
            if seenIds.contains(cap.id) {
                errors.append("Duplicate capability ID: \(cap.id)")
            }
            seenIds.insert(cap.id)
            errors.append(contentsOf: validateCapability(cap))
        }

        return errors
    }

    /// Validate a single capability
    static func validateCapability(_ cap: Capability) -> [String] {
        var errors: [String] = []

        if cap.id.isEmpty {
            errors.append("Capability has empty ID")
        }

        if cap.title.isEmpty {
            errors.append("Capability '\(cap.id)' has empty title")
        }

        if cap.description.isEmpty {
            errors.append("Capability '\(cap.id)' has empty description")
        }

        // Process executor must have commandTemplate
        if cap.executorType == .process || cap.executorType == .helperXpc {
            if cap.commandTemplate == nil || cap.commandTemplate?.isEmpty == true {
                errors.append("Capability '\(cap.id)' uses \(cap.executorType.rawValue) but has no commandTemplate")
            }
        }

        // AppleEvents executor must have appleScript
        if cap.executorType == .appleEvents {
            if cap.appleScript == nil || cap.appleScript?.isEmpty == true {
                errors.append("Capability '\(cap.id)' uses appleEvents but has no appleScript")
            }
        }

        // Elevated privilege must not be safe risk class (safety check)
        if cap.requiredPrivileges == .elevated && cap.riskClass == .safe {
            errors.append("Capability '\(cap.id)' requires elevated privileges but is marked safe — review risk classification")
        }

        // Destructive capabilities must have confirm text
        if cap.riskClass == .destructive {
            if cap.uiHints?.confirmText == nil || cap.uiHints?.confirmText?.isEmpty == true {
                errors.append("Capability '\(cap.id)' is destructive but has no confirmText in uiHints")
            }
        }

        // Moderate capabilities should have confirm text
        if cap.riskClass == .moderate {
            if cap.uiHints?.confirmText == nil || cap.uiHints?.confirmText?.isEmpty == true {
                errors.append("Capability '\(cap.id)' is moderate risk but has no confirmText — recommend adding one")
            }
        }

        return errors
    }

    /// Validate that a capability ID is in the allowlist
    static func isAllowed(_ capabilityId: String, in catalog: CapabilityCatalogData) -> Bool {
        return catalog.capabilities.contains { $0.id == capabilityId }
    }
}
