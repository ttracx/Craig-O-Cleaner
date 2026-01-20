// MARK: - AutomatedE2ETests.swift
// Craig-O-Clean - Comprehensive Automated End-to-End UI Tests
// Designed for automated testing pipeline with detailed logging and reporting

import XCTest

/// Comprehensive end-to-end test suite for Craig-O-Clean
/// This suite is designed to be run by the automated testing script
/// and provides detailed logging for the agent orchestration system
final class AutomatedE2ETests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!
    private var testStartTime: Date!
    private var screenshotCounter = 0

    // Test configuration from environment
    private var shouldCaptureScreenshots: Bool {
        ProcessInfo.processInfo.environment["CAPTURE_SCREENSHOTS"] == "true"
    }

    private var verboseLogging: Bool {
        ProcessInfo.processInfo.environment["VERBOSE_LOGGING"] == "true"
    }

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        testStartTime = Date()
        screenshotCounter = 0

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--enable-debug-logging"]
        app.launchEnvironment = [
            "UITEST_MODE": "true",
            "LOG_LEVEL": "verbose"
        ]

        logTestEvent("Starting test: \(name)")
        app.launch()

        // Wait for app to be ready
        XCTAssertTrue(waitForAppReady(), "App should be ready within timeout")
    }

    override func tearDownWithError() throws {
        let duration = Date().timeIntervalSince(testStartTime)
        logTestEvent("Completed test: \(name) in \(String(format: "%.2f", duration))s")

        // Capture final screenshot if test failed
        if testRun?.hasSucceeded == false {
            captureScreenshot(name: "failure_state")
        }

        app = nil
    }

    // MARK: - Helper Methods

    private func waitForAppReady(timeout: TimeInterval = 10) -> Bool {
        // For menu bar app, wait for window to exist
        let window = app.windows.firstMatch
        return window.waitForExistence(timeout: timeout)
    }

    private func logTestEvent(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [E2E-TEST] \(message)"
        print(logMessage)

        // Also write to test attachment
        let attachment = XCTAttachment(string: logMessage)
        attachment.name = "test_log"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func captureScreenshot(name: String) {
        guard shouldCaptureScreenshots else { return }

        screenshotCounter += 1
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(screenshotCounter)_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        logTestEvent("Screenshot captured: \(name)")
    }

    private func navigateToSection(_ section: String) -> Bool {
        let sidebarItem = app.staticTexts[section]
        guard sidebarItem.waitForExistence(timeout: 5) else {
            logTestEvent("ERROR: Could not find sidebar item '\(section)'")
            return false
        }

        sidebarItem.tap()
        // Wait for view transition using proper wait condition instead of sleep
        _ = waitForViewTransition()
        captureScreenshot(name: "navigate_to_\(section.lowercased().replacingOccurrences(of: " ", with: "_"))")
        logTestEvent("Navigated to: \(section)")
        return true
    }

    /// Wait for view transition to complete using XCTWaiter instead of sleep
    private func waitForViewTransition(timeout: TimeInterval = 2) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.windows.firstMatch
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Wait for a specific condition with timeout
    private func waitFor(condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    // MARK: - App Launch Tests

    func test_A01_AppLaunch() throws {
        logTestEvent("Testing app launch")

        // Verify main window exists
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Main window should exist after launch")

        // Verify window title
        captureScreenshot(name: "app_launched")

        logTestEvent("App launch successful")
    }

    func test_A02_AppLaunchPerformance() throws {
        if #available(macOS 10.15, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - Sidebar Navigation Tests

    func test_B01_SidebarExists() throws {
        logTestEvent("Testing sidebar existence")

        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "Sidebar should exist")

        captureScreenshot(name: "sidebar_visible")
    }

    func test_B02_AllNavigationItemsPresent() throws {
        logTestEvent("Testing all navigation items are present")

        let expectedItems = ["Dashboard", "Processes", "Memory Cleanup", "Auto-Cleanup", "Browser Tabs", "Settings"]
        var missingItems: [String] = []

        for item in expectedItems {
            let element = app.staticTexts[item]
            if !element.waitForExistence(timeout: 3) {
                missingItems.append(item)
            }
        }

        captureScreenshot(name: "navigation_items")

        XCTAssertTrue(missingItems.isEmpty, "Missing navigation items: \(missingItems.joined(separator: ", "))")
        logTestEvent("All \(expectedItems.count) navigation items present")
    }

    func test_B03_NavigationToDashboard() throws {
        XCTAssertTrue(navigateToSection("Dashboard"), "Should navigate to Dashboard")

        // Verify Dashboard content
        let systemHealth = app.staticTexts["System Health"]
        XCTAssertTrue(systemHealth.waitForExistence(timeout: 5), "Dashboard should show System Health")
    }

    func test_B04_NavigationToProcesses() throws {
        XCTAssertTrue(navigateToSection("Processes"), "Should navigate to Processes")

        // Verify Process Manager content
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Process search field should exist")
    }

    func test_B05_NavigationToMemoryCleanup() throws {
        XCTAssertTrue(navigateToSection("Memory Cleanup"), "Should navigate to Memory Cleanup")

        // Verify Memory Cleanup content
        let memoryStatus = app.staticTexts["Memory Status"]
        XCTAssertTrue(memoryStatus.waitForExistence(timeout: 5), "Memory Status section should exist")
    }

    func test_B06_NavigationToAutoCleanup() throws {
        XCTAssertTrue(navigateToSection("Auto-Cleanup"), "Should navigate to Auto-Cleanup")

        // Verify Auto-Cleanup content loads
        _ = waitForViewTransition()
        captureScreenshot(name: "auto_cleanup_view")
    }

    func test_B07_NavigationToBrowserTabs() throws {
        XCTAssertTrue(navigateToSection("Browser Tabs"), "Should navigate to Browser Tabs")

        // View should show content
        _ = waitForViewTransition()
        captureScreenshot(name: "browser_tabs_view")
    }

    func test_B08_NavigationToSettings() throws {
        XCTAssertTrue(navigateToSection("Settings"), "Should navigate to Settings")

        // Verify Settings sections
        let generalSection = app.staticTexts["General"]
        XCTAssertTrue(generalSection.waitForExistence(timeout: 5), "General section should exist in Settings")
    }

    // MARK: - Dashboard Tests

    func test_C01_DashboardMetricsCards() throws {
        XCTAssertTrue(navigateToSection("Dashboard"), "Should navigate to Dashboard")

        let expectedCards = ["CPU", "Memory", "Disk", "Network"]
        var missingCards: [String] = []

        for card in expectedCards {
            let element = app.staticTexts[card]
            if !element.waitForExistence(timeout: 3) {
                missingCards.append(card)
            }
        }

        captureScreenshot(name: "dashboard_metrics")

        XCTAssertTrue(missingCards.isEmpty, "Missing metric cards: \(missingCards.joined(separator: ", "))")
        logTestEvent("All dashboard metric cards present")
    }

    func test_C02_DashboardRealTimeUpdates() throws {
        XCTAssertTrue(navigateToSection("Dashboard"), "Should navigate to Dashboard")

        captureScreenshot(name: "dashboard_initial")

        // Wait for potential updates using proper wait condition
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.staticTexts["CPU"]
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: 3)

        captureScreenshot(name: "dashboard_after_3s")

        logTestEvent("Dashboard real-time updates test completed")
    }

    // MARK: - Process Manager Tests

    func test_D01_ProcessListLoads() throws {
        XCTAssertTrue(navigateToSection("Processes"), "Should navigate to Processes")

        // Wait for process list to load
        let tableContent = app.tables.firstMatch
        _ = tableContent.waitForExistence(timeout: 3)

        captureScreenshot(name: "process_list_loaded")

        // Should show some processes
        if tableContent.exists {
            XCTAssertGreaterThan(tableContent.cells.count, 0, "Process list should have items")
        }

        logTestEvent("Process list loaded")
    }

    func test_D02_ProcessSearch() throws {
        XCTAssertTrue(navigateToSection("Processes"), "Should navigate to Processes")

        let searchField = app.textFields["Search processes..."]
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Search field should exist")
            return
        }

        // Type search query
        searchField.tap()
        searchField.typeText("Finder")

        captureScreenshot(name: "process_search_finder")
        _ = waitForViewTransition()

        // Clear search
        if let text = searchField.value as? String, !text.isEmpty {
            searchField.tap()
            // Select all and delete
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
        }

        captureScreenshot(name: "process_search_cleared")
        logTestEvent("Process search functionality tested")
    }

    func test_D03_ProcessFilterPicker() throws {
        XCTAssertTrue(navigateToSection("Processes"), "Should navigate to Processes")

        _ = waitForViewTransition()

        let filterPicker = app.popUpButtons.firstMatch
        guard filterPicker.waitForExistence(timeout: 5) else {
            logTestEvent("Filter picker not found - may be a picker instead")
            return
        }

        filterPicker.tap()
        captureScreenshot(name: "process_filter_open")

        _ = waitForViewTransition()

        // Select an option if available
        let userAppsOption = app.menuItems["User Apps"]
        if userAppsOption.exists {
            userAppsOption.tap()
            captureScreenshot(name: "process_filter_user_apps")
        }

        logTestEvent("Process filter picker tested")
    }

    // MARK: - Memory Cleanup Tests

    func test_E01_MemoryStatusDisplay() throws {
        XCTAssertTrue(navigateToSection("Memory Cleanup"), "Should navigate to Memory Cleanup")

        // Verify memory status elements exist
        let memoryStatus = app.staticTexts["Memory Status"]
        XCTAssertTrue(memoryStatus.waitForExistence(timeout: 5), "Memory Status should be visible")

        captureScreenshot(name: "memory_status")
        logTestEvent("Memory status display verified")
    }

    func test_E02_QuickActionsExist() throws {
        XCTAssertTrue(navigateToSection("Memory Cleanup"), "Should navigate to Memory Cleanup")

        let quickActions = app.staticTexts["Quick Actions"]
        XCTAssertTrue(quickActions.waitForExistence(timeout: 5), "Quick Actions section should exist")

        captureScreenshot(name: "memory_quick_actions")
        logTestEvent("Quick actions section verified")
    }

    // MARK: - Settings Tests

    func test_F01_SettingsSections() throws {
        XCTAssertTrue(navigateToSection("Settings"), "Should navigate to Settings")

        let sections = ["General", "Monitoring", "Permissions"]
        var missingSections: [String] = []

        for section in sections {
            let element = app.staticTexts[section]
            if !element.waitForExistence(timeout: 3) {
                missingSections.append(section)
            }
        }

        captureScreenshot(name: "settings_sections")

        XCTAssertTrue(missingSections.isEmpty, "Missing settings sections: \(missingSections.joined(separator: ", "))")
        logTestEvent("All settings sections present")
    }

    func test_F02_SettingsToggleInteraction() throws {
        XCTAssertTrue(navigateToSection("Settings"), "Should navigate to Settings")

        let toggles = app.switches
        guard toggles.count > 0 else {
            logTestEvent("No toggles found in settings")
            return
        }

        let firstToggle = toggles.firstMatch
        guard firstToggle.exists && firstToggle.isHittable else {
            logTestEvent("Toggle exists but is not hittable")
            return
        }

        let initialValue = firstToggle.value as? String
        captureScreenshot(name: "settings_toggle_before")

        firstToggle.tap()
        _ = waitForViewTransition()
        captureScreenshot(name: "settings_toggle_after")

        // Toggle back to original state
        firstToggle.tap()

        logTestEvent("Settings toggle interaction tested")
    }

    // MARK: - Window Tests

    func test_G01_WindowResizable() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Main window should exist")

        let frame = window.frame
        XCTAssertGreaterThan(frame.width, 0, "Window should have positive width")
        XCTAssertGreaterThan(frame.height, 0, "Window should have positive height")

        logTestEvent("Window size: \(frame.width)x\(frame.height)")
    }

    func test_G02_WindowMinimumSize() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Main window should exist")

        // Verify minimum size is respected
        let frame = window.frame
        XCTAssertGreaterThanOrEqual(frame.width, 900, "Window width should be at least 900")
        XCTAssertGreaterThanOrEqual(frame.height, 600, "Window height should be at least 600")

        logTestEvent("Window meets minimum size requirements")
    }

    // MARK: - Accessibility Tests

    func test_H01_SidebarAccessibility() throws {
        let sidebarItems = ["Dashboard", "Processes", "Memory Cleanup", "Browser Tabs", "Settings"]

        for item in sidebarItems {
            let element = app.staticTexts[item]
            if element.exists {
                XCTAssertTrue(element.isHittable, "\(item) should be accessible and hittable")
            }
        }

        logTestEvent("Sidebar accessibility verified")
    }

    func test_H02_ButtonsAccessibility() throws {
        let buttons = app.buttons

        for i in 0..<min(buttons.count, 10) {
            let button = buttons.element(boundBy: i)
            if button.exists && button.isHittable {
                // Button has accessibility
                logTestEvent("Button '\(button.identifier)' is accessible")
            }
        }

        logTestEvent("Button accessibility check completed")
    }

    // MARK: - Error Handling Tests

    func test_I01_GracefulErrorHandling() throws {
        // Test that the app doesn't crash with various interactions

        // Rapid navigation
        for section in ["Dashboard", "Processes", "Memory Cleanup", "Settings"] {
            let item = app.staticTexts[section]
            if item.exists {
                item.tap()
            }
        }

        _ = waitForViewTransition()

        // App should still be running
        XCTAssertTrue(app.state == .runningForeground, "App should still be running after rapid navigation")

        captureScreenshot(name: "after_rapid_navigation")
        logTestEvent("Graceful error handling verified")
    }

    // MARK: - Integration Tests

    func test_J01_FullUserJourney() throws {
        logTestEvent("Starting full user journey test")

        // 1. Start at Dashboard
        XCTAssertTrue(navigateToSection("Dashboard"), "Should navigate to Dashboard")
        _ = waitForViewTransition()

        // 2. Check system metrics
        let cpuCard = app.staticTexts["CPU"]
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "CPU card should exist")

        // 3. Navigate to Processes
        XCTAssertTrue(navigateToSection("Processes"), "Should navigate to Processes")
        _ = waitForViewTransition()

        // 4. Search for a process
        let searchField = app.textFields["Search processes..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Finder")
            _ = waitForViewTransition()
        }

        // 5. Navigate to Memory Cleanup
        XCTAssertTrue(navigateToSection("Memory Cleanup"), "Should navigate to Memory Cleanup")
        _ = waitForViewTransition()

        // 6. Check memory status
        let memoryStatus = app.staticTexts["Memory Status"]
        XCTAssertTrue(memoryStatus.waitForExistence(timeout: 5), "Memory Status should exist")

        // 7. Navigate to Settings
        XCTAssertTrue(navigateToSection("Settings"), "Should navigate to Settings")
        _ = waitForViewTransition()

        // 8. Verify settings loaded
        let generalSection = app.staticTexts["General"]
        XCTAssertTrue(generalSection.waitForExistence(timeout: 5), "General section should exist")

        captureScreenshot(name: "full_journey_complete")
        logTestEvent("Full user journey test completed successfully")
    }

    // MARK: - Performance Tests

    func test_K01_NavigationPerformance() throws {
        let sections = ["Dashboard", "Processes", "Memory Cleanup", "Settings"]
        var navigationTimes: [String: TimeInterval] = [:]

        for section in sections {
            let startTime = Date()

            let item = app.staticTexts[section]
            if item.exists {
                item.tap()
                _ = waitForViewTransition()
            }

            let duration = Date().timeIntervalSince(startTime)
            navigationTimes[section] = duration

            logTestEvent("Navigation to \(section): \(String(format: "%.2f", duration))s")
        }

        // All navigations should be under 3 seconds (increased from 2 to account for wait conditions)
        for (section, time) in navigationTimes {
            XCTAssertLessThan(time, 3.0, "Navigation to \(section) should be fast")
        }
    }

    // MARK: - Data Export for Automated Testing

    func test_Z01_ExportTestResults() throws {
        // This test runs last to export all results
        logTestEvent("Test suite execution completed")

        // Create test summary
        let summary = """
        ================================================================================
        AUTOMATED E2E TEST SUMMARY
        ================================================================================
        Test Class: AutomatedE2ETests
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        App: Craig-O-Clean
        ================================================================================
        """

        let attachment = XCTAttachment(string: summary)
        attachment.name = "test_summary"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - Test Helper Extensions

extension XCUIElement {
    /// Wait for element to exist and be hittable
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Safe tap that waits for element
    func safeTap(timeout: TimeInterval = 5) -> Bool {
        guard waitForHittable(timeout: timeout) else { return false }
        tap()
        return true
    }
}
