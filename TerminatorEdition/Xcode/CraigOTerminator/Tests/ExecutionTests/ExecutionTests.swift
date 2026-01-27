//
//  ExecutionTests.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import XCTest
@testable import CraigOTerminator

// MARK: - Process Runner Tests

final class ProcessRunnerTests: XCTestCase {

    // Test 1: Execute simple command
    func testExecuteEchoCommand() async throws {
        let runner = ProcessRunner()

        let result = try await runner.execute(
            command: "/bin/echo",
            arguments: ["test"],
            timeout: 5
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("test"))
        XCTAssertFalse(result.didTimeout)
    }

    // Test 2: Verify timeout functionality
    func testCommandTimeout() async throws {
        let runner = ProcessRunner()

        let result = try await runner.execute(
            command: "/bin/sleep",
            arguments: ["10"],
            timeout: 2
        )

        XCTAssertTrue(result.didTimeout)
    }

    // Test 3: Capture stderr output
    func testStderrCapture() async throws {
        let runner = ProcessRunner()

        // Use a command that writes to stderr
        let result = try await runner.execute(
            command: "/bin/bash",
            arguments: ["-c", "echo 'error message' >&2"],
            timeout: 5
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("error message"))
    }

    // Test 4: Non-zero exit code
    func testNonZeroExitCode() async throws {
        let runner = ProcessRunner()

        let result = try await runner.execute(
            command: "/bin/bash",
            arguments: ["-c", "exit 42"],
            timeout: 5
        )

        XCTAssertEqual(result.exitCode, 42)
    }

    // Test 5: Stream output callbacks
    func testOutputStreamingCallbacks() async throws {
        let runner = ProcessRunner()
        var stdoutLines: [String] = []
        var stderrLines: [String] = []

        let result = try await runner.execute(
            command: "/bin/bash",
            arguments: ["-c", "echo 'line1'; echo 'line2'; echo 'err' >&2"],
            timeout: 5,
            onStdout: { line in
                stdoutLines.append(line)
            },
            onStderr: { line in
                stderrLines.append(line)
            }
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(stdoutLines.contains("line1"))
        XCTAssertTrue(stdoutLines.contains("line2"))
        XCTAssertTrue(stderrLines.contains("err"))
    }
}

// MARK: - Output Parser Tests

final class OutputParserTests: XCTestCase {

    // Test 1: Text parser
    func testTextParser() {
        let parser = TextParser()
        let output = "Simple text output"

        let result = parser.parse(output, pattern: nil)

        if case let .text(text) = result {
            XCTAssertEqual(text, output)
        } else {
            XCTFail("Expected text output")
        }
    }

    // Test 2: JSON parser
    func testJSONParser() {
        let parser = JSONParser()
        let jsonString = """
        {
            "name": "test",
            "value": 123,
            "active": true
        }
        """

        let result = parser.parse(jsonString, pattern: nil)

        if case let .json(dict) = result {
            XCTAssertEqual(dict.keys.count, 3)
            XCTAssertTrue(dict.keys.contains("name"))
        } else {
            XCTFail("Expected JSON output")
        }
    }

    // Test 3: Regex parser
    func testRegexParser() {
        let parser = RegexParser()
        let output = "Version: 14.2.1 Build: 23C64"
        let pattern = "Version: ([0-9.]+)"

        let result = parser.parse(output, pattern: pattern)

        if case let .regex(captures) = result {
            XCTAssertEqual(captures.count, 2)  // Full match + capture group
            XCTAssertTrue(captures[1].contains("14.2.1"))
        } else {
            XCTFail("Expected regex captures")
        }
    }

    // Test 4: Memory pressure parser
    func testMemoryPressureParser() {
        let parser = MemoryPressureParser()
        let output = """
        System-wide memory free percentage: 45%
        Available memory: 12.5 GB
        Pages free: 3145728
        """

        let result = parser.parse(output, pattern: nil)

        if case let .memoryPressure(info) = result {
            XCTAssertEqual(info.level, "normal")
            XCTAssertGreaterThan(info.availableBytes, 0)
            XCTAssertEqual(info.pagesAvailable, 3145728)
        } else {
            XCTFail("Expected memory pressure output")
        }
    }

    // Test 5: Disk usage parser (df format)
    func testDiskUsageParser() {
        let parser = DiskUsageParser()
        let output = """
        Filesystem     Size   Used  Avail Capacity  iused  ifree %iused  Mounted on
        /dev/disk3s1  932Gi  234Gi  234Gi    51%  12345678 234567   34%   /
        """

        let result = parser.parse(output, pattern: nil)

        if case let .diskUsage(entries) = result {
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries[0].filesystem, "/dev/disk3s1")
            XCTAssertEqual(entries[0].capacity, "51%")
            XCTAssertEqual(entries[0].mountPoint, "/")
        } else {
            XCTFail("Expected disk usage output")
        }
    }

    // Test 6: Process table parser
    func testProcessTableParser() {
        let parser = ProcessTableParser()
        let output = """
        USER    PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
        root    123  0.5  1.2  1234567  89012  ??  Ss    1Jan26   0:01.23 /usr/sbin/mDNSResponder
        _windowserver 234  2.1  3.4  9876543 234567  ??  Ss   1Jan26   5:23.45 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
        """

        let result = parser.parse(output, pattern: nil)

        if case let .processTable(processes) = result {
            XCTAssertEqual(processes.count, 2)
            XCTAssertEqual(processes[0].pid, 123)
            XCTAssertEqual(processes[0].user, "root")
            XCTAssertEqual(processes[0].cpuPercent, 0.5)
        } else {
            XCTFail("Expected process table output")
        }
    }
}

// MARK: - SQLite Log Store Tests

final class SQLiteLogStoreTests: XCTestCase {

    var logStore: SQLiteLogStore!
    var testDBPath: URL!

    override func setUp() async throws {
        // Create temporary database for testing
        let tempDir = FileManager.default.temporaryDirectory
        testDBPath = tempDir.appendingPathComponent("test_logs_\(UUID().uuidString).sqlite")
        let outputDir = tempDir.appendingPathComponent("test_logs_\(UUID().uuidString)")

        logStore = try SQLiteLogStore(dbPath: testDBPath, outputDirectory: outputDir)
    }

    override func tearDown() async throws {
        // Clean up test database
        try? FileManager.default.removeItem(at: testDBPath)
    }

    // Test 1: Save and fetch record
    func testSaveAndFetchRecord() async throws {
        let record = RunRecord(
            timestamp: Date(),
            capabilityId: "test.capability",
            capabilityTitle: "Test Capability",
            privilegeLevel: .user,
            arguments: ["key": "value"],
            durationMs: 100,
            exitCode: 0,
            status: .success,
            stdoutPath: nil,
            stderrPath: nil,
            outputSizeBytes: 1024,
            parsedSummary: "Test summary",
            parsedData: nil,
            previousRecordHash: nil
        )

        try await logStore.save(record)

        let fetched = try await logStore.fetch(limit: 10, offset: 0)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, record.id)
        XCTAssertEqual(fetched[0].capabilityId, "test.capability")
    }

    // Test 2: Fetch by capability ID
    func testFetchByCapabilityId() async throws {
        // Save multiple records
        for i in 0..<5 {
            let record = RunRecord(
                timestamp: Date(),
                capabilityId: i < 3 ? "cap.a" : "cap.b",
                capabilityTitle: "Test \(i)",
                privilegeLevel: .user,
                arguments: [:],
                durationMs: 100,
                exitCode: 0,
                status: .success,
                stdoutPath: nil,
                stderrPath: nil,
                outputSizeBytes: 100,
                parsedSummary: nil,
                parsedData: nil,
                previousRecordHash: nil
            )
            try await logStore.save(record)
        }

        let capARecords = try await logStore.fetch(capabilityId: "cap.a", limit: 10)
        XCTAssertEqual(capARecords.count, 3)

        let capBRecords = try await logStore.fetch(capabilityId: "cap.b", limit: 10)
        XCTAssertEqual(capBRecords.count, 2)
    }

    // Test 3: Fetch recent records
    func testFetchRecent() async throws {
        // Save old record
        let oldRecord = RunRecord(
            timestamp: Date().addingTimeInterval(-48 * 3600),  // 2 days ago
            capabilityId: "old.cap",
            capabilityTitle: "Old",
            privilegeLevel: .user,
            arguments: [:],
            durationMs: 100,
            exitCode: 0,
            status: .success,
            stdoutPath: nil,
            stderrPath: nil,
            outputSizeBytes: 100,
            parsedSummary: nil,
            parsedData: nil,
            previousRecordHash: nil
        )
        try await logStore.save(oldRecord)

        // Save recent record
        let recentRecord = RunRecord(
            timestamp: Date(),
            capabilityId: "recent.cap",
            capabilityTitle: "Recent",
            privilegeLevel: .user,
            arguments: [:],
            durationMs: 100,
            exitCode: 0,
            status: .success,
            stdoutPath: nil,
            stderrPath: nil,
            outputSizeBytes: 100,
            parsedSummary: nil,
            parsedData: nil,
            previousRecordHash: nil
        )
        try await logStore.save(recentRecord)

        // Fetch records from last 24 hours
        let recent = try await logStore.fetchRecent(hours: 24)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].capabilityId, "recent.cap")
    }

    // Test 4: Get last error
    func testGetLastError() async throws {
        // Save successful record
        let successRecord = RunRecord(
            timestamp: Date().addingTimeInterval(-60),
            capabilityId: "success.cap",
            capabilityTitle: "Success",
            privilegeLevel: .user,
            arguments: [:],
            durationMs: 100,
            exitCode: 0,
            status: .success,
            stdoutPath: nil,
            stderrPath: nil,
            outputSizeBytes: 100,
            parsedSummary: nil,
            parsedData: nil,
            previousRecordHash: nil
        )
        try await logStore.save(successRecord)

        // Save failed record
        let failedRecord = RunRecord(
            timestamp: Date(),
            capabilityId: "failed.cap",
            capabilityTitle: "Failed",
            privilegeLevel: .user,
            arguments: [:],
            durationMs: 100,
            exitCode: 1,
            status: .failed,
            stdoutPath: nil,
            stderrPath: nil,
            outputSizeBytes: 100,
            parsedSummary: nil,
            parsedData: nil,
            previousRecordHash: nil
        )
        try await logStore.save(failedRecord)

        let lastError = try await logStore.getLastError()
        XCTAssertNotNil(lastError)
        XCTAssertEqual(lastError?.capabilityId, "failed.cap")
    }

    // Test 5: Export logs
    func testExportLogs() async throws {
        // Save some records
        for i in 0..<3 {
            let record = RunRecord(
                timestamp: Date().addingTimeInterval(Double(i * 60)),
                capabilityId: "cap.\(i)",
                capabilityTitle: "Cap \(i)",
                privilegeLevel: .user,
                arguments: [:],
                durationMs: 100 + i,
                exitCode: 0,
                status: .success,
                stdoutPath: nil,
                stderrPath: nil,
                outputSizeBytes: 100,
                parsedSummary: nil,
                parsedData: nil,
                previousRecordHash: nil
            )
            try await logStore.save(record)
        }

        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date().addingTimeInterval(3600)

        let exportURL = try await logStore.exportLogs(from: startDate, to: endDate)

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Verify exported JSON
        let data = try Data(contentsOf: exportURL)
        let records = try JSONDecoder().decode([RunRecord].self, from: data)
        XCTAssertEqual(records.count, 3)
    }
}

// MARK: - User Executor Tests

final class UserExecutorTests: XCTestCase {

    var executor: UserExecutor!

    override func setUp() async throws {
        executor = UserExecutor()
    }

    // Test 1: Can execute user-level capability
    func testCanExecuteUserLevel() async {
        let capability = Capability(
            id: "test.cap",
            title: "Test",
            description: "Test capability",
            group: .diagnostics,
            commandTemplate: "/bin/echo test",
            arguments: [],
            workingDirectory: nil,
            timeout: 5,
            privilegeLevel: .user,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "star",
            rollbackNotes: nil,
            estimatedDuration: nil
        )

        let canExecute = await executor.canExecute(capability)
        XCTAssertTrue(canExecute)
    }

    // Test 2: Cannot execute elevated capability
    func testCannotExecuteElevated() async {
        let capability = Capability(
            id: "test.cap",
            title: "Test",
            description: "Test capability",
            group: .diagnostics,
            commandTemplate: "/usr/bin/sudo echo test",
            arguments: [],
            workingDirectory: nil,
            timeout: 5,
            privilegeLevel: .elevated,
            riskClass: .moderate,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "star",
            rollbackNotes: nil,
            estimatedDuration: nil
        )

        let canExecute = await executor.canExecute(capability)
        XCTAssertFalse(canExecute)
    }

    // Test 3: Execute simple capability
    func testExecuteSimpleCapability() async throws {
        let capability = Capability(
            id: "test.echo",
            title: "Echo Test",
            description: "Test echo",
            group: .diagnostics,
            commandTemplate: "/bin/echo hello world",
            arguments: [],
            workingDirectory: nil,
            timeout: 5,
            privilegeLevel: .user,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "star",
            rollbackNotes: nil,
            estimatedDuration: nil
        )

        let result = try await executor.execute(capability, arguments: [:])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.stdout.contains("hello world"))
    }

    // Test 4: Argument interpolation
    func testArgumentInterpolation() async throws {
        let capability = Capability(
            id: "test.args",
            title: "Args Test",
            description: "Test arguments",
            group: .diagnostics,
            commandTemplate: "/bin/echo {{message}} {{count}}",
            arguments: ["message", "count"],
            workingDirectory: nil,
            timeout: 5,
            privilegeLevel: .user,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [],
            requiredPaths: [],
            requiredApps: [],
            icon: "star",
            rollbackNotes: nil,
            estimatedDuration: nil
        )

        let result = try await executor.execute(
            capability,
            arguments: ["message": "hello", "count": "3"]
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("hello"))
        XCTAssertTrue(result.stdout.contains("3"))
    }
}
