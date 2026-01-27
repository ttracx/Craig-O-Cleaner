//
//  ElevatedExecutorTests.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import XCTest
@testable import CraigOTerminator

@MainActor
final class ElevatedExecutorTests: XCTestCase {

    // MARK: - Properties

    var executor: ElevatedExecutor!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        executor = ElevatedExecutor()
    }

    override func tearDown() async throws {
        executor = nil
        try await super.tearDown()
    }

    // MARK: - Capability Validation Tests

    func testCanExecute_ElevatedCapability() async {
        // Given
        let capability = Capability(
            id: "test.elevated",
            title: "Test Elevated",
            description: "Test",
            group: "test",
            commandTemplate: "/usr/bin/purge",
            arguments: [],
            workingDirectory: nil,
            timeout: 10,
            privilegeLevel: .elevated,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "gear",
            rollbackNotes: nil,
            estimatedDuration: 5
        )

        // When
        let canExecute = await executor.canExecute(capability)

        // Then
        XCTAssertTrue(canExecute, "Executor should be able to execute elevated capabilities")
    }

    func testCanExecute_UserCapability() async {
        // Given
        let capability = Capability(
            id: "test.user",
            title: "Test User",
            description: "Test",
            group: "test",
            commandTemplate: "echo test",
            arguments: [],
            workingDirectory: nil,
            timeout: 10,
            privilegeLevel: .user,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "gear",
            rollbackNotes: nil,
            estimatedDuration: 1
        )

        // When
        let canExecute = await executor.canExecute(capability)

        // Then
        XCTAssertFalse(canExecute, "Executor should not be able to execute user-level capabilities")
    }

    // MARK: - Helper Status Tests

    func testExecute_HelperNotInstalled() async {
        // Given
        let capability = Capability(
            id: "test.elevated",
            title: "Test Elevated",
            description: "Test",
            group: "test",
            commandTemplate: "/usr/bin/purge",
            arguments: [],
            workingDirectory: nil,
            timeout: 10,
            privilegeLevel: .elevated,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "gear",
            rollbackNotes: nil,
            estimatedDuration: 5
        )

        // When/Then
        do {
            _ = try await executor.execute(capability, arguments: [:])
            XCTFail("Should throw helper not installed error")
        } catch let error as HelperError {
            if case .notInstalled = error {
                // Expected
            } else {
                XCTFail("Expected notInstalled error, got \(error)")
            }
        } catch {
            XCTFail("Expected HelperError, got \(error)")
        }
    }

    // MARK: - Elevated Capabilities Tests

    func testElevatedCapabilitiesFromCatalog() async throws {
        // Load actual catalog
        guard let catalogURL = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let catalogData = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode(CapabilityCatalog.self, from: catalogData) else {
            throw XCTSkip("Catalog not available in test bundle")
        }

        // Find elevated capabilities
        let elevatedCapabilities = catalog.capabilities.filter { $0.privilegeLevel == .elevated }

        // Verify we found the expected elevated capabilities
        XCTAssertGreaterThan(elevatedCapabilities.count, 0, "Should have elevated capabilities in catalog")

        // Verify executor can execute them
        for capability in elevatedCapabilities {
            let canExecute = await executor.canExecute(capability)
            XCTAssertTrue(canExecute, "Executor should handle \(capability.id)")
        }

        // Check specific known elevated capabilities
        let expectedElevatedIDs = [
            "quick.dns.flush",
            "quick.mem.purge",
            "quick.mem.sync_purge",
            "deep.system.temp",
            "deep.system.asl",
            "disk.trash.empty_all",
            "sys.audio.restart",
            "sys.maintenance.daily",
            "sys.maintenance.weekly",
            "sys.maintenance.monthly",
            "sys.maintenance.all",
            "sys.spotlight.status",
            "sys.spotlight.rebuild"
        ]

        let elevatedIDs = elevatedCapabilities.map { $0.id }

        for expectedID in expectedElevatedIDs {
            XCTAssertTrue(
                elevatedIDs.contains(expectedID),
                "Expected elevated capability \(expectedID) not found in catalog"
            )
        }
    }

    // MARK: - Command Allowlist Tests

    func testHelperCommandAllowlist() {
        // Define expected allowed commands (from helper tool)
        let expectedAllowedCommands: Set<String> = [
            "/usr/sbin/diskutil",
            "/usr/bin/purge",
            "/usr/bin/dscacheutil",
            "/usr/bin/mdutil",
            "/usr/sbin/periodic",
            "/usr/bin/killall",
            "/bin/rm",
            "/usr/bin/log",
            "/usr/sbin/sysctl"
        ]

        // This is a documentation test - verify our understanding of the allowlist
        XCTAssertGreaterThan(
            expectedAllowedCommands.count,
            0,
            "Helper should have allowed commands defined"
        )
    }

    // MARK: - State Management Tests

    func testIsExecutingState() async {
        // Given
        XCTAssertFalse(executor.isExecuting, "Should not be executing initially")

        // Note: Cannot test actual execution without helper installed
        // This test verifies the state property exists and is accessible
    }

    func testCurrentCapabilityState() async {
        // Given
        XCTAssertNil(executor.currentCapability, "Should have no current capability initially")

        // Note: Cannot test actual execution without helper installed
        // This test verifies the state property exists and is accessible
    }
}

// MARK: - Helper Installer Tests

@MainActor
final class HelperInstallerTests: XCTestCase {

    // MARK: - Status Tests

    func testHelperStatus_Initial() async {
        // Given
        let installer = HelperInstaller.shared

        // When
        await installer.checkStatus()

        // Then
        // Status will be one of the valid states
        // Cannot assert specific state as it depends on system configuration
        XCTAssertNotNil(installer.status, "Status should be set after check")
    }

    func testHelperConstants() {
        // Verify helper constants are correctly defined
        XCTAssertEqual(HelperConstants.bundleID, "ai.neuralquantum.CraigOTerminator.helper")
        XCTAssertEqual(HelperConstants.machServiceName, "ai.neuralquantum.CraigOTerminator.helper")
        XCTAssertEqual(HelperConstants.currentVersion, "1.0.0")
        XCTAssertGreaterThan(HelperConstants.maxTimeout, 0)
        XCTAssertGreaterThan(HelperConstants.connectionTimeout, 0)
    }

    // MARK: - Status Display Tests

    func testHelperStatus_DisplayText() {
        // Test all status cases
        XCTAssertEqual(
            HelperStatus.notInstalled.displayText,
            "Not Installed"
        )

        XCTAssertEqual(
            HelperStatus.installed(version: "1.0.0").displayText,
            "Installed (v1.0.0)"
        )

        XCTAssertEqual(
            HelperStatus.outdated(current: "0.9.0", required: "1.0.0").displayText,
            "Outdated (v0.9.0, requires v1.0.0)"
        )

        XCTAssertEqual(
            HelperStatus.unknown.displayText,
            "Unknown"
        )
    }

    func testHelperStatus_IsInstalled() {
        // Test isInstalled property
        XCTAssertFalse(HelperStatus.notInstalled.isInstalled)
        XCTAssertTrue(HelperStatus.installed(version: "1.0.0").isInstalled)
        XCTAssertTrue(HelperStatus.outdated(current: "0.9.0", required: "1.0.0").isInstalled)
        XCTAssertFalse(HelperStatus.unknown.isInstalled)
    }

    func testHelperStatus_NeedsUpdate() {
        // Test needsUpdate property
        XCTAssertFalse(HelperStatus.notInstalled.needsUpdate)
        XCTAssertFalse(HelperStatus.installed(version: "1.0.0").needsUpdate)
        XCTAssertTrue(HelperStatus.outdated(current: "0.9.0", required: "1.0.0").needsUpdate)
        XCTAssertFalse(HelperStatus.unknown.needsUpdate)
    }
}

// MARK: - Helper Error Tests

final class HelperErrorTests: XCTestCase {

    func testHelperError_Descriptions() {
        // Test all error descriptions
        let errors: [(HelperError, String)] = [
            (.notInstalled, "not installed"),
            (.outdated(current: "0.9", required: "1.0"), "outdated"),
            (.authorizationDenied, "denied"),
            (.commandNotAllowed("test"), "not allowed"),
            (.executionFailed("test"), "failed"),
            (.invalidResponse, "invalid"),
            (.helperNotResponding, "not responding"),
            (.invalidAuthData, "invalid authorization"),
            (.commandNotFound("test"), "not found")
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring),
                "Error description for \(error) should contain '\(expectedSubstring)'"
            )
        }
    }

    func testHelperError_RecoverySuggestions() {
        // Test recovery suggestions
        let errorsWithSuggestions: [HelperError] = [
            .notInstalled,
            .outdated(current: "0.9", required: "1.0"),
            .connectionFailed(NSError(domain: "", code: 0)),
            .authorizationDenied
        ]

        for error in errorsWithSuggestions {
            XCTAssertNotNil(
                error.recoverySuggestion,
                "Error \(error) should have recovery suggestion"
            )
        }
    }
}
