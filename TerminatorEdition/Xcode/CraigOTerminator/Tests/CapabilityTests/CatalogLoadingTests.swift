//
//  CatalogLoadingTests.swift
//  CraigOTerminator Tests
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import XCTest
@testable import CraigOTerminator

final class CatalogLoadingTests: XCTestCase {

    var catalog: CapabilityCatalog!

    override func setUp() {
        super.setUp()
        catalog = CapabilityCatalog.shared
    }

    override func tearDown() {
        catalog = nil
        super.tearDown()
    }

    // MARK: - Loading Tests

    func testCatalogLoadsSuccessfully() {
        XCTAssertTrue(catalog.isLoaded, "Catalog should load successfully")
        XCTAssertNil(catalog.loadError, "Catalog should not have load error")
    }

    func testCatalogHasCapabilities() {
        XCTAssertGreaterThan(catalog.totalCount, 0, "Catalog should have capabilities")
        XCTAssertEqual(catalog.totalCount, 91, "Catalog should have 91 capabilities")
    }

    func testCatalogVersion() {
        XCTAssertFalse(catalog.version.isEmpty, "Catalog should have version")
        XCTAssertEqual(catalog.version, "1.0.0", "Catalog version should be 1.0.0")
    }

    // MARK: - Lookup Tests

    func testLookupCapabilityById() {
        let capability = catalog.capability(id: "diag.mem.pressure")
        XCTAssertNotNil(capability, "Should find capability by ID")
        XCTAssertEqual(capability?.title, "Memory Pressure")
    }

    func testLookupInvalidId() {
        let capability = catalog.capability(id: "invalid.id")
        XCTAssertNil(capability, "Should return nil for invalid ID")
    }

    func testCapabilitiesByGroup() {
        let diagnostics = catalog.capabilities(group: .diagnostics)
        XCTAssertGreaterThan(diagnostics.count, 0, "Diagnostics group should have capabilities")

        let browsers = catalog.capabilities(group: .browsers)
        XCTAssertGreaterThan(browsers.count, 0, "Browsers group should have capabilities")
    }

    func testAllGroupsHaveCapabilities() {
        for group in CapabilityGroup.allCases {
            let count = catalog.count(for: group)
            XCTAssertGreaterThan(count, 0, "\(group.displayTitle) should have capabilities")
        }
    }

    // MARK: - Search Tests

    func testSearchByTitle() {
        let results = catalog.search(query: "Memory")
        XCTAssertGreaterThan(results.count, 0, "Should find capabilities matching 'Memory'")
    }

    func testSearchByDescription() {
        let results = catalog.search(query: "browser")
        XCTAssertGreaterThan(results.count, 0, "Should find capabilities matching 'browser'")
    }

    func testSearchEmptyQuery() {
        let results = catalog.search(query: "")
        XCTAssertEqual(results.count, 0, "Empty search should return no results")
    }

    // MARK: - Filter Tests

    func testFilterByPrivilegeLevel() {
        let userCapabilities = catalog.capabilities(privilegeLevel: .user)
        XCTAssertGreaterThan(userCapabilities.count, 0, "Should have user-level capabilities")

        let elevatedCapabilities = catalog.capabilities(privilegeLevel: .elevated)
        XCTAssertGreaterThan(elevatedCapabilities.count, 0, "Should have elevated capabilities")

        let automationCapabilities = catalog.capabilities(privilegeLevel: .automation)
        XCTAssertGreaterThan(automationCapabilities.count, 0, "Should have automation capabilities")
    }

    func testFilterByRiskClass() {
        let safeCapabilities = catalog.capabilities(riskClass: .safe)
        XCTAssertGreaterThan(safeCapabilities.count, 0, "Should have safe capabilities")

        let moderateCapabilities = catalog.capabilities(riskClass: .moderate)
        XCTAssertGreaterThan(moderateCapabilities.count, 0, "Should have moderate capabilities")

        let destructiveCapabilities = catalog.capabilities(riskClass: .destructive)
        XCTAssertGreaterThan(destructiveCapabilities.count, 0, "Should have destructive capabilities")
    }

    // MARK: - Statistics Tests

    func testStatistics() {
        let stats = catalog.statistics
        XCTAssertEqual(stats.totalCapabilities, catalog.totalCount)
        XCTAssertEqual(stats.byGroup.count, CapabilityGroup.allCases.count)
    }

    // MARK: - Capability Model Tests

    func testCapabilityHasRequiredFields() {
        guard let capability = catalog.capability(id: "diag.mem.pressure") else {
            XCTFail("Should find test capability")
            return
        }

        XCTAssertFalse(capability.id.isEmpty, "Capability should have ID")
        XCTAssertFalse(capability.title.isEmpty, "Capability should have title")
        XCTAssertFalse(capability.description.isEmpty, "Capability should have description")
        XCTAssertFalse(capability.commandTemplate.isEmpty, "Capability should have command template")
        XCTAssertGreaterThan(capability.timeout, 0, "Capability should have positive timeout")
    }

    func testCapabilityPreflightChecks() {
        // Find capability with preflight checks
        let capability = catalog.capability(id: "quick.restart.finder")
        XCTAssertNotNil(capability, "Should find capability with preflight checks")
        XCTAssertGreaterThan(capability?.preflightChecks.count ?? 0, 0, "Capability should have preflight checks")
    }

    func testBrowserCapabilitiesHaveAutomationPermission() {
        let browserCaps = catalog.capabilities(group: .browsers)
            .filter { $0.privilegeLevel == .automation }

        XCTAssertGreaterThan(browserCaps.count, 0, "Browser group should have automation capabilities")

        for cap in browserCaps {
            XCTAssertEqual(cap.privilegeLevel, .automation, "\(cap.id) should require automation permission")
        }
    }
}
