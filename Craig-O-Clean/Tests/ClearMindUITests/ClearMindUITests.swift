// MARK: - ClearMindUITests.swift
// ClearMind Control Center - UI Tests
// Tests for the main application UI flows

import XCTest

final class ClearMindUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationSidebar() throws {
        // Verify sidebar items are visible
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "Sidebar should exist")
        
        // Test navigation to each section
        let sections = ["Dashboard", "Processes", "Memory Cleanup", "Browser Tabs", "Settings"]
        
        for section in sections {
            let item = app.staticTexts[section]
            if item.exists {
                item.tap()
                // Give time for view to load
                sleep(1)
            }
        }
    }
    
    func testDashboardLoads() throws {
        // Navigate to Dashboard (should be default)
        let dashboardText = app.staticTexts["System Health"]
        XCTAssertTrue(dashboardText.waitForExistence(timeout: 5), "Dashboard should show System Health")
    }
    
    // MARK: - Dashboard Tests
    
    func testDashboardShowsMetrics() throws {
        // Verify CPU card exists
        let cpuCard = app.staticTexts["CPU"]
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "CPU card should exist")
        
        // Verify Memory card exists
        let memoryCard = app.staticTexts["Memory"]
        XCTAssertTrue(memoryCard.waitForExistence(timeout: 5), "Memory card should exist")
        
        // Verify Disk card exists
        let diskCard = app.staticTexts["Disk"]
        XCTAssertTrue(diskCard.waitForExistence(timeout: 5), "Disk card should exist")
        
        // Verify Network card exists
        let networkCard = app.staticTexts["Network"]
        XCTAssertTrue(networkCard.waitForExistence(timeout: 5), "Network card should exist")
    }
    
    func testDashboardRefreshButton() throws {
        // Find and tap refresh button
        let refreshButton = app.buttons["Refresh"]
        if refreshButton.exists {
            refreshButton.tap()
            // Give time for refresh
            sleep(2)
        }
    }
    
    // MARK: - Process Manager Tests
    
    func testProcessManagerNavigation() throws {
        // Navigate to Processes
        let processesItem = app.staticTexts["Processes"]
        if processesItem.exists {
            processesItem.tap()
            sleep(1)
        }
        
        // Verify process list elements
        let searchField = app.textFields["Search processes..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")
    }
    
    func testProcessManagerSearch() throws {
        // Navigate to Processes
        let processesItem = app.staticTexts["Processes"]
        if processesItem.exists {
            processesItem.tap()
            sleep(1)
        }
        
        // Test search functionality
        let searchField = app.textFields["Search processes..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Finder")
            sleep(1)
            
            // Clear search
            let clearButton = app.buttons["xmark.circle.fill"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
    }
    
    func testProcessManagerFilterPicker() throws {
        // Navigate to Processes
        let processesItem = app.staticTexts["Processes"]
        if processesItem.exists {
            processesItem.tap()
            sleep(1)
        }
        
        // Test filter picker
        let filterPicker = app.popUpButtons.firstMatch
        if filterPicker.exists {
            filterPicker.tap()
            sleep(1)
            
            // Select an option
            let userAppsOption = app.menuItems["User Apps"]
            if userAppsOption.exists {
                userAppsOption.tap()
            }
        }
    }
    
    // MARK: - Memory Cleanup Tests
    
    func testMemoryCleanupNavigation() throws {
        // Navigate to Memory Cleanup
        let memoryItem = app.staticTexts["Memory Cleanup"]
        if memoryItem.exists {
            memoryItem.tap()
            sleep(1)
        }
        
        // Verify Memory Status header exists
        let statusText = app.staticTexts["Memory Status"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 5), "Memory Status should exist")
    }
    
    func testMemoryCleanupQuickActions() throws {
        // Navigate to Memory Cleanup
        let memoryItem = app.staticTexts["Memory Cleanup"]
        if memoryItem.exists {
            memoryItem.tap()
            sleep(1)
        }
        
        // Verify Quick Actions exist
        let quickActionsText = app.staticTexts["Quick Actions"]
        XCTAssertTrue(quickActionsText.waitForExistence(timeout: 5), "Quick Actions section should exist")
    }
    
    // MARK: - Browser Tabs Tests
    
    func testBrowserTabsNavigation() throws {
        // Navigate to Browser Tabs
        let browserItem = app.staticTexts["Browser Tabs"]
        if browserItem.exists {
            browserItem.tap()
            sleep(1)
        }
        
        // View should show either browser content or permissions required
        let anyBrowserElement = app.staticTexts["All Browsers"].exists || 
                               app.staticTexts["Automation Permission Required"].exists ||
                               app.staticTexts["No Browsers Running"].exists
        XCTAssertTrue(anyBrowserElement, "Browser Tabs view should show content")
    }
    
    // MARK: - Settings Tests
    
    func testSettingsNavigation() throws {
        // Navigate to Settings
        let settingsItem = app.staticTexts["Settings"]
        if settingsItem.exists {
            settingsItem.tap()
            sleep(1)
        }
        
        // Verify Settings sections exist
        let generalSection = app.staticTexts["General"]
        XCTAssertTrue(generalSection.waitForExistence(timeout: 5), "General section should exist")
        
        let monitoringSection = app.staticTexts["Monitoring"]
        XCTAssertTrue(monitoringSection.waitForExistence(timeout: 5), "Monitoring section should exist")
        
        let permissionsSection = app.staticTexts["Permissions"]
        XCTAssertTrue(permissionsSection.waitForExistence(timeout: 5), "Permissions section should exist")
    }
    
    func testSettingsToggle() throws {
        // Navigate to Settings
        let settingsItem = app.staticTexts["Settings"]
        if settingsItem.exists {
            settingsItem.tap()
            sleep(1)
        }
        
        // Find and toggle a switch
        let toggles = app.switches
        if toggles.count > 0 {
            let firstToggle = toggles.firstMatch
            if firstToggle.exists && firstToggle.isHittable {
                firstToggle.tap()
                sleep(1)
                // Toggle back
                firstToggle.tap()
            }
        }
    }
    
    // MARK: - Window Tests
    
    func testWindowResizing() throws {
        // Get the main window
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Main window should exist")
        
        // Verify window can be resized (has resize frame)
        let frame = window.frame
        XCTAssertGreaterThan(frame.width, 0, "Window should have width")
        XCTAssertGreaterThan(frame.height, 0, "Window should have height")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Verify key elements have accessibility labels
        
        // Check sidebar items
        let sidebarItems = ["Dashboard", "Processes", "Memory Cleanup", "Browser Tabs", "Settings"]
        for item in sidebarItems {
            let element = app.staticTexts[item]
            if element.exists {
                XCTAssertTrue(element.isHittable, "\(item) should be accessible")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
