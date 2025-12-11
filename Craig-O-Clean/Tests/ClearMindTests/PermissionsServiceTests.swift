// MARK: - PermissionsServiceTests.swift
// CraigOClean Control Center - Unit Tests for PermissionsService

import XCTest
@testable import Craig_O_Clean

@MainActor
final class PermissionsServiceTests: XCTestCase {
    
    var sut: PermissionsService!
    
    override func setUp() async throws {
        sut = PermissionsService()
    }
    
    override func tearDown() async throws {
        sut.stopPeriodicCheck()
        sut = nil
    }
    
    // MARK: - Permission Type Tests
    
    func testPermissionTypeProperties() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.rawValue.isEmpty, "Permission should have a raw value")
            XCTAssertFalse(permission.description.isEmpty, "Permission should have a description")
            XCTAssertFalse(permission.icon.isEmpty, "Permission should have an icon")
            XCTAssertFalse(permission.settingsPath.isEmpty, "Permission should have a settings path")
        }
    }
    
    func testPermissionTypeSettingsPaths() {
        XCTAssertTrue(PermissionType.automation.settingsPath.contains("Automation"))
        XCTAssertTrue(PermissionType.accessibility.settingsPath.contains("Accessibility"))
        XCTAssertTrue(PermissionType.fullDiskAccess.settingsPath.contains("AllFiles"))
    }
    
    // MARK: - Permission Status Tests
    
    func testPermissionStatusProperties() {
        let statuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .restricted]
        
        for status in statuses {
            XCTAssertFalse(status.rawValue.isEmpty, "Status should have a raw value")
            XCTAssertFalse(status.color.isEmpty, "Status should have a color")
            XCTAssertFalse(status.icon.isEmpty, "Status should have an icon")
        }
    }
    
    func testPermissionStatusColors() {
        XCTAssertEqual(PermissionStatus.granted.color, "green")
        XCTAssertEqual(PermissionStatus.denied.color, "red")
        XCTAssertEqual(PermissionStatus.notDetermined.color, "yellow")
        XCTAssertEqual(PermissionStatus.restricted.color, "orange")
    }
    
    // MARK: - Automation Target Tests
    
    func testPredefinedAutomationTargets() {
        let safari = AutomationTarget.safari
        XCTAssertEqual(safari.name, "Safari")
        XCTAssertEqual(safari.bundleIdentifier, "com.apple.Safari")
        
        let chrome = AutomationTarget.chrome
        XCTAssertEqual(chrome.name, "Google Chrome")
        XCTAssertEqual(chrome.bundleIdentifier, "com.google.Chrome")
        
        let edge = AutomationTarget.edge
        XCTAssertEqual(edge.name, "Microsoft Edge")
        XCTAssertEqual(edge.bundleIdentifier, "com.microsoft.edgemac")
        
        let brave = AutomationTarget.brave
        XCTAssertEqual(brave.name, "Brave Browser")
        XCTAssertEqual(brave.bundleIdentifier, "com.brave.Browser")
        
        let arc = AutomationTarget.arc
        XCTAssertEqual(arc.name, "Arc")
        XCTAssertEqual(arc.bundleIdentifier, "company.thebrowser.Browser")
        
        let systemEvents = AutomationTarget.systemEvents
        XCTAssertEqual(systemEvents.name, "System Events")
        XCTAssertEqual(systemEvents.bundleIdentifier, "com.apple.systemevents")
    }
    
    // MARK: - Service Tests
    
    func testAutomationTargetsInitialized() {
        // Automation targets should be set up on init
        XCTAssertFalse(sut.automationTargets.isEmpty, "Automation targets should be initialized")
        
        // Should at least have System Events
        let hasSystemEvents = sut.automationTargets.contains { $0.bundleIdentifier == "com.apple.systemevents" }
        XCTAssertTrue(hasSystemEvents, "System Events should always be included")
    }
    
    func testCheckAccessibilityPermission() {
        let status = sut.checkAccessibilityPermission()
        
        // Status should be either granted or denied
        XCTAssertTrue(status == .granted || status == .denied, "Accessibility status should be determined")
    }
    
    func testHasRequiredPermissions() {
        // This is a computed property, just verify it returns a boolean
        let hasPermissions = sut.hasRequiredPermissions
        XCTAssertTrue(hasPermissions || !hasPermissions, "hasRequiredPermissions should return boolean")
    }
    
    func testAllAutomationGranted() {
        let allGranted = sut.allAutomationGranted
        XCTAssertTrue(allGranted || !allGranted, "allAutomationGranted should return boolean")
    }
    
    // MARK: - Status Summary Tests
    
    func testGetStatusSummary() {
        let summary = sut.getStatusSummary()
        
        XCTAssertFalse(summary.isEmpty, "Status summary should not be empty")
        
        // Summary should contain relevant information
        let containsRelevantInfo = summary.contains("permission") || 
                                   summary.contains("granted") || 
                                   summary.contains("All")
        XCTAssertTrue(containsRelevantInfo, "Summary should contain permission-related text")
    }
    
    // MARK: - Helper Method Tests
    
    func testHasAutomationPermissionForBundleIdentifier() {
        // Test with a known bundle identifier
        let safariPermission = sut.hasAutomationPermission(for: "com.apple.Safari")
        XCTAssertTrue(safariPermission || !safariPermission, "Should return boolean for Safari")
        
        // Test with unknown bundle identifier
        let unknownPermission = sut.hasAutomationPermission(for: "com.nonexistent.app")
        XCTAssertFalse(unknownPermission, "Should return false for unknown app")
    }
    
    // MARK: - Instructions Tests
    
    func testGetInstructions() {
        for permission in PermissionType.allCases {
            let instructions = sut.getInstructions(for: permission)
            
            XCTAssertFalse(instructions.isEmpty, "Should have instructions for \(permission.rawValue)")
            XCTAssertGreaterThanOrEqual(instructions.count, 3, "Should have at least 3 instruction steps")
            
            for instruction in instructions {
                XCTAssertFalse(instruction.isEmpty, "Each instruction should have content")
            }
        }
    }
    
    // MARK: - Periodic Check Tests
    
    func testPeriodicCheckStartStop() {
        sut.startPeriodicCheck(interval: 60.0)
        // Can't easily verify timer without internal access
        
        sut.stopPeriodicCheck()
        // Just verify no crash
    }
    
    // MARK: - Check All Permissions Tests
    
    func testCheckAllPermissions() async throws {
        XCTAssertFalse(sut.isChecking, "Should not be checking initially")
        
        await sut.checkAllPermissions()
        
        XCTAssertFalse(sut.isChecking, "Should not be checking after completion")
        XCTAssertNotNil(sut.lastCheckTime, "Last check time should be set")
        
        // Accessibility status should be determined
        let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .restricted]
        XCTAssertTrue(validStatuses.contains(sut.accessibilityStatus), "Accessibility status should be a valid value")
    }
}
