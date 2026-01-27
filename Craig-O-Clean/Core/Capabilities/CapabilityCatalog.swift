// MARK: - CapabilityCatalog.swift
// Craig-O-Clean - Capability Catalog Loader & Registry
// Loads and provides access to the bundled capability catalog

import Foundation
import os.log

// MARK: - Catalog Schema

/// Top-level catalog JSON structure
struct CatalogSchema: Codable {
    let version: String
    let lastUpdated: String
    let capabilities: [Capability]
}

// MARK: - Capability Catalog

/// Registry of all available capabilities, loaded from bundled JSON
@MainActor
final class CapabilityCatalog: ObservableObject {
    static let shared = CapabilityCatalog()

    @Published private(set) var capabilities: [Capability] = []
    @Published private(set) var loadError: String?

    private let logger = Logger(subsystem: "com.CraigOClean", category: "CapabilityCatalog")

    private init() {
        loadCatalog()
    }

    // MARK: - Loading

    private func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            logger.error("catalog.json not found in bundle")
            loadError = "Capability catalog not found"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let schema = try decoder.decode(CatalogSchema.self, from: data)
            capabilities = schema.capabilities
            logger.info("Loaded \(schema.capabilities.count) capabilities (v\(schema.version))")
        } catch {
            logger.error("Failed to decode catalog: \(error.localizedDescription)")
            loadError = "Failed to load capability catalog: \(error.localizedDescription)"
        }
    }

    // MARK: - Queries

    /// Get a capability by ID
    func capability(id: String) -> Capability? {
        capabilities.first { $0.id == id }
    }

    /// Get all capabilities in a group
    func capabilities(in group: CapabilityGroup) -> [Capability] {
        capabilities.filter { $0.group == group }
    }

    /// Get all capabilities requiring a specific privilege level
    func capabilities(requiring privilege: PrivilegeLevel) -> [Capability] {
        capabilities.filter { $0.privilegeLevel == privilege }
    }

    /// Get all capabilities of a specific risk class
    func capabilities(risk: RiskClass) -> [Capability] {
        capabilities.filter { $0.riskClass == risk }
    }

    /// Get all safe, user-level capabilities (no confirmation needed)
    var quickActions: [Capability] {
        capabilities.filter { $0.riskClass == .safe && $0.privilegeLevel == .user }
    }

    /// Get all destructive capabilities
    var destructiveActions: [Capability] {
        capabilities.filter { $0.riskClass == .destructive }
    }
}
