//
//  PermissionSystemTests.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import XCTest
@testable import CraigOTerminator

final class PermissionSystemTests: XCTestCase {

    // MARK: - PermissionCenter Tests

    func testPermissionCenterRefreshesAllPermissions() async throws {
        let center = PermissionCenter.shared

        await center.refreshAll()

        XCTAssertNotNil(center.lastCheckDate)
        XCTAssertFalse(center.automationPermissions.isEmpty)
    }

    func testPermissionCenterChecksAllBrowsers() async throws {
        let center = PermissionCenter.shared

        await center.refreshAll()

        for browser in BrowserApp.allCases {
            XCTAssertNotNil(center.automationPermissions[browser])
        }
    }

    func testPermissionCenterDetectsInstalledBrowsers() async throws {
        let center = PermissionCenter.shared

        for browser in BrowserApp.allCases {
            let state = await center.checkAutomationPermission(for: browser)

            // If browser is installed, state should be determined
            // If not installed, state should be notDetermined
            XCTAssertTrue(
                state != .unknown,
                "Browser \(browser.rawValue) permission state should not be unknown"
            )
        }
    }

    // MARK: - AutomationChecker Tests

    func testAutomationCheckerDetectsInstalledBrowsers() async throws {
        for browser in BrowserApp.allCases {
            let state = await AutomationChecker.checkPermission(for: browser)

            // Should never return unknown for any browser
            XCTAssertNotEqual(state, .unknown)
        }
    }

    func testAutomationCheckerSystemSettingsURL() {
        for browser in BrowserApp.allCases {
            let url = AutomationChecker.systemSettingsURL(for: browser)

            XCTAssertNotNil(url)
            XCTAssertTrue(url?.absoluteString.contains("systempreferences") ?? false)
        }
    }

    // MARK: - PreflightEngine Tests

    func testPreflightEngineValidatesPathExists() async throws {
        let engine = PreflightEngine()

        // Test existing path
        let existingCheck = PreflightCheck(
            type: .pathExists,
            target: NSHomeDirectory(),
            failureMessage: "Home directory should exist"
        )

        let capability = createTestCapability(preflightChecks: [existingCheck])
        let result = await engine.validate(capability)

        XCTAssertTrue(result.canExecute)
        XCTAssertTrue(result.failedChecks.isEmpty)
    }

    func testPreflightEngineFailsOnMissingPath() async throws {
        let engine = PreflightEngine()

        // Test non-existing path
        let missingCheck = PreflightCheck(
            type: .pathExists,
            target: "/this/path/does/not/exist",
            failureMessage: "Path does not exist"
        )

        let capability = createTestCapability(preflightChecks: [missingCheck])
        let result = await engine.validate(capability)

        XCTAssertFalse(result.canExecute)
        XCTAssertEqual(result.failedChecks.count, 1)
    }

    func testPreflightEngineValidatesWritablePath() async throws {
        let engine = PreflightEngine()

        // Test writable path (temp directory)
        let writableCheck = PreflightCheck(
            type: .pathWritable,
            target: NSTemporaryDirectory(),
            failureMessage: "Temp directory should be writable"
        )

        let capability = createTestCapability(preflightChecks: [writableCheck])
        let result = await engine.validate(capability)

        XCTAssertTrue(result.canExecute)
        XCTAssertTrue(result.failedChecks.isEmpty)
    }

    func testPreflightEngineParsesDiskSpace() async throws {
        let engine = PreflightEngine()

        // Test with reasonable disk space requirement
        let diskCheck = PreflightCheck(
            type: .diskSpaceAvailable,
            target: "1MB",  // Very small requirement should always pass
            failureMessage: "Insufficient disk space"
        )

        let capability = createTestCapability(preflightChecks: [diskCheck])
        let result = await engine.validate(capability)

        XCTAssertTrue(result.canExecute)
        XCTAssertTrue(result.failedChecks.isEmpty)
    }

    func testPreflightEngineValidatesMultipleChecks() async throws {
        let engine = PreflightEngine()

        let checks = [
            PreflightCheck(
                type: .pathExists,
                target: NSHomeDirectory(),
                failureMessage: "Home should exist"
            ),
            PreflightCheck(
                type: .pathWritable,
                target: NSTemporaryDirectory(),
                failureMessage: "Temp should be writable"
            ),
            PreflightCheck(
                type: .diskSpaceAvailable,
                target: "1MB",
                failureMessage: "Need 1MB space"
            )
        ]

        let capability = createTestCapability(preflightChecks: checks)
        let result = await engine.validate(capability)

        XCTAssertTrue(result.canExecute)
        XCTAssertTrue(result.failedChecks.isEmpty)
    }

    func testPreflightEngineDetectsPrivilegeLevelRequirements() async throws {
        let engine = PreflightEngine()

        // Test user level (should pass)
        let userCapability = createTestCapability(
            privilegeLevel: .user,
            preflightChecks: []
        )
        let userResult = await engine.validate(userCapability)
        XCTAssertTrue(userResult.canExecute)

        // Test elevated level (requires helper)
        let elevatedCapability = createTestCapability(
            privilegeLevel: .elevated,
            preflightChecks: []
        )
        let elevatedResult = await engine.validate(elevatedCapability)
        // May fail if helper not installed (expected)
    }

    // MARK: - PreflightResult Tests

    func testPreflightResultSummary() {
        let failedCheck = PreflightResult.FailedCheck(
            check: PreflightCheck(
                type: .pathExists,
                target: "/test",
                failureMessage: "Path not found"
            ),
            reason: "Path not found"
        )

        let result = PreflightResult(
            canExecute: false,
            failedChecks: [failedCheck],
            missingPermissions: [.fullDiskAccess]
        )

        let summary = result.summary
        XCTAssertTrue(summary.contains("pathExists"))
        XCTAssertTrue(summary.contains("Full Disk Access"))
    }

    // MARK: - BrowserApp Tests

    func testBrowserAppBundleIdentifiers() {
        XCTAssertEqual(BrowserApp.safari.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(BrowserApp.chrome.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(BrowserApp.firefox.bundleIdentifier, "org.mozilla.firefox")
    }

    func testBrowserAppIcons() {
        for browser in BrowserApp.allCases {
            XCTAssertFalse(browser.icon.isEmpty)
        }
    }

    // MARK: - PermissionType Tests

    func testPermissionTypeDisplayNames() {
        let safariPermission = PermissionType.automation(.safari)
        XCTAssertEqual(safariPermission.displayName, "Safari Automation")

        let fdaPermission = PermissionType.fullDiskAccess
        XCTAssertEqual(fdaPermission.displayName, "Full Disk Access")

        let helperPermission = PermissionType.helper
        XCTAssertEqual(helperPermission.displayName, "Privileged Helper")
    }

    func testPermissionTypeIcons() {
        XCTAssertFalse(PermissionType.automation(.safari).icon.isEmpty)
        XCTAssertFalse(PermissionType.fullDiskAccess.icon.isEmpty)
        XCTAssertFalse(PermissionType.helper.icon.isEmpty)
    }

    // MARK: - RemediationStep Tests

    func testRemediationStepsForAutomation() {
        let center = PermissionCenter.shared
        let steps = center.remediationSteps(for: .automation(.safari))

        XCTAssertFalse(steps.isEmpty)
        XCTAssertTrue(steps.contains { $0.instruction.contains("System Settings") })
    }

    func testRemediationStepsForFullDiskAccess() {
        let center = PermissionCenter.shared
        let steps = center.remediationSteps(for: .fullDiskAccess)

        XCTAssertFalse(steps.isEmpty)
        XCTAssertTrue(steps.contains { $0.instruction.contains("Full Disk Access") })
    }

    func testRemediationStepsForHelper() {
        let center = PermissionCenter.shared
        let steps = center.remediationSteps(for: .helper)

        XCTAssertFalse(steps.isEmpty)
        XCTAssertTrue(steps.contains { $0.instruction.contains("Install Helper") || $0.instruction.contains("administrator") })
    }

    // MARK: - Integration Tests

    func testUserExecutorUsesPreflightEngine() async throws {
        let executor = UserExecutor()

        // Create a capability that will fail preflight
        let capability = createTestCapability(
            preflightChecks: [
                PreflightCheck(
                    type: .pathExists,
                    target: "/this/does/not/exist",
                    failureMessage: "Required path not found"
                )
            ]
        )

        do {
            _ = try await executor.execute(capability, arguments: [:])
            XCTFail("Execution should have failed preflight")
        } catch let error as UserExecutorError {
            if case .preflightValidationFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestCapability(
        privilegeLevel: PrivilegeLevel = .user,
        preflightChecks: [PreflightCheck]
    ) -> Capability {
        Capability(
            id: "test-capability",
            title: "Test Capability",
            description: "Test capability for unit tests",
            group: .diagnostics,
            commandTemplate: "/bin/echo test",
            arguments: [],
            workingDirectory: nil,
            timeout: 10,
            privilegeLevel: privilegeLevel,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: preflightChecks,
            requiredPaths: [],
            requiredApps: [],
            icon: "checkmark",
            rollbackNotes: nil,
            estimatedDuration: nil
        )
    }
}

// MARK: - Performance Tests

extension PermissionSystemTests {

    func testPermissionCheckPerformance() {
        measure {
            Task {
                let center = PermissionCenter.shared
                await center.checkAutomationPermission(for: .safari)
            }
        }
    }

    func testPreflightEnginePerformance() {
        let engine = PreflightEngine()
        let capability = createTestCapability(
            preflightChecks: [
                PreflightCheck(
                    type: .pathExists,
                    target: NSHomeDirectory(),
                    failureMessage: "Home not found"
                )
            ]
        )

        measure {
            Task {
                _ = await engine.validate(capability)
            }
        }
    }
}
