// MARK: - PermissionsServiceTests.swift
// Craig-O-Clean - Unit Tests for Permissions Service
// Tests permission checking and request functionality

import XCTest
@testable import Craig_O_Clean

@MainActor
final class PermissionsServiceTests: XCTestCase {
    
    var service: PermissionsService!
    
    override func setUp() {
        super.setUp()
        service = PermissionsService()
    }
    
    override func tearDown() {
        service.stopPeriodicCheck()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.automationTargets.isEmpty, "Should have automation targets")
    }
    
    // MARK: - Permission Type Tests
    
    func testPermissionTypeProperties() {
        for type in PermissionType.allCases {
            XCTAssertFalse(type.rawValue.isEmpty, "Permission type should have name")
            XCTAssertFalse(type.description.isEmpty, "Permission type should have description")
            XCTAssertFalse(type.icon.isEmpty, "Permission type should have icon")
            XCTAssertFalse(type.settingsPath.isEmpty, "Permission type should have settings path")
        }
    }
    
    // MARK: - Permission Status Tests
    
    func testPermissionStatusProperties() {
        for status in [PermissionStatus.granted, .denied, .notDetermined, .restricted] {
            XCTAssertFalse(status.rawValue.isEmpty, "Status should have name")
            XCTAssertFalse(status.color.isEmpty, "Status should have color")
            XCTAssertFalse(status.icon.isEmpty, "Status should have icon")
        }
    }
    
    // MARK: - Automation Target Tests
    
    func testAutomationTargetPresets() {
        let safari = AutomationTarget.safari
        XCTAssertEqual(safari.bundleIdentifier, "com.apple.Safari")
        
        let chrome = AutomationTarget.chrome
        XCTAssertEqual(chrome.bundleIdentifier, "com.google.Chrome")
        
        let systemEvents = AutomationTarget.systemEvents
        XCTAssertEqual(systemEvents.bundleIdentifier, "com.apple.systemevents")
    }
    
    func testAutomationTargetsContainsSafari() {
        let hasSafari = service.automationTargets.contains { $0.bundleIdentifier == "com.apple.Safari" }
        XCTAssertTrue(hasSafari, "Safari should be in automation targets")
    }
    
    // MARK: - Permission Check Tests
    
    func testCheckAccessibilityPermission() {
        let status = service.checkAccessibilityPermission()
        let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .restricted]
        XCTAssertTrue(validStatuses.contains(status), "Status should be valid")
    }
    
    func testCheckFullDiskAccessPermission() {
        let status = service.checkFullDiskAccessPermission()
        let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .restricted]
        XCTAssertTrue(validStatuses.contains(status), "Status should be valid")
    }
    
    func testCheckAllPermissions() async {
        await service.checkAllPermissions()
        
        XCTAssertNotNil(service.lastCheckTime, "Last check time should be set")
        XCTAssertFalse(service.isChecking, "Should not be checking after completion")
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasRequiredPermissions() {
        // Just verify property doesn't crash
        _ = service.hasRequiredPermissions
    }
    
    func testAllAutomationGranted() {
        // Just verify property doesn't crash
        _ = service.allAutomationGranted
    }
    
    func testHasAllCriticalPermissions() {
        // Just verify property doesn't crash
        _ = service.hasAllCriticalPermissions
    }
    
    func testMissingCriticalPermissions() {
        let missing = service.missingCriticalPermissions
        XCTAssertNotNil(missing, "Missing permissions should not be nil")
    }
    
    // MARK: - Helper Methods Tests
    
    func testGetStatusSummary() {
        let summary = service.getStatusSummary()
        XCTAssertFalse(summary.isEmpty, "Status summary should not be empty")
    }
    
    func testHasAutomationPermission() {
        // Test with Safari
        _ = service.hasAutomationPermission(for: "com.apple.Safari")
        // Just verify it doesn't crash
    }
    
    // MARK: - Instructions Tests
    
    func testGetInstructions() {
        for type in PermissionType.allCases {
            let instructions = service.getInstructions(for: type)
            XCTAssertFalse(instructions.isEmpty, "Should have instructions for \(type)")
            XCTAssertGreaterThan(instructions.count, 2, "Should have multiple steps")
        }
    }
    
    // MARK: - Periodic Check Tests
    
    func testStartPeriodicCheck() {
        service.startPeriodicCheck(interval: 30.0)
        // Just verify it doesn't crash
        service.stopPeriodicCheck()
    }
    
    func testStopPeriodicCheck() {
        service.startPeriodicCheck(interval: 30.0)
        service.stopPeriodicCheck()
        // Just verify it doesn't crash
    }
}
