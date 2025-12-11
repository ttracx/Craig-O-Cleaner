// MARK: - BrowserAutomationServiceTests.swift
// CraigOClean Control Center - Unit Tests for BrowserAutomationService

import XCTest
@testable import Craig_O_Clean

@MainActor
final class BrowserAutomationServiceTests: XCTestCase {
    
    var sut: BrowserAutomationService!
    
    override func setUp() async throws {
        sut = BrowserAutomationService()
    }
    
    override func tearDown() async throws {
        sut.stopAutoRefresh()
        sut = nil
    }
    
    // MARK: - Browser Detection Tests
    
    func testDetectInstalledBrowsers() {
        sut.detectInstalledBrowsers()
        
        // We can't assert specific browsers are installed,
        // but we can verify the list is populated with valid browsers
        for browser in sut.installedBrowsers {
            XCTAssertTrue(SupportedBrowser.allCases.contains(browser), "Installed browser should be a supported type")
        }
    }
    
    func testUpdateRunningBrowsers() {
        sut.detectInstalledBrowsers()
        sut.updateRunningBrowsers()
        
        // Running browsers should be a subset of installed browsers
        for browser in sut.runningBrowsers {
            XCTAssertTrue(sut.installedBrowsers.contains(browser), "Running browser should be an installed browser")
        }
    }
    
    // MARK: - Browser Properties Tests
    
    func testSupportedBrowserProperties() {
        for browser in SupportedBrowser.allCases {
            XCTAssertFalse(browser.rawValue.isEmpty, "Browser should have a name")
            XCTAssertFalse(browser.bundleIdentifier.isEmpty, "Browser should have a bundle identifier")
            XCTAssertFalse(browser.icon.isEmpty, "Browser should have an icon")
        }
    }
    
    func testSupportedBrowserTabScripting() {
        // Verify which browsers support tab scripting
        XCTAssertTrue(SupportedBrowser.safari.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.chrome.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.edge.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.brave.supportsTabScripting)
        XCTAssertTrue(SupportedBrowser.arc.supportsTabScripting)
        XCTAssertFalse(SupportedBrowser.firefox.supportsTabScripting)
    }
    
    // MARK: - Tab Model Tests
    
    func testBrowserTabModel() {
        let tab = BrowserTab(
            id: "safari-1-1",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Apple - Start",
            url: "https://www.apple.com/",
            isActive: true
        )
        
        XCTAssertEqual(tab.id, "safari-1-1")
        XCTAssertEqual(tab.browser, .safari)
        XCTAssertEqual(tab.windowIndex, 1)
        XCTAssertEqual(tab.tabIndex, 1)
        XCTAssertEqual(tab.title, "Apple - Start")
        XCTAssertEqual(tab.url, "https://www.apple.com/")
        XCTAssertTrue(tab.isActive)
    }
    
    func testBrowserTabDomainExtraction() {
        let tab1 = BrowserTab(
            id: "test1",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test",
            url: "https://www.example.com/path/page",
            isActive: false
        )
        XCTAssertEqual(tab1.domain, "www.example.com")
        
        let tab2 = BrowserTab(
            id: "test2",
            browser: .chrome,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test",
            url: "https://subdomain.example.org:8080/",
            isActive: false
        )
        XCTAssertEqual(tab2.domain, "subdomain.example.org")
        
        let tab3 = BrowserTab(
            id: "test3",
            browser: .edge,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test",
            url: "invalid-url",
            isActive: false
        )
        XCTAssertEqual(tab3.domain, "")
    }
    
    func testBrowserTabFaviconURL() {
        let tab = BrowserTab(
            id: "test",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test",
            url: "https://www.apple.com/products/",
            isActive: false
        )
        
        let expectedFavicon = URL(string: "https://www.apple.com/favicon.ico")
        XCTAssertEqual(tab.faviconURL, expectedFavicon)
    }
    
    // MARK: - Window Model Tests
    
    func testBrowserWindowModel() {
        let tabs = [
            BrowserTab(id: "1", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab 1", url: "https://example.com", isActive: true),
            BrowserTab(id: "2", browser: .safari, windowIndex: 1, tabIndex: 2, title: "Tab 2", url: "https://example.org", isActive: false)
        ]
        
        let window = BrowserWindow(
            id: "safari-window-1",
            browser: .safari,
            windowIndex: 1,
            title: "Safari Window",
            tabs: tabs,
            activeTabIndex: 1
        )
        
        XCTAssertEqual(window.id, "safari-window-1")
        XCTAssertEqual(window.browser, .safari)
        XCTAssertEqual(window.windowIndex, 1)
        XCTAssertEqual(window.tabCount, 2)
        XCTAssertEqual(window.activeTabIndex, 1)
    }
    
    // MARK: - Statistics Tests
    
    func testGetTabStatistics() {
        // Since we can't guarantee browser state, just verify the method returns valid data
        let stats = sut.getTabStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.total, 0)
        XCTAssertNotNil(stats.byBrowser)
        XCTAssertNotNil(stats.byDomain)
    }
    
    func testGetTopDomains() {
        let topDomains = sut.getTopDomains(limit: 5)
        
        XCTAssertLessThanOrEqual(topDomains.count, 5)
        
        // Verify sorted by count (descending)
        for i in 0..<(topDomains.count - 1) {
            XCTAssertGreaterThanOrEqual(topDomains[i].count, topDomains[i + 1].count)
        }
    }
    
    // MARK: - Tab Aggregation Tests
    
    func testAllTabs() {
        // AllTabs should aggregate tabs from all browsers
        let allTabs = sut.allTabs
        
        // Verify each tab belongs to a browser in browserTabs
        for tab in allTabs {
            XCTAssertTrue(SupportedBrowser.allCases.contains(tab.browser))
        }
    }
    
    func testTotalTabCount() {
        let totalFromAllTabs = sut.allTabs.count
        let totalFromProperty = sut.totalTabCount
        
        XCTAssertEqual(totalFromAllTabs, totalFromProperty)
    }
    
    func testTabsByDomain() {
        let grouped = sut.tabsByDomain
        
        // Verify all tabs are accounted for
        let totalGrouped = grouped.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalGrouped, sut.totalTabCount)
    }
    
    // MARK: - Error Handling Tests
    
    func testBrowserAutomationErrorDescriptions() {
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
            XCTAssertNotNil(error.errorDescription, "Error should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Heavy Tabs Tests
    
    func testGetHeavyTabs() {
        let heavyTabs = sut.getHeavyTabs(limit: 10)
        
        XCTAssertLessThanOrEqual(heavyTabs.count, 10)
    }
    
    // MARK: - Auto Refresh Tests
    
    func testAutoRefreshStartStop() {
        sut.startAutoRefresh(interval: 10.0)
        // Can't easily verify timer is running without internal access
        
        sut.stopAutoRefresh()
        // Just verify no crash
    }
}
