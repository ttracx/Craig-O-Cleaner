//
//  BrowserOperationsTests.swift
//  CraigOTerminatorTests
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import XCTest
@testable import CraigOTerminator

// MARK: - Mock Browser Controller

final class MockBrowserController: BrowserController {
    let app: BrowserApp

    var isInstalledResult = true
    var isRunningResult = true
    var getAllTabsResult: [BrowserTab] = []
    var closeTabsResult = 0
    var tabCountResult = 0
    var quitCalled = false
    var forceQuitCalled = false

    init(app: BrowserApp) {
        self.app = app
    }

    func isInstalled() -> Bool {
        return isInstalledResult
    }

    func isRunning() async -> Bool {
        return isRunningResult
    }

    func getAllTabs() async throws -> [BrowserTab] {
        return getAllTabsResult
    }

    func closeTabs(matching pattern: String) async throws -> Int {
        return closeTabsResult
    }

    func closeTab(byIndex windowIndex: Int, tabIndex: Int) async throws {
        // Mock implementation
    }

    func tabCount() async throws -> Int {
        return tabCountResult
    }

    func getHeavyTabs() async throws -> [BrowserTab] {
        // Return tabs matching heavy patterns
        let heavyPatterns = ["youtube.com", "twitch.tv", "netflix.com"]
        return getAllTabsResult.filter { tab in
            heavyPatterns.contains { pattern in
                tab.url.localizedCaseInsensitiveContains(pattern)
            }
        }
    }

    func closeAllTabs(except whitelist: [String]) async throws -> Int {
        return getAllTabsResult.count
    }

    func quit() async throws {
        quitCalled = true
    }

    func forceQuit() async throws {
        forceQuitCalled = true
    }
}

// MARK: - Browser Controller Tests

final class BrowserControllerTests: XCTestCase {

    // MARK: - Browser Tab Model Tests

    func testBrowserTabCreation() {
        let tab = BrowserTab(
            url: "https://example.com",
            title: "Example",
            windowIndex: 0,
            tabIndex: 0
        )

        XCTAssertEqual(tab.url, "https://example.com")
        XCTAssertEqual(tab.title, "Example")
        XCTAssertEqual(tab.windowIndex, 0)
        XCTAssertEqual(tab.tabIndex, 0)
        XCTAssertNil(tab.memoryUsage)
    }

    func testBrowserTabMemoryUsageFormatting() {
        let tab = BrowserTab(
            url: "https://example.com",
            title: "Example",
            windowIndex: 0,
            tabIndex: 0,
            memoryUsage: 104_857_600 // 100 MB
        )

        XCTAssertEqual(tab.memoryUsageFormatted, "100.0 MB")
    }

    func testBrowserTabMemoryUsageFormattingWhenNil() {
        let tab = BrowserTab(
            url: "https://example.com",
            title: "Example",
            windowIndex: 0,
            tabIndex: 0
        )

        XCTAssertNil(tab.memoryUsageFormatted)
    }

    // MARK: - Browser Error Tests

    func testBrowserErrorDescriptions() {
        let notInstalledError = BrowserError.browserNotInstalled(.safari)
        XCTAssertTrue(notInstalledError.errorDescription?.contains("not installed") ?? false)

        let notRunningError = BrowserError.browserNotRunning(.chrome)
        XCTAssertTrue(notRunningError.errorDescription?.contains("not currently running") ?? false)

        let permissionError = BrowserError.permissionDenied(.firefox)
        XCTAssertTrue(permissionError.errorDescription?.contains("permission denied") ?? false)

        let notSupportedError = BrowserError.operationNotSupported(.firefox, operation: "Tab listing")
        XCTAssertTrue(notSupportedError.errorDescription?.contains("not supported") ?? false)
    }

    // MARK: - Mock Controller Tests

    func testMockControllerInstallation() {
        let mock = MockBrowserController(app: .safari)
        XCTAssertTrue(mock.isInstalled())

        mock.isInstalledResult = false
        XCTAssertFalse(mock.isInstalled())
    }

    func testMockControllerRunningState() async {
        let mock = MockBrowserController(app: .chrome)
        let isRunning = await mock.isRunning()
        XCTAssertTrue(isRunning)

        mock.isRunningResult = false
        let isNotRunning = await mock.isRunning()
        XCTAssertFalse(isNotRunning)
    }

    func testMockControllerTabCount() async throws {
        let mock = MockBrowserController(app: .safari)
        mock.tabCountResult = 5

        let count = try await mock.tabCount()
        XCTAssertEqual(count, 5)
    }

    func testMockControllerGetAllTabs() async throws {
        let mock = MockBrowserController(app: .chrome)

        let tabs = [
            BrowserTab(url: "https://example.com", title: "Example", windowIndex: 0, tabIndex: 0),
            BrowserTab(url: "https://google.com", title: "Google", windowIndex: 0, tabIndex: 1)
        ]
        mock.getAllTabsResult = tabs

        let result = try await mock.getAllTabs()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].url, "https://example.com")
        XCTAssertEqual(result[1].url, "https://google.com")
    }

    func testMockControllerCloseTabs() async throws {
        let mock = MockBrowserController(app: .safari)
        mock.closeTabsResult = 3

        let closed = try await mock.closeTabs(matching: "youtube.com")
        XCTAssertEqual(closed, 3)
    }

    func testMockControllerQuit() async throws {
        let mock = MockBrowserController(app: .firefox)
        XCTAssertFalse(mock.quitCalled)

        try await mock.quit()
        XCTAssertTrue(mock.quitCalled)
    }

    func testMockControllerForceQuit() async throws {
        let mock = MockBrowserController(app: .brave)
        XCTAssertFalse(mock.forceQuitCalled)

        try await mock.forceQuit()
        XCTAssertTrue(mock.forceQuitCalled)
    }

    // MARK: - Heavy Tab Detection Tests

    func testHeavyTabDetection() async throws {
        let mock = MockBrowserController(app: .chrome)

        let tabs = [
            BrowserTab(url: "https://youtube.com/watch?v=123", title: "YouTube", windowIndex: 0, tabIndex: 0),
            BrowserTab(url: "https://example.com", title: "Example", windowIndex: 0, tabIndex: 1),
            BrowserTab(url: "https://twitch.tv/channel", title: "Twitch", windowIndex: 0, tabIndex: 2),
            BrowserTab(url: "https://google.com", title: "Google", windowIndex: 0, tabIndex: 3)
        ]
        mock.getAllTabsResult = tabs

        let heavyTabs = try await mock.getHeavyTabs()
        XCTAssertEqual(heavyTabs.count, 2)
        XCTAssertTrue(heavyTabs.contains { $0.url.contains("youtube.com") })
        XCTAssertTrue(heavyTabs.contains { $0.url.contains("twitch.tv") })
    }

    func testHeavyTabDetectionCaseInsensitive() async throws {
        let mock = MockBrowserController(app: .safari)

        let tabs = [
            BrowserTab(url: "https://YOUTUBE.COM/watch", title: "YouTube", windowIndex: 0, tabIndex: 0),
            BrowserTab(url: "https://Netflix.com/watch", title: "Netflix", windowIndex: 0, tabIndex: 1)
        ]
        mock.getAllTabsResult = tabs

        let heavyTabs = try await mock.getHeavyTabs()
        XCTAssertEqual(heavyTabs.count, 2)
    }

    func testHeavyTabDetectionNoHeavyTabs() async throws {
        let mock = MockBrowserController(app: .firefox)

        let tabs = [
            BrowserTab(url: "https://example.com", title: "Example", windowIndex: 0, tabIndex: 0),
            BrowserTab(url: "https://google.com", title: "Google", windowIndex: 0, tabIndex: 1)
        ]
        mock.getAllTabsResult = tabs

        let heavyTabs = try await mock.getHeavyTabs()
        XCTAssertEqual(heavyTabs.count, 0)
    }

    // MARK: - Close All Tabs Tests

    func testCloseAllTabs() async throws {
        let mock = MockBrowserController(app: .chrome)

        let tabs = [
            BrowserTab(url: "https://youtube.com", title: "YouTube", windowIndex: 0, tabIndex: 0),
            BrowserTab(url: "https://example.com", title: "Example", windowIndex: 0, tabIndex: 1),
            BrowserTab(url: "https://google.com", title: "Google", windowIndex: 0, tabIndex: 2)
        ]
        mock.getAllTabsResult = tabs

        let closed = try await mock.closeAllTabs(except: [])
        XCTAssertEqual(closed, 3)
    }

    // MARK: - Browser App Enum Tests

    func testBrowserAppBundleIdentifiers() {
        XCTAssertEqual(BrowserApp.safari.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(BrowserApp.chrome.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(BrowserApp.edge.bundleIdentifier, "com.microsoft.edgemac")
        XCTAssertEqual(BrowserApp.brave.bundleIdentifier, "com.brave.Browser")
        XCTAssertEqual(BrowserApp.firefox.bundleIdentifier, "org.mozilla.firefox")
        XCTAssertEqual(BrowserApp.arc.bundleIdentifier, "company.thebrowser.Browser")
    }

    func testBrowserAppIcons() {
        XCTAssertEqual(BrowserApp.safari.icon, "safari")
        XCTAssertEqual(BrowserApp.chrome.icon, "globe")
        XCTAssertEqual(BrowserApp.brave.icon, "shield")
        XCTAssertEqual(BrowserApp.firefox.icon, "flame")
    }

    func testBrowserAppAllCases() {
        let allBrowsers = BrowserApp.allCases
        XCTAssertEqual(allBrowsers.count, 6)
        XCTAssertTrue(allBrowsers.contains(.safari))
        XCTAssertTrue(allBrowsers.contains(.chrome))
        XCTAssertTrue(allBrowsers.contains(.edge))
        XCTAssertTrue(allBrowsers.contains(.brave))
        XCTAssertTrue(allBrowsers.contains(.firefox))
        XCTAssertTrue(allBrowsers.contains(.arc))
    }

    // MARK: - Browser Info Tests

    func testBrowserInfoCreation() {
        let info = BrowserInfo(
            id: "com.apple.Safari",
            app: .safari,
            isInstalled: true,
            isRunning: true,
            tabCount: 10,
            hasPermission: true
        )

        XCTAssertEqual(info.displayName, "Safari")
        XCTAssertEqual(info.icon, "safari")
        XCTAssertTrue(info.isInstalled)
        XCTAssertTrue(info.isRunning)
        XCTAssertEqual(info.tabCount, 10)
        XCTAssertTrue(info.hasPermission)
    }
}
