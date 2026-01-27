// MARK: - CatalogStore.swift
// Craig-O-Clean - Capability Catalog Store
// Loads, validates, and provides access to the capability catalog

import Foundation
import os.log

@MainActor
final class CatalogStore: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var capabilities: [Capability] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var loadError: String?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "CatalogStore")
    private var capabilityIndex: [String: Capability] = [:]

    // MARK: - Singleton

    static let shared = CatalogStore()

    // MARK: - Initialization

    private init() {}

    // MARK: - Loading

    func load() {
        guard !isLoaded else { return }

        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            loadError = "catalog.json not found in app bundle"
            logger.error("catalog.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(CapabilityCatalogData.self, from: data)

            // Validate
            let errors = CatalogValidator.validate(catalog)
            if !errors.isEmpty {
                for error in errors {
                    logger.warning("Catalog validation warning: \(error)")
                }
            }

            capabilities = catalog.capabilities
            capabilityIndex = Dictionary(uniqueKeysWithValues: catalog.capabilities.map { ($0.id, $0) })
            isLoaded = true
            logger.info("Loaded \(catalog.capabilities.count) capabilities (v\(catalog.version))")
        } catch {
            loadError = "Failed to load catalog: \(error.localizedDescription)"
            logger.error("Failed to load catalog: \(error.localizedDescription)")
        }
    }

    // MARK: - Lookup

    func capability(byId id: String) -> Capability? {
        return capabilityIndex[id]
    }

    func capabilities(inCategory category: CapabilityCategory) -> [Capability] {
        return capabilities.filter { $0.category == category }
    }

    func capabilities(withRisk risk: RiskClass) -> [Capability] {
        return capabilities.filter { $0.riskClass == risk }
    }

    func capabilities(forExecutor executor: ExecutorType) -> [Capability] {
        return capabilities.filter { $0.executorType == executor }
    }

    /// Returns true if the given ID exists in the catalog (allowlist check)
    func isAllowed(_ capabilityId: String) -> Bool {
        return capabilityIndex[capabilityId] != nil
    }

    /// Safe capabilities that can run without confirmation
    var safeCapabilities: [Capability] {
        return capabilities.filter { $0.riskClass == .safe && $0.requiredPrivileges == .user }
    }

    /// Capabilities grouped by category for UI display
    var groupedByCategory: [CapabilityCategory: [Capability]] {
        return Dictionary(grouping: capabilities, by: { $0.category })
    }
}
