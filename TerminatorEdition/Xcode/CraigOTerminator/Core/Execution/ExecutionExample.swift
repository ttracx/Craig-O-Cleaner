//
//  ExecutionExample.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//
//  USAGE EXAMPLES for Slice B: Non-Privileged Executor
//

import Foundation

// MARK: - Example 1: Simple Command Execution

func exampleSimpleExecution() async throws {
    let catalog = CapabilityCatalog.shared
    let executor = UserExecutor()

    // Execute system version diagnostic
    if let capability = catalog.capability(id: "diag.sys.version") {
        let result = try await executor.execute(capability, arguments: [:])

        print("Exit code: \(result.exitCode)")
        print("Status: \(result.status.rawValue)")
        print("Duration: \(result.endTime.timeIntervalSince(result.startTime))s")

        if let parsed = result.parsedOutput {
            print("Parsed output: \(parsed)")
        }
    }
}

// MARK: - Example 2: Memory Pressure Diagnostic

func exampleMemoryPressure() async throws {
    let catalog = CapabilityCatalog.shared
    let executor = UserExecutor()

    if let capability = catalog.capability(id: "diag.mem.pressure") {
        let result = try await executor.execute(capability, arguments: [:])

        if case let .memoryPressure(info) = result.parsedOutput {
            print("Memory Level: \(info.level)")
            print("Available: \(ByteCountFormatter.string(fromByteCount: info.availableBytes, countStyle: .memory))")
            print("Pages Available: \(info.pagesAvailable)")
        }
    }
}

// MARK: - Example 3: Disk Usage Check

func exampleDiskUsage() async throws {
    let catalog = CapabilityCatalog.shared
    let executor = UserExecutor()

    if let capability = catalog.capability(id: "diag.disk.root") {
        let result = try await executor.execute(capability, arguments: [:])

        if case let .diskUsage(entries) = result.parsedOutput {
            for entry in entries {
                print("Filesystem: \(entry.filesystem ?? "N/A")")
                print("Size: \(entry.size), Used: \(entry.used), Available: \(entry.available)")
                print("Capacity: \(entry.capacity)")
                if let mount = entry.mountPoint {
                    print("Mounted at: \(mount)")
                }
                print("---")
            }
        }
    }
}

// MARK: - Example 4: Query Recent Logs

func exampleQueryLogs() async throws {
    let logStore = SQLiteLogStore.shared

    // Get last 10 executions
    let recentLogs = try await logStore.fetch(limit: 10, offset: 0)
    print("Recent executions: \(recentLogs.count)")

    for record in recentLogs {
        print("\(record.timestamp): \(record.capabilityTitle) - \(record.status.rawValue)")
        print("  Duration: \(record.durationMs)ms")
        print("  Exit code: \(record.exitCode)")
        if let summary = record.parsedSummary {
            print("  Summary: \(summary)")
        }
    }
}

// MARK: - Example 5: Error Handling

func exampleErrorHandling() async throws {
    let catalog = CapabilityCatalog.shared
    let executor = UserExecutor()

    if let capability = catalog.capability(id: "diag.mem.pressure") {
        do {
            let result = try await executor.execute(capability, arguments: [:])
            print("Success: \(result.status)")
        } catch let error as UserExecutorError {
            print("Execution error: \(error.localizedDescription)")

            // Check log store for error details
            if let lastError = try await SQLiteLogStore.shared.getLastError() {
                print("Last error record:")
                print("  Capability: \(lastError.capabilityTitle)")
                print("  Exit code: \(lastError.exitCode)")
                print("  Status: \(lastError.status.rawValue)")
            }
        }
    }
}

// MARK: - Example 6: Export Logs

func exampleExportLogs() async throws {
    let logStore = SQLiteLogStore.shared

    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    let endDate = Date()

    let exportURL = try await logStore.exportLogs(from: startDate, to: endDate)
    print("Logs exported to: \(exportURL.path)")
}

// MARK: - Example 7: Capability Filtering

func exampleCapabilityFiltering() async {
    let catalog = CapabilityCatalog.shared
    let executor = UserExecutor()

    // Get all user-level capabilities
    var userCapabilities: [Capability] = []
    for capability in catalog.allCapabilities() {
        if await executor.canExecute(capability) {
            userCapabilities.append(capability)
        }
    }

    print("User-level capabilities: \(userCapabilities.count)")

    // Group by category
    for group in CapabilityGroup.allCases {
        let groupCaps = catalog.capabilities(group: group)
            .filter { $0.privilegeLevel == .user }

        if !groupCaps.isEmpty {
            print("\(group.displayTitle): \(groupCaps.count) capabilities")
            for cap in groupCaps {
                print("  - \(cap.title)")
            }
        }
    }
}

// MARK: - Example 8: Real-time Output Streaming

func exampleOutputStreaming() async throws {
    let processRunner = ProcessRunner()

    print("Starting long-running command...")

    let result = try await processRunner.execute(
        command: "/bin/bash",
        arguments: ["-c", "for i in {1..5}; do echo 'Line $i'; sleep 1; done"],
        timeout: 10,
        onStdout: { line in
            print("[STDOUT] \(line)")
        },
        onStderr: { line in
            print("[STDERR] \(line)")
        }
    )

    print("Command completed with exit code: \(result.exitCode)")
}

// MARK: - Example 9: Timeout Handling

func exampleTimeout() async throws {
    let processRunner = ProcessRunner()

    do {
        // This will timeout after 2 seconds
        let result = try await processRunner.execute(
            command: "/bin/sleep",
            arguments: ["10"],
            timeout: 2
        )

        if result.didTimeout {
            print("Command timed out as expected")
        }

    } catch ProcessRunnerError.timeout {
        print("Caught timeout error")
    }
}

// MARK: - Example 10: Complete Workflow

func exampleCompleteWorkflow() async throws {
    print("=== Craig-O-Clean Execution Example ===\n")

    let catalog = CapabilityCatalog.shared
    let executor = UserExecutor()

    // 1. Check catalog is loaded
    guard catalog.isLoaded else {
        print("Error: Catalog not loaded")
        return
    }

    print("Catalog loaded: \(catalog.totalCount) capabilities\n")

    // 2. Run diagnostics
    let diagnosticIds = [
        "diag.sys.version",
        "diag.mem.pressure",
        "diag.disk.root"
    ]

    for capId in diagnosticIds {
        guard let capability = catalog.capability(id: capId) else {
            print("Capability not found: \(capId)")
            continue
        }

        print("Running: \(capability.title)...")

        do {
            let result = try await executor.execute(capability)

            print("  Status: \(result.status.rawValue)")
            print("  Exit code: \(result.exitCode)")

            if let parsed = result.parsedOutput {
                switch parsed {
                case .text(let text):
                    print("  Output: \(text.prefix(100))...")
                case .memoryPressure(let info):
                    print("  Memory: \(info.level)")
                case .diskUsage(let entries):
                    print("  Disk entries: \(entries.count)")
                default:
                    print("  Parsed successfully")
                }
            }

        } catch {
            print("  Error: \(error.localizedDescription)")
        }

        print("")
    }

    // 3. Query execution history
    let recentLogs = try await SQLiteLogStore.shared.fetch(limit: 5, offset: 0)
    print("Recent execution history (\(recentLogs.count) records):")

    for record in recentLogs {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        print("  [\(formatter.string(from: record.timestamp))] \(record.capabilityTitle)")
        print("    Status: \(record.status.rawValue), Duration: \(record.durationMs)ms")
    }

    print("\n=== Example Complete ===")
}
