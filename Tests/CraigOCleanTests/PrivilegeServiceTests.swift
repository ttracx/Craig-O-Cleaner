// MARK: - PrivilegeServiceTests.swift
// Craig-O-Clean - Unit Tests for Privilege Service
// Tests privileged helper management and memory cleanup operations

import XCTest
@testable import Craig_O_Clean

@MainActor
final class PrivilegeServiceTests: XCTestCase {

    var service: PrivilegeService!

    override func setUp() {
        super.setUp()
        service = PrivilegeService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isHelperInstalled, "Helper should not be installed on init")
        XCTAssertFalse(service.isOperationInProgress, "No operation should be in progress on init")
    }

    func testInitialHelperStatus() {
        // Initially the helper status should be unknown
        XCTAssertEqual(service.helperStatus, .unknown, "Helper status should be unknown on init")
    }

    // MARK: - Helper Status Tests

    func testCheckHelperStatus() async {
        await service.checkHelperStatus()

        // After checking, status should no longer be unknown
        // (Will likely be .notInstalled in test environment)
        XCTAssertNotEqual(service.helperStatus, .unknown, "Helper status should be determined after check")
    }

    func testHelperStatusIsInstalledProperty() {
        // Test the isInstalled computed property on HelperStatus
        XCTAssertFalse(HelperStatus.notInstalled.isInstalled, "notInstalled should not be installed")
        XCTAssertTrue(HelperStatus.installed(version: "1.0.0").isInstalled, "installed should be installed")
        XCTAssertTrue(HelperStatus.needsUpdate(currentVersion: "0.9", requiredVersion: "1.0").isInstalled, "needsUpdate should be installed")
        XCTAssertFalse(HelperStatus.installationFailed(error: "test").isInstalled, "installationFailed should not be installed")
        XCTAssertFalse(HelperStatus.unknown.isInstalled, "unknown should not be installed")
    }

    // MARK: - Privilege Operation Result Tests

    func testPrivilegeOperationResultSuccess() {
        let result = PrivilegeOperationResult(
            success: true,
            message: "Operation completed successfully",
            errorCode: 0,
            output: "Some output"
        )

        XCTAssertTrue(result.success, "Result should be successful")
        XCTAssertEqual(result.message, "Operation completed successfully")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.output, "Some output")
    }

    func testPrivilegeOperationResultFailure() {
        let result = PrivilegeOperationResult(
            success: false,
            message: "Operation failed",
            errorCode: -1,
            output: nil
        )

        XCTAssertFalse(result.success, "Result should not be successful")
        XCTAssertEqual(result.message, "Operation failed")
        XCTAssertEqual(result.errorCode, -1)
        XCTAssertNil(result.output)
    }

    func testPrivilegeOperationResultEquality() {
        let result1 = PrivilegeOperationResult(
            success: true,
            message: "Test",
            errorCode: 0,
            output: nil
        )
        let result2 = PrivilegeOperationResult(
            success: true,
            message: "Test",
            errorCode: 0,
            output: nil
        )
        let result3 = PrivilegeOperationResult(
            success: false,
            message: "Test",
            errorCode: 0,
            output: nil
        )

        XCTAssertEqual(result1, result2, "Equal results should be equal")
        XCTAssertNotEqual(result1, result3, "Different results should not be equal")
    }

    // MARK: - Purge Availability Tests

    func testPurgeAvailabilityCheck() async {
        await service.checkHelperStatus()

        // isPurgeAvailable should be set (true or false depending on system)
        // Just verify it doesn't crash and returns a boolean
        _ = service.isPurgeAvailable
    }

    // MARK: - Memory Cleanup Tests (Debug Mode)

    func testExecuteMemoryCleanup() async {
        // In test/debug mode, this should use the AppleScript fallback
        // We can't fully test this without admin privileges, but we can
        // verify the method runs without crashing

        await service.checkHelperStatus()

        // Note: This test may prompt for admin password in debug mode
        // For CI/automated testing, you might want to skip this
        // let result = await service.executeMemoryCleanup()
        // XCTAssertNotNil(result.message, "Result should have a message")
    }

    // MARK: - Operation State Tests

    func testOperationInProgressState() async {
        XCTAssertFalse(service.isOperationInProgress, "Should not be in progress initially")

        // Note: Would need to capture mid-operation state to fully test this
        // For now, just verify the property exists and is accessible
    }

    func testLastOperationResult() async {
        XCTAssertNil(service.lastOperationResult, "Last result should be nil initially")

        // After an operation, lastOperationResult should be set
        // This would require actually executing an operation
    }

    // MARK: - Helper Status Equatable Tests

    func testHelperStatusEquatable() {
        XCTAssertEqual(HelperStatus.notInstalled, HelperStatus.notInstalled)
        XCTAssertEqual(HelperStatus.unknown, HelperStatus.unknown)
        XCTAssertEqual(
            HelperStatus.installed(version: "1.0.0"),
            HelperStatus.installed(version: "1.0.0")
        )
        XCTAssertNotEqual(
            HelperStatus.installed(version: "1.0.0"),
            HelperStatus.installed(version: "2.0.0")
        )
        XCTAssertEqual(
            HelperStatus.needsUpdate(currentVersion: "0.9", requiredVersion: "1.0"),
            HelperStatus.needsUpdate(currentVersion: "0.9", requiredVersion: "1.0")
        )
        XCTAssertEqual(
            HelperStatus.installationFailed(error: "test"),
            HelperStatus.installationFailed(error: "test")
        )
    }

    // MARK: - Integration Tests (Require Manual Setup)

    // These tests would require the helper to be installed
    // They are commented out for CI but can be run manually

    /*
    func testExecuteSyncWithHelper() async {
        // Requires helper to be installed
        await service.checkHelperStatus()
        guard service.isHelperInstalled else {
            XCTSkip("Helper not installed")
            return
        }

        let result = await service.executeSync()
        XCTAssertNotNil(result.message)
    }

    func testExecutePurgeWithHelper() async {
        // Requires helper to be installed and purge to be available
        await service.checkHelperStatus()
        guard service.isHelperInstalled && service.isPurgeAvailable else {
            XCTSkip("Helper not installed or purge not available")
            return
        }

        let result = await service.executePurge()
        XCTAssertNotNil(result.message)
    }
    */
}

// MARK: - Mock Tests

/// Mock PrivilegeService for testing UI components
final class MockPrivilegeService: PrivilegeServiceProtocol {
    var helperStatus: HelperStatus = .installed(version: "1.0.0")
    var isHelperInstalled: Bool = true
    var isPurgeAvailable: Bool = true

    var checkHelperStatusCalled = false
    var installHelperCalled = false
    var executeMemoryCleanupCalled = false
    var executeSyncCalled = false
    var executePurgeCalled = false

    var mockResult = PrivilegeOperationResult(
        success: true,
        message: "Mock operation completed",
        errorCode: 0,
        output: nil
    )

    func checkHelperStatus() async {
        checkHelperStatusCalled = true
    }

    func installHelper() async -> PrivilegeOperationResult {
        installHelperCalled = true
        return mockResult
    }

    func executeMemoryCleanup() async -> PrivilegeOperationResult {
        executeMemoryCleanupCalled = true
        return mockResult
    }

    func executeSync() async -> PrivilegeOperationResult {
        executeSyncCalled = true
        return mockResult
    }

    func executePurge() async -> PrivilegeOperationResult {
        executePurgeCalled = true
        return mockResult
    }
}

@MainActor
final class MockPrivilegeServiceTests: XCTestCase {

    func testMockServiceDefaultValues() {
        let mock = MockPrivilegeService()

        XCTAssertTrue(mock.isHelperInstalled)
        XCTAssertTrue(mock.isPurgeAvailable)
        XCTAssertEqual(mock.helperStatus, .installed(version: "1.0.0"))
    }

    func testMockServiceMethodCalls() async {
        let mock = MockPrivilegeService()

        await mock.checkHelperStatus()
        XCTAssertTrue(mock.checkHelperStatusCalled)

        _ = await mock.installHelper()
        XCTAssertTrue(mock.installHelperCalled)

        _ = await mock.executeMemoryCleanup()
        XCTAssertTrue(mock.executeMemoryCleanupCalled)

        _ = await mock.executeSync()
        XCTAssertTrue(mock.executeSyncCalled)

        _ = await mock.executePurge()
        XCTAssertTrue(mock.executePurgeCalled)
    }

    func testMockServiceCustomResult() async {
        let mock = MockPrivilegeService()
        mock.mockResult = PrivilegeOperationResult(
            success: false,
            message: "Custom failure",
            errorCode: -99,
            output: "Error details"
        )

        let result = await mock.executeMemoryCleanup()

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, "Custom failure")
        XCTAssertEqual(result.errorCode, -99)
        XCTAssertEqual(result.output, "Error details")
    }
}
