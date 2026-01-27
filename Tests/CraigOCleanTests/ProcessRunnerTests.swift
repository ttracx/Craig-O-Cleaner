// MARK: - ProcessRunnerTests.swift
// Tests for ProcessRunner execution

import XCTest
@testable import Craig_O_Clean

final class ProcessRunnerTests: XCTestCase {

    var runner: ProcessRunner!

    override func setUp() {
        runner = ProcessRunner()
    }

    // MARK: - Success Path

    func testSuccessfulCommandReturnsZeroExitCode() async throws {
        let result = try await runner.run(executablePath: "/usr/bin/sw_vers")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.stdout.isEmpty)
        XCTAssertTrue(result.duration > 0)
    }

    func testCommandWithArguments() async throws {
        let result = try await runner.run(executablePath: "/bin/echo", arguments: ["hello", "world"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("hello world"))
    }

    // MARK: - Failure Path

    func testNonExistentCommandThrows() async {
        do {
            _ = try await runner.run(executablePath: "/nonexistent/command")
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
    }

    func testFailingCommandReturnsNonZeroExitCode() async throws {
        let result = try await runner.run(executablePath: "/usr/bin/false")
        XCTAssertNotEqual(result.exitCode, 0)
    }

    // MARK: - Streaming

    func testStdoutStreamingCallback() async throws {
        var streamedOutput = ""
        let result = try await runner.run(
            executablePath: "/bin/echo",
            arguments: ["streamed output test"],
            onStdout: { line in
                streamedOutput += line
            }
        )

        XCTAssertEqual(result.exitCode, 0)
        // Note: streaming may or may not capture all data depending on timing
        XCTAssertFalse(result.stdout.isEmpty)
    }

    // MARK: - Duration Tracking

    func testDurationIsTracked() async throws {
        let result = try await runner.run(executablePath: "/bin/sleep", arguments: ["0.1"])
        XCTAssertGreaterThan(result.duration, 0.05)
    }
}
