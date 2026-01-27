// MARK: - AppEnvironment.swift
// Craig-O-Clean - Dependency Container
// Centralizes shared services for injection into the view hierarchy

import Foundation

/// Central dependency container for the application
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let catalog: CapabilityCatalog
    let coordinator: CapabilityCoordinator
    let logStore: LogStore
    let browserRegistry: BrowserControllerRegistry

    private init() {
        self.catalog = CapabilityCatalog.shared
        self.logStore = SQLiteLogStore.shared
        self.coordinator = CapabilityCoordinator(logStore: SQLiteLogStore.shared)
        self.browserRegistry = BrowserControllerRegistry.shared
    }
}
