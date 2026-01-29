// File: CraigOClean-vNext/CraigOClean/App/AppEnvironment.swift
// Craig-O-Clean - App Environment
// Central configuration and environment detection

import Foundation
import SwiftUI

/// Central environment configuration for the application
@MainActor
public final class AppEnvironment: ObservableObject {

    // MARK: - Singleton

    public static let shared = AppEnvironment()

    // MARK: - Published Properties

    @Published public private(set) var edition: AppEdition
    @Published public private(set) var capabilities: Capabilities

    // MARK: - App Info

    public let appName = "Craig-O-Clean"
    public let bundleIdentifier: String
    public let version: String
    public let build: String

    // MARK: - Paths

    public let applicationSupportDirectory: URL
    public let logsDirectory: URL
    public let cacheDirectory: URL

    // MARK: - Initialization

    private init() {
        // Determine edition from build flags
        self.edition = AppEdition.current

        // Get capabilities for this edition
        let provider = CapabilityProviderFactory.current()
        self.capabilities = provider.capabilities

        // Get bundle info
        let bundle = Bundle.main
        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.craigosoft.CraigOClean"
        self.version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        // Set up directories
        let fileManager = FileManager.default

        // Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.applicationSupportDirectory = appSupport.appendingPathComponent("CraigOClean")

        // Logs directory
        self.logsDirectory = applicationSupportDirectory.appendingPathComponent("logs")

        // Cache directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent(bundleIdentifier)

        // Create directories if needed
        try? fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Computed Properties

    /// Full version string for display
    public var fullVersionString: String {
        "\(version) (\(build))"
    }

    /// Edition display name
    public var editionDisplayName: String {
        edition.displayName
    }

    /// Whether this is the Pro edition
    public var isPro: Bool {
        edition == .directPro
    }

    /// Whether this is the Lite edition
    public var isLite: Bool {
        edition == .appStoreLite
    }

    // MARK: - Capability Checks

    /// Check if a specific capability is available
    public func hasCapability(_ keyPath: KeyPath<Capabilities, Bool>) -> Bool {
        capabilities[keyPath: keyPath]
    }

    /// Get capability info for UI display
    public func capabilityInfo() -> [Capabilities.CapabilityInfo] {
        capabilities.allCapabilities(edition: edition)
    }

    // MARK: - Debug Info

    #if DEBUG
    public var isDebug: Bool { true }
    #else
    public var isDebug: Bool { false }
    #endif

    public func debugInfo() -> [String: String] {
        [
            "Edition": edition.rawValue,
            "Version": fullVersionString,
            "Bundle ID": bundleIdentifier,
            "Debug": isDebug ? "Yes" : "No",
            "App Support": applicationSupportDirectory.path,
            "Logs": logsDirectory.path
        ]
    }
}

// MARK: - Environment Key

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.shared
}

extension EnvironmentValues {
    public var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    public func withAppEnvironment(_ environment: AppEnvironment = .shared) -> some View {
        self.environment(\.appEnvironment, environment)
            .environmentObject(environment)
    }
}
