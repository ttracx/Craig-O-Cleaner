//
//  BrowserManager.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI
import AppKit
import os.log

// MARK: - Browser Info

/// Information about an installed browser
struct BrowserInfo: Identifiable {
    let id: String
    let app: BrowserApp
    let isInstalled: Bool
    let isRunning: Bool
    let tabCount: Int
    let hasPermission: Bool

    var displayName: String { app.rawValue }
    var icon: String { app.icon }
}

// MARK: - Browser Manager

/// Factory and coordinator for browser controllers
@Observable
final class BrowserManager {

    // MARK: - State

    /// Cached browser information
    var browsers: [BrowserInfo] = []

    /// Last refresh timestamp
    var lastRefreshDate: Date?

    /// Whether refresh is in progress
    var isRefreshing: Bool = false

    // MARK: - Dependencies

    private let permissionCenter: PermissionCenter
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "BrowserManager")

    // MARK: - Controllers

    private let safariController = SafariController()
    private let chromeController = ChromeController()
    private let edgeController = EdgeController()
    private let braveController = BraveController()
    private let arcController = ArcController()
    private let firefoxController = FirefoxController()

    // MARK: - Initialization

    init(permissionCenter: PermissionCenter = .shared) {
        self.permissionCenter = permissionCenter
    }

    // MARK: - Factory Methods

    /// Get controller for specific browser
    func controller(for app: BrowserApp) -> BrowserController {
        switch app {
        case .safari: return safariController
        case .chrome: return chromeController
        case .edge: return edgeController
        case .brave: return braveController
        case .arc: return arcController
        case .firefox: return firefoxController
        }
    }

    /// Get all installed browsers
    func installedBrowsers() -> [BrowserApp] {
        BrowserApp.allCases.filter { app in
            controller(for: app).isInstalled()
        }
    }

    // MARK: - Browser Information

    /// Refresh information for all browsers
    func refreshAll() async {
        guard !isRefreshing else { return }

        await MainActor.run {
            isRefreshing = true
        }

        logger.info("Refreshing browser information")

        var newBrowsers: [BrowserInfo] = []

        for app in BrowserApp.allCases {
            let controller = self.controller(for: app)
            let isInstalled = controller.isInstalled()

            guard isInstalled else {
                // Browser not installed - skip
                continue
            }

            let isRunning = await controller.isRunning()
            let tabCount = (try? await controller.tabCount()) ?? 0
            let hasPermission = permissionCenter.automationPermissions[app] == .granted

            let info = BrowserInfo(
                id: app.bundleIdentifier,
                app: app,
                isInstalled: isInstalled,
                isRunning: isRunning,
                tabCount: tabCount,
                hasPermission: hasPermission
            )

            newBrowsers.append(info)
        }

        let browsersToSet = newBrowsers
        await MainActor.run {
            self.browsers = browsersToSet
            self.lastRefreshDate = Date()
            self.isRefreshing = false
        }

        logger.info("Browser refresh complete: \(newBrowsers.count) browsers found")
    }

    /// Get tab count for specific browser
    func getTabCount(for app: BrowserApp) async -> Int {
        let controller = controller(for: app)

        guard controller.isInstalled() else {
            return 0
        }

        guard await controller.isRunning() else {
            return 0
        }

        return (try? await controller.tabCount()) ?? 0
    }

    // MARK: - Tab Operations

    /// Get all tabs from a specific browser
    func getAllTabs(from app: BrowserApp) async throws -> [BrowserTab] {
        let controller = controller(for: app)

        // Check permission first
        let permissionState = permissionCenter.automationPermissions[app] ?? .unknown
        guard permissionState == .granted else {
            throw BrowserError.permissionDenied(app)
        }

        return try await controller.getAllTabs()
    }

    /// Close tabs matching pattern in specific browser
    func closeTabs(in app: BrowserApp, matching pattern: String) async throws -> Int {
        let controller = controller(for: app)

        // Check permission first
        let permissionState = permissionCenter.automationPermissions[app] ?? .unknown
        guard permissionState == .granted else {
            throw BrowserError.permissionDenied(app)
        }

        return try await controller.closeTabs(matching: pattern)
    }

    /// Close heavy tabs in specific browser
    func closeHeavyTabs(in app: BrowserApp) async throws -> Int {
        let controller = controller(for: app)

        // Check permission first
        let permissionState = permissionCenter.automationPermissions[app] ?? .unknown
        guard permissionState == .granted else {
            throw BrowserError.permissionDenied(app)
        }

        let heavyTabs = try await controller.getHeavyTabs()

        var closedCount = 0
        for tab in heavyTabs {
            try await controller.closeTab(byIndex: tab.windowIndex, tabIndex: tab.tabIndex)
            closedCount += 1
        }

        return closedCount
    }

    /// Close all tabs in specific browser
    func closeAllTabs(in app: BrowserApp, except whitelist: [String] = []) async throws -> Int {
        let controller = controller(for: app)

        // Check permission first
        let permissionState = permissionCenter.automationPermissions[app] ?? .unknown
        guard permissionState == .granted else {
            throw BrowserError.permissionDenied(app)
        }

        return try await controller.closeAllTabs(except: whitelist)
    }

    /// Get heavy tabs from specific browser
    func getHeavyTabs(from app: BrowserApp) async throws -> [BrowserTab] {
        let controller = controller(for: app)

        // Check permission first
        let permissionState = permissionCenter.automationPermissions[app] ?? .unknown
        guard permissionState == .granted else {
            throw BrowserError.permissionDenied(app)
        }

        return try await controller.getHeavyTabs()
    }

    // MARK: - Browser Control

    /// Quit specific browser
    func quit(_ app: BrowserApp) async throws {
        let controller = controller(for: app)

        // Check permission first (might not be needed for quit, but be safe)
        let permissionState = permissionCenter.automationPermissions[app] ?? .unknown
        guard permissionState == .granted else {
            throw BrowserError.permissionDenied(app)
        }

        try await controller.quit()
    }

    /// Force quit specific browser
    func forceQuit(_ app: BrowserApp) async throws {
        let controller = controller(for: app)
        try await controller.forceQuit()
    }

    // MARK: - Permission Helpers

    /// Check if browser has automation permission
    func hasPermission(for app: BrowserApp) -> Bool {
        return permissionCenter.automationPermissions[app] == .granted
    }

    /// Request permission for specific browser
    func requestPermission(for app: BrowserApp) async {
        _ = await permissionCenter.requestAutomationPermission(for: app)
        await permissionCenter.refreshAll()
        await refreshAll()
    }
}
