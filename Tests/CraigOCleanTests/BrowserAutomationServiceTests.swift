// MARK: - BrowserAutomationServiceTests.swift
// Craig-O-Clean - Unit Tests for Browser Automation Service
// Tests browser detection, tab management, and AppleScript automation

import XCTest
@testable import Craig_O_Clean

@MainActor
final class BrowserAutomationServiceTests: XCTestCase {
    
    var service: BrowserAutomationService!
    
    override func setUp() {
        super.setUp()
        service = BrowserAutomationService()
    }
    
    override func tearDown() {
        service.stopAutoRefresh()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isLoading, "Should not be loading on init")
        XCTAssertNil(service.lastError, "Should have no error on init")
    }
    
    // MARK: - Browser Detection Tests
    
    func testDetectInstalledBrowsers() {
        service.detectInstalledBrowsers()
        
        // At least Safari should be installed on macOS
        XCTAssertFalse(service.installedBrowsers.isEmpty, "Should detect at least one browser")
        XCTAssertTrue(service.installedBrowsers.contains(.safari), "Safari should be detected on macOS")
    }
    
    func testUpdateRunningBrowsers() {
        service.detectInstalledBrowsers()
        service.updateRunningBrowsers()
        
        // Running browsers should be subset of installed browsers
        for browser in service.runningBrowsers {
            XCTAssertTrue(service.installedBrowsers.contains(browser), "Running browser should be installed")
        }
    }
    
    // MARK: - Browser Enum Tests
    
    func testSupportedBrowserProperties() {
        for browser in SupportedBrowser.allCases {
            XCTAssertFalse(browser.rawValue.isEmpty, "Browser \(browser) should have name")
            XCTAssertFalse(browser.bundleIdentifier.isEmpty, "Browser \(browser) should have bundle ID")
            XCTAssertFalse(browser.icon.isEmpty, "Browser \(browser) should have icon")
        }
    }
    
    func testBrowserBundleIdentifiers() {
        XCTAssertEqual(SupportedBrowser.safari.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(SupportedBrowser.chrome.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(SupportedBrowser.edge.bundleIdentifier, "com.microsoft.edgemac")
        XCTAssertEqual(SupportedBrowser.brave.bundleIdentifier, "com.brave.Browser")
        XCTAssertEqual(SupportedBrowser.arc.bundleIdentifier, "company.thebrowser.Browser")
    }
    
    func testBrowserScriptingSupport() {
        XCTAssertTrue(SupportedBrowser.safari.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.chrome.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.edge.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.brave.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.arc.supportsTabScripting)
        XCTAssertFalse(SupportedBrowser.firefox.supportsTabScripting)
    }
    
    // MARK: - Tab Statistics Tests
    
    func testAllTabsComputation() {
        // allTabs should return flattened array from all browser windows
        let allTabs = service.allTabs
        XCTAssertNotNil(allTabs, "allTabs should not be nil")
    }
    
    func testTotalTabCount() {
        let count = service.totalTabCount
        XCTAssertGreaterThanOrEqual(count, 0, "Tab count should be non-negative")
    }
    
    func testTabsByDomain() {
        let byDomain = service.tabsByDomain
        XCTAssertNotNil(byDomain, "tabsByDomain should not be nil")
    }
    
    func testGetTabStatistics() {
        let stats = service.getTabStatistics()
        XCTAssertGreaterThanOrEqual(stats.total, 0, "Total should be non-negative")
    }
    
    func testGetTopDomains() {
        let topDomains = service.getTopDomains(limit: 5)
        XCTAssertLessThanOrEqual(topDomains.count, 5, "Should return at most 5 domains")
    }
    
    func testGetHeavyTabs() {
        let heavyTabs = service.getHeavyTabs(limit: 10)
        XCTAssertLessThanOrEqual(heavyTabs.count, 10, "Should return at most 10 heavy tabs")
    }
    
    // MARK: - BrowserTab Model Tests
    
    func testBrowserTabDomain() {
        let tab = BrowserTab(
            id: "test-1-1",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test",
            url: "https://www.example.com/path/to/page",
            isActive: true
        )
        
        XCTAssertEqual(tab.domain, "www.example.com")
    }
    
    func testBrowserTabFavicon() {
        let tab = BrowserTab(
            id: "test-1-1",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test",
            url: "https://www.example.com/path",
            isActive: true
        )
        
        XCTAssertNotNil(tab.faviconURL, "Favicon URL should be generated")
        XCTAssertEqual(tab.faviconURL?.absoluteString, "https://www.example.com/favicon.ico")
    }
    
    // MARK: - BrowserWindow Model Tests
    
    func testBrowserWindowTabCount() {
        let tabs = [
            BrowserTab(id: "1", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab 1", url: "https://a.com", isActive: true),
            BrowserTab(id: "2", browser: .safari, windowIndex: 1, tabIndex: 2, title: "Tab 2", url: "https://b.com", isActive: false)
        ]
        
        let window = BrowserWindow(
            id: "safari-window-1",
            browser: .safari,
            windowIndex: 1,
            title: "Safari Window",
            tabs: tabs,
            activeTabIndex: 1
        )
        
        XCTAssertEqual(window.tabCount, 2)
    }
    
    // MARK: - Error Types Tests
    
    func testBrowserAutomationErrors() {
        let errors: [BrowserAutomationError] = [
            .browserNotInstalled(.safari),
            .browserNotRunning(.chrome),
            .automationPermissionDenied(.edge),
            .scriptExecutionFailed("Test error"),
            .parseError("Parse failed"),
            .unsupportedBrowser(.firefox),
            .tabNotFound,
            .windowNotFound
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Auto Refresh Tests
    
    func testStartAutoRefresh() {
        service.startAutoRefresh(interval: 10.0)
        // Just verify it doesn't crash
        service.stopAutoRefresh()
    }
    
    func testStopAutoRefresh() {
        service.startAutoRefresh(interval: 10.0)
        service.stopAutoRefresh()
        // Just verify it doesn't crash
    }
}
