// MARK: - PreflightEngineTests.swift
// Tests for PreflightEngine gating logic

import XCTest
@testable import Craig_O_Clean

@MainActor
final class PreflightEngineTests: XCTestCase {

    var engine: PreflightEngine!

    override func setUp() async throws {
        engine = PreflightEngine()
    }

    // MARK: - Path Exists Check

    func testPathExistsCheckPassesForValidPath() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .pathExists, value: "/usr/bin", message: "Path not found")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertTrue(result.passed, "Should pass for existing path")
    }

    func testPathExistsCheckFailsForInvalidPath() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .pathExists, value: "/nonexistent/path/foo", message: "Path not found")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertFalse(result.passed, "Should fail for non-existent path")
    }

    // MARK: - Command Exists Check

    func testCommandExistsCheckPassesForValidCommand() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .commandExists, value: "/usr/bin/sw_vers", message: "Not found")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertTrue(result.passed, "Should pass for existing command")
    }

    func testCommandExistsCheckFailsForMissingCommand() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .commandExists, value: "/usr/bin/nonexistent_tool_xyz", message: "Not found")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertFalse(result.passed, "Should fail for missing command")
    }

    // MARK: - OS Version Check

    func testMinOSVersionCheckPasses() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .minOSVersion, value: "10.0", message: "Too old")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertTrue(result.passed, "Should pass for a very low OS version requirement")
    }

    func testMinOSVersionCheckFailsForFutureVersion() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .minOSVersion, value: "99.0", message: "Requires macOS 99")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertFalse(result.passed, "Should fail for a future OS version")
    }

    // MARK: - SIP Note (Informational, Never Fails)

    func testSipNoteNeverFails() async {
        let cap = makeCapability(preflightChecks: [
            PreflightCheck(type: .sipNote, value: "/System/Library", message: "SIP protected")
        ])

        let result = await engine.runChecks(for: cap)
        XCTAssertTrue(result.passed, "SIP notes should never cause preflight failure")
    }

    // MARK: - No Checks (Always Pass)

    func testNoChecksAlwaysPasses() async {
        let cap = makeCapability(preflightChecks: [])
        let result = await engine.runChecks(for: cap)
        XCTAssertTrue(result.passed)
    }

    // MARK: - Helpers

    private func makeCapability(
        preflightChecks: [PreflightCheck],
        permissions: [RequiredPermission] = [.none],
        privilege: PrivilegeLevel = .user
    ) -> Capability {
        return Capability(
            id: "test.preflight",
            title: "Preflight Test",
            description: "Test",
            category: .diagnostics,
            executorType: .process,
            commandTemplate: "/usr/bin/true",
            args: [],
            appleScript: nil,
            requiredPrivileges: privilege,
            requiredPermissions: permissions,
            riskClass: .safe,
            preflightChecks: preflightChecks,
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )
    }
}
