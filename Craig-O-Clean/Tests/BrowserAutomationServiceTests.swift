// BrowserAutomationServiceTests.swift
// ClearMind Control Center Tests
//
// Unit tests for BrowserAutomationService

import XCTest
@testable import Craig_O_Clean

final class BrowserAutomationServiceTests: XCTestCase {
    
    var sut: BrowserAutomationService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        sut = BrowserAutomationService()
    }
    
    @MainActor
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Browser Detection Tests
    
    @MainActor
    func testInstalledBrowsersNotEmpty() {
        // When
        sut.detectInstalledBrowsers()
        
        // Then - At least Safari should be installed on any Mac
        XCTAssertFalse(sut.installedBrowsers.isEmpty, "At least one browser should be installed")
    }
    
    @MainActor
    func testSafariIsDetectedAsInstalled() {
        // When
        sut.detectInstalledBrowsers()
        
        // Then - Safari should be installed on any Mac
        XCTAssertTrue(sut.installedBrowsers.contains(.safari), "Safari should be detected as installed")
    }
    
    @MainActor
    func testRunningBrowsersIsSubsetOfInstalled() {
        // When
        sut.detectInstalledBrowsers()
        sut.updateRunningBrowsers()
        
        // Then
        for browser in sut.runningBrowsers {
            XCTAssertTrue(sut.installedBrowsers.contains(browser), 
                         "Running browser \(browser.rawValue) should be in installed list")
        }
    }
    
    // MARK: - Browser Type Tests
    
    func testBrowserTypeBundleIdentifiers() {
        // Test Safari
        XCTAssertEqual(BrowserType.safari.bundleIdentifier, "com.apple.Safari")
        
        // Test Chrome
        XCTAssertEqual(BrowserType.chrome.bundleIdentifier, "com.google.Chrome")
        
        // Test Edge
        XCTAssertEqual(BrowserType.edge.bundleIdentifier, "com.microsoft.edgemac")
        
        // Test Brave
        XCTAssertEqual(BrowserType.brave.bundleIdentifier, "com.brave.Browser")
    }
    
    func testChromiumBasedBrowsers() {
        // Chromium-based
        XCTAssertTrue(BrowserType.chrome.isChromiumBased)
        XCTAssertTrue(BrowserType.edge.isChromiumBased)
        XCTAssertTrue(BrowserType.brave.isChromiumBased)
        
        // Not Chromium-based
        XCTAssertFalse(BrowserType.safari.isChromiumBased)
        XCTAssertFalse(BrowserType.firefox.isChromiumBased)
    }
    
    func testSupportedBrowsersForTabManagement() {
        // Supported
        XCTAssertTrue(BrowserType.safari.supportsTabManagement)
        XCTAssertTrue(BrowserType.chrome.supportsTabManagement)
        XCTAssertTrue(BrowserType.edge.supportsTabManagement)
        XCTAssertTrue(BrowserType.brave.supportsTabManagement)
        
        // Not supported
        XCTAssertFalse(BrowserType.arc.supportsTabManagement)
        XCTAssertFalse(BrowserType.firefox.supportsTabManagement)
    }
    
    // MARK: - Tab Model Tests
    
    func testBrowserTabDomainExtraction() {
        // Given
        let tab = BrowserTab(
            id: "test-1",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test Tab",
            url: "https://www.example.com/path/to/page"
        )
        
        // Then
        XCTAssertEqual(tab.domain, "www.example.com")
    }
    
    func testBrowserTabDomainExtractionWithoutWWW() {
        // Given
        let tab = BrowserTab(
            id: "test-2",
            browser: .chrome,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test Tab",
            url: "https://example.com/page"
        )
        
        // Then
        XCTAssertEqual(tab.domain, "example.com")
    }
    
    func testBrowserTabDomainWithInvalidURL() {
        // Given
        let tab = BrowserTab(
            id: "test-3",
            browser: .safari,
            windowIndex: 1,
            tabIndex: 1,
            title: "Test Tab",
            url: "not-a-valid-url"
        )
        
        // Then
        XCTAssertEqual(tab.domain, "")
    }
    
    func testBrowserWindowTabCount() {
        // Given
        let tabs = [
            BrowserTab(id: "1", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab 1", url: "https://example.com"),
            BrowserTab(id: "2", browser: .safari, windowIndex: 1, tabIndex: 2, title: "Tab 2", url: "https://example.com"),
            BrowserTab(id: "3", browser: .safari, windowIndex: 1, tabIndex: 3, title: "Tab 3", url: "https://example.com")
        ]
        
        let window = BrowserWindow(
            id: "window-1",
            browser: .safari,
            windowIndex: 1,
            title: "Test Window",
            tabs: tabs
        )
        
        // Then
        XCTAssertEqual(window.tabCount, 3)
    }
    
    // MARK: - Statistics Tests
    
    @MainActor
    func testTotalTabCountIsCorrect() {
        // Given - manually set tabs for testing
        // Note: In a real test, we'd use dependency injection to mock the tabs
        
        // Then
        XCTAssertEqual(sut.totalTabCount, sut.allTabs.count)
    }
    
    @MainActor
    func testUniqueDomains() {
        // The unique domains should never be nil
        XCTAssertNotNil(sut.uniqueDomains)
    }
}

// MARK: - Browser Tab Model Tests

final class BrowserTabModelTests: XCTestCase {
    
    func testBrowserTabEquality() {
        // Given
        let tab1 = BrowserTab(id: "test-id", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab", url: "https://example.com")
        let tab2 = BrowserTab(id: "test-id", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab", url: "https://example.com")
        let tab3 = BrowserTab(id: "different-id", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab", url: "https://example.com")
        
        // Then
        XCTAssertEqual(tab1, tab2, "Tabs with same ID should be equal")
        XCTAssertNotEqual(tab1, tab3, "Tabs with different IDs should not be equal")
    }
    
    func testBrowserTabHashValue() {
        // Given
        let tab1 = BrowserTab(id: "test-id", browser: .safari, windowIndex: 1, tabIndex: 1, title: "Tab", url: "https://example.com")
        let tab2 = BrowserTab(id: "test-id", browser: .chrome, windowIndex: 2, tabIndex: 2, title: "Different", url: "https://different.com")
        
        // Then - same ID should produce same hash
        XCTAssertEqual(tab1.hashValue, tab2.hashValue)
    }
}
