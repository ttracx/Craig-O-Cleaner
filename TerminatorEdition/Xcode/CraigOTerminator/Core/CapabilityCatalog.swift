//
//  CapabilityCatalog.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import os.log

// MARK: - Capability Catalog

/// Central registry for all capabilities loaded from catalog.json
@Observable
final class CapabilityCatalog {

    // MARK: - Singleton
    static let shared = CapabilityCatalog()

    // MARK: - Observable State
    private(set) var capabilities: [Capability] = []
    private(set) var version: String = ""
    private(set) var lastUpdated: String = ""
    private(set) var isLoaded: Bool = false
    private(set) var loadError: Error?

    // MARK: - Private State
    private var capabilityIndex: [String: Capability] = [:]
    private var groupIndex: [CapabilityGroup: [Capability]] = [:]
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "CapabilityCatalog")

    // MARK: - Initialization
    private init() {
        loadCatalog()
    }

    // MARK: - Loading

    /// Load catalog from bundle resources
    func loadCatalog() {
        do {
            logger.info("Loading capability catalog from bundle...")

            guard let catalogURL = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
                throw CatalogError.fileNotFound
            }

            let data = try Data(contentsOf: catalogURL)
            let decoder = JSONDecoder()

            let catalog = try decoder.decode(CapabilityCatalogSchema.self, from: data)

            // Store metadata
            self.version = catalog.version
            self.lastUpdated = catalog.lastUpdated
            self.capabilities = catalog.capabilities

            // Build indexes for fast lookup
            buildIndexes()

            self.isLoaded = true
            self.loadError = nil

            logger.info("✅ Catalog loaded: version \(self.version), \(self.capabilities.count) capabilities")

        } catch {
            logger.error("❌ Failed to load catalog: \(error.localizedDescription)")
            self.loadError = error
            self.isLoaded = false
        }
    }

    /// Build lookup indexes for performance
    private func buildIndexes() {
        // ID index
        capabilityIndex = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.id, $0) })

        // Group index
        groupIndex = Dictionary(grouping: capabilities, by: { $0.group })

        logger.debug("Built indexes: \(self.capabilityIndex.count) capabilities, \(self.groupIndex.count) groups")
    }

    // MARK: - Lookup Methods

    /// Get capability by ID
    /// - Parameter id: Capability identifier
    /// - Returns: Capability if found, nil otherwise
    func capability(id: String) -> Capability? {
        capabilityIndex[id]
    }

    /// Get all capabilities for a specific group
    /// - Parameter group: Capability group
    /// - Returns: Array of capabilities in the group, sorted by title
    func capabilities(group: CapabilityGroup) -> [Capability] {
        groupIndex[group]?.sorted(by: { $0.title < $1.title }) ?? []
    }

    /// Get all capabilities, optionally filtered
    /// - Parameter filter: Optional closure to filter capabilities
    /// - Returns: Array of all capabilities (or filtered subset)
    func allCapabilities(filter: ((Capability) -> Bool)? = nil) -> [Capability] {
        if let filter = filter {
            return capabilities.filter(filter)
        }
        return capabilities
    }

    /// Search capabilities by title or description
    /// - Parameter query: Search term
    /// - Returns: Array of matching capabilities
    func search(query: String) -> [Capability] {
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()
        return capabilities.filter { capability in
            capability.title.lowercased().contains(lowercasedQuery) ||
            capability.description.lowercased().contains(lowercasedQuery) ||
            capability.id.lowercased().contains(lowercasedQuery)
        }
    }

    /// Get capabilities by privilege level
    /// - Parameter level: Privilege level to filter by
    /// - Returns: Array of capabilities requiring that privilege level
    func capabilities(privilegeLevel level: PrivilegeLevel) -> [Capability] {
        capabilities.filter { $0.privilegeLevel == level }
    }

    /// Get capabilities by risk class
    /// - Parameter risk: Risk class to filter by
    /// - Returns: Array of capabilities with that risk class
    func capabilities(riskClass risk: RiskClass) -> [Capability] {
        capabilities.filter { $0.riskClass == risk }
    }

    // MARK: - Statistics

    /// Get capability count for a group
    /// - Parameter group: Capability group
    /// - Returns: Number of capabilities in the group
    func count(for group: CapabilityGroup) -> Int {
        groupIndex[group]?.count ?? 0
    }

    /// Get total capability count
    var totalCount: Int {
        capabilities.count
    }

    /// Get statistics summary
    var statistics: CatalogStatistics {
        CatalogStatistics(
            totalCapabilities: capabilities.count,
            byGroup: Dictionary(uniqueKeysWithValues: CapabilityGroup.allCases.map { ($0, count(for: $0)) }),
            byPrivilege: Dictionary(grouping: capabilities, by: { $0.privilegeLevel })
                .mapValues { $0.count },
            byRisk: Dictionary(grouping: capabilities, by: { $0.riskClass })
                .mapValues { $0.count }
        )
    }
}

// MARK: - Catalog Statistics

struct CatalogStatistics {
    let totalCapabilities: Int
    let byGroup: [CapabilityGroup: Int]
    let byPrivilege: [PrivilegeLevel: Int]
    let byRisk: [RiskClass: Int]

    var description: String {
        """
        Catalog Statistics:
        Total: \(totalCapabilities) capabilities
        By Group: \(byGroup.map { "\($0.key.displayTitle): \($0.value)" }.joined(separator: ", "))
        By Privilege: \(byPrivilege.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", "))
        By Risk: \(byRisk.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", "))
        """
    }
}

// MARK: - Catalog Error

enum CatalogError: LocalizedError {
    case fileNotFound
    case decodingFailed(Error)
    case invalidSchema

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Catalog file (catalog.json) not found in bundle resources"
        case .decodingFailed(let error):
            return "Failed to decode catalog: \(error.localizedDescription)"
        case .invalidSchema:
            return "Catalog schema validation failed"
        }
    }
}
