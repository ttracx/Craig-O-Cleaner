// MARK: - CatalogValidatorTests.swift
// Tests for Capability Catalog validation

import XCTest
@testable import Craig_O_Clean

final class CatalogValidatorTests: XCTestCase {

    // MARK: - Catalog Loading

    func testCatalogLoadsFromBundle() throws {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            // In test context, try loading from source
            XCTSkip("catalog.json not available in test bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(CapabilityCatalogData.self, from: data)

        XCTAssertFalse(catalog.capabilities.isEmpty, "Catalog should have capabilities")
        XCTAssertFalse(catalog.version.isEmpty, "Catalog should have a version")
    }

    // MARK: - Schema Validation

    func testValidCapabilityPassesValidation() {
        let cap = Capability(
            id: "test.valid",
            title: "Valid Test",
            description: "A valid test capability",
            category: .diagnostics,
            executorType: .process,
            commandTemplate: "/usr/bin/test",
            args: [],
            appleScript: nil,
            requiredPrivileges: .user,
            requiredPermissions: [.none],
            riskClass: .safe,
            preflightChecks: [],
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )

        let errors = CatalogValidator.validateCapability(cap)
        XCTAssertTrue(errors.isEmpty, "Valid capability should have no errors: \(errors)")
    }

    func testEmptyIdFailsValidation() {
        let cap = Capability(
            id: "",
            title: "Bad",
            description: "Missing ID",
            category: .diagnostics,
            executorType: .process,
            commandTemplate: "/usr/bin/test",
            args: nil,
            appleScript: nil,
            requiredPrivileges: .user,
            requiredPermissions: [.none],
            riskClass: .safe,
            preflightChecks: [],
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )

        let errors = CatalogValidator.validateCapability(cap)
        XCTAssertTrue(errors.contains { $0.contains("empty ID") })
    }

    func testProcessWithoutCommandFailsValidation() {
        let cap = Capability(
            id: "test.nocommand",
            title: "No Command",
            description: "Process with no command",
            category: .diagnostics,
            executorType: .process,
            commandTemplate: nil,
            args: nil,
            appleScript: nil,
            requiredPrivileges: .user,
            requiredPermissions: [.none],
            riskClass: .safe,
            preflightChecks: [],
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )

        let errors = CatalogValidator.validateCapability(cap)
        XCTAssertTrue(errors.contains { $0.contains("commandTemplate") })
    }

    func testAppleEventsWithoutScriptFailsValidation() {
        let cap = Capability(
            id: "test.noscript",
            title: "No Script",
            description: "AppleEvents with no script",
            category: .browsers,
            executorType: .appleEvents,
            commandTemplate: nil,
            args: nil,
            appleScript: nil,
            requiredPrivileges: .user,
            requiredPermissions: [.automationSafari],
            riskClass: .safe,
            preflightChecks: [],
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )

        let errors = CatalogValidator.validateCapability(cap)
        XCTAssertTrue(errors.contains { $0.contains("appleScript") })
    }

    func testDestructiveWithoutConfirmFailsValidation() {
        let cap = Capability(
            id: "test.noconfirm",
            title: "No Confirm",
            description: "Destructive with no confirm text",
            category: .deepClean,
            executorType: .process,
            commandTemplate: "/bin/rm",
            args: ["-rf"],
            appleScript: nil,
            requiredPrivileges: .user,
            requiredPermissions: [.none],
            riskClass: .destructive,
            preflightChecks: [],
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )

        let errors = CatalogValidator.validateCapability(cap)
        XCTAssertTrue(errors.contains { $0.contains("confirmText") })
    }

    // MARK: - Duplicate ID Detection

    func testDuplicateIdsDetected() {
        let cap1 = makeCapability(id: "test.dup")
        let cap2 = makeCapability(id: "test.dup")

        let catalog = CapabilityCatalogData(version: "1.0", generatedAt: "2026-01-27", capabilities: [cap1, cap2])
        let errors = CatalogValidator.validate(catalog)

        XCTAssertTrue(errors.contains { $0.contains("Duplicate") })
    }

    // MARK: - Allowlist Check

    func testAllowlistRejectsUnknownId() {
        let catalog = CapabilityCatalogData(version: "1.0", generatedAt: "2026-01-27", capabilities: [makeCapability(id: "test.known")])
        XCTAssertTrue(CatalogValidator.isAllowed("test.known", in: catalog))
        XCTAssertFalse(CatalogValidator.isAllowed("test.unknown", in: catalog))
    }

    // MARK: - Helpers

    private func makeCapability(id: String) -> Capability {
        return Capability(
            id: id,
            title: "Test",
            description: "Test capability",
            category: .diagnostics,
            executorType: .process,
            commandTemplate: "/usr/bin/true",
            args: [],
            appleScript: nil,
            requiredPrivileges: .user,
            requiredPermissions: [.none],
            riskClass: .safe,
            preflightChecks: [],
            dryRunSupport: false,
            dryRunVariant: nil,
            outputParsing: .none,
            rollbackNotes: nil,
            uiHints: nil
        )
    }
}
