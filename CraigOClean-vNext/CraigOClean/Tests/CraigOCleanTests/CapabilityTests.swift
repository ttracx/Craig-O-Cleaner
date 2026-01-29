// File: CraigOClean-vNext/CraigOClean/Tests/CraigOCleanTests/CapabilityTests.swift
// Craig-O-Clean - Capability Tests
// Unit tests for capability model and providers

import XCTest
@testable import CraigOClean

final class CapabilityTests: XCTestCase {

    // MARK: - DirectPro Capabilities Tests

    func testDirectProCapabilitiesAllEnabled() {
        let capabilities = DirectProCapabilities.shared.capabilities

        XCTAssertTrue(capabilities.canDeleteSystemWideCaches)
        XCTAssertTrue(capabilities.canDeleteUserCaches)
        XCTAssertTrue(capabilities.canInspectDiskUsage)
        XCTAssertTrue(capabilities.canExportDiagnostics)
        XCTAssertTrue(capabilities.canRunPrivilegedOperations)
        XCTAssertTrue(capabilities.canInstallHelperTool)
        XCTAssertTrue(capabilities.canAutoUpdate)
        XCTAssertTrue(capabilities.canUseExternalLicensing)
    }

    func testDirectProEdition() {
        let provider = DirectProCapabilities.shared

        XCTAssertEqual(provider.edition, .directPro)
        XCTAssertEqual(provider.edition.displayName, "Craig-O-Clean Pro")
    }

    // MARK: - AppStoreLite Capabilities Tests

    func testAppStoreLiteCapabilitiesRestricted() {
        let capabilities = AppStoreLiteCapabilities.shared.capabilities

        // These should be disabled in Lite
        XCTAssertFalse(capabilities.canDeleteSystemWideCaches)
        XCTAssertFalse(capabilities.canInspectDiskUsage)
        XCTAssertFalse(capabilities.canExportDiagnostics)
        XCTAssertFalse(capabilities.canRunPrivilegedOperations)
        XCTAssertFalse(capabilities.canInstallHelperTool)
        XCTAssertFalse(capabilities.canAutoUpdate)
        XCTAssertFalse(capabilities.canUseExternalLicensing)

        // This should still be enabled
        XCTAssertTrue(capabilities.canDeleteUserCaches)
    }

    func testAppStoreLiteEdition() {
        let provider = AppStoreLiteCapabilities.shared

        XCTAssertEqual(provider.edition, .appStoreLite)
        XCTAssertEqual(provider.edition.displayName, "Craig-O-Clean Lite")
    }

    // MARK: - Path Validation Tests

    func testAppStoreLitePathValidation() {
        let provider = AppStoreLiteCapabilities.shared
        let home = NSHomeDirectory()

        // User home paths should be allowed
        XCTAssertTrue(provider.isPathAllowed("\(home)/Library/Caches"))
        XCTAssertTrue(provider.isPathAllowed("\(home)/Library/Logs"))
        XCTAssertTrue(provider.isPathAllowed("\(home)/Documents"))

        // System paths should be blocked
        XCTAssertFalse(provider.isPathAllowed("/Library/Caches"))
        XCTAssertFalse(provider.isPathAllowed("/System/Library"))
        XCTAssertFalse(provider.isPathAllowed("/var/log"))

        // Sensitive user paths should be blocked
        XCTAssertFalse(provider.isPathAllowed("\(home)/.ssh"))
        XCTAssertFalse(provider.isPathAllowed("\(home)/Library/Keychains"))
    }

    func testLiteCannotDeleteOutsideUserHome() {
        let provider = AppStoreLiteCapabilities.shared

        // Verify system paths are blocked
        XCTAssertFalse(provider.isPathAllowed("/Library/Caches"))
        XCTAssertFalse(provider.isPathAllowed("/private/var/folders"))
        XCTAssertFalse(provider.isPathAllowed("/tmp"))
    }

    // MARK: - Capability Info Tests

    func testCapabilityInfoGeneration() {
        let capabilities = DirectProCapabilities.shared.capabilities
        let info = capabilities.allCapabilities(edition: .directPro)

        XCTAssertFalse(info.isEmpty)

        // Check that all capabilities have info
        XCTAssertTrue(info.contains { $0.id == "systemCaches" })
        XCTAssertTrue(info.contains { $0.id == "userCaches" })
        XCTAssertTrue(info.contains { $0.id == "autoUpdate" })
    }

    func testLiteCapabilityInfoShowsUnavailable() {
        let capabilities = AppStoreLiteCapabilities.shared.capabilities
        let info = capabilities.allCapabilities(edition: .appStoreLite)

        // System caches should show as unavailable with reason
        if let systemCachesInfo = info.first(where: { $0.id == "systemCaches" }) {
            XCTAssertFalse(systemCachesInfo.isEnabled)
            XCTAssertNotNil(systemCachesInfo.unavailableReason)
        } else {
            XCTFail("System caches info not found")
        }
    }

    // MARK: - Edition Detection Tests

    func testEditionShortName() {
        XCTAssertEqual(AppEdition.directPro.shortName, "Pro")
        XCTAssertEqual(AppEdition.appStoreLite.shortName, "Lite")
    }

    func testEditionDescription() {
        XCTAssertFalse(AppEdition.directPro.description.isEmpty)
        XCTAssertFalse(AppEdition.appStoreLite.description.isEmpty)
    }

    // MARK: - Capability Provider Factory Tests

    func testCapabilityProviderFactory() {
        let directProProvider = CapabilityProviderFactory.provider(for: .directPro)
        XCTAssertEqual(directProProvider.edition, .directPro)

        let liteProvider = CapabilityProviderFactory.provider(for: .appStoreLite)
        XCTAssertEqual(liteProvider.edition, .appStoreLite)
    }

    // MARK: - Capabilities Equality Tests

    func testCapabilitiesEquality() {
        let cap1 = DirectProCapabilities.shared.capabilities
        let cap2 = DirectProCapabilities.shared.capabilities

        XCTAssertEqual(cap1, cap2)

        let cap3 = AppStoreLiteCapabilities.shared.capabilities
        XCTAssertNotEqual(cap1, cap3)
    }
}
