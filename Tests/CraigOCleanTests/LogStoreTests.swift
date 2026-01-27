// MARK: - LogStoreTests.swift
// Tests for LogStore persistence

import XCTest
@testable import Craig_O_Clean

@MainActor
final class LogStoreTests: XCTestCase {

    // MARK: - RunRecord Creation

    func testRunRecordFormatsDurationCorrectly() {
        let fast = RunRecord(
            capabilityId: "test.fast",
            capabilityTitle: "Fast",
            category: "Diagnostics",
            privilegeLevel: "user",
            durationMs: 500,
            exitCode: 0,
            success: true
        )
        XCTAssertEqual(fast.formattedDuration, "500ms")

        let slow = RunRecord(
            capabilityId: "test.slow",
            capabilityTitle: "Slow",
            category: "Diagnostics",
            privilegeLevel: "user",
            durationMs: 3500,
            exitCode: 0,
            success: true
        )
        XCTAssertEqual(slow.formattedDuration, "3.5s")
    }

    func testRunRecordCodable() throws {
        let record = RunRecord(
            capabilityId: "test.codable",
            capabilityTitle: "Codable Test",
            category: "Diagnostics",
            privilegeLevel: "user",
            durationMs: 100,
            exitCode: 0,
            success: true,
            parsedSummaryJSON: "test summary"
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(RunRecord.self, from: data)

        XCTAssertEqual(decoded.capabilityId, record.capabilityId)
        XCTAssertEqual(decoded.success, record.success)
        XCTAssertEqual(decoded.parsedSummaryJSON, record.parsedSummaryJSON)
    }
}
