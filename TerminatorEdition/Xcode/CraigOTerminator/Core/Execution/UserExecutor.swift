//
//  UserExecutor.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import AppKit
import os.log

// MARK: - Capability Executor Protocol

protocol CapabilityExecutor {
    func canExecute(_ capability: Capability) async -> Bool
    func execute(
        _ capability: Capability,
        arguments: [String: String]
    ) async throws -> ExecutionResultWithOutput
}

// MARK: - Execution Result

struct ExecutionResultWithOutput {
    let capabilityId: String
    let startTime: Date
    let endTime: Date
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let parsedOutput: ParsedOutput?
    let status: ExecutionStatus
}

// MARK: - User Executor Errors

enum UserExecutorError: LocalizedError {
    case notUserLevel(String)
    case preflightCheckFailed(String)
    case preflightValidationFailed(PreflightResult)
    case argumentInterpolationFailed(String)
    case executionFailed(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notUserLevel(let message):
            return "Not a user-level capability: \(message)"
        case .preflightCheckFailed(let message):
            return "Preflight check failed: \(message)"
        case .preflightValidationFailed(let result):
            return "Preflight validation failed:\n\(result.summary)"
        case .argumentInterpolationFailed(let message):
            return "Failed to interpolate arguments: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .parsingFailed(let message):
            return "Failed to parse output: \(message)"
        }
    }
}

// MARK: - User Executor

/// Executor for user-level (non-privileged) commands with full logging support
@Observable
final class UserExecutor: CapabilityExecutor {

    // MARK: - Dependencies
    private let processRunner: ProcessRunner
    private let logStore: SQLiteLogStore
    private let preflightEngine: PreflightEngine
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "UserExecutor")

    // MARK: - Observable State
    private(set) var isExecuting: Bool = false
    private(set) var currentCapability: Capability?
    private(set) var lastExecution: ExecutionResultWithOutput?

    // MARK: - Initialization

    init(
        processRunner: ProcessRunner = ProcessRunner(),
        logStore: SQLiteLogStore = .shared,
        preflightEngine: PreflightEngine = PreflightEngine()
    ) {
        self.processRunner = processRunner
        self.logStore = logStore
        self.preflightEngine = preflightEngine
    }

    // MARK: - Command Executor Protocol

    func canExecute(_ capability: Capability) async -> Bool {
        capability.privilegeLevel == .user
    }

    func execute(
        _ capability: Capability,
        arguments: [String: String] = [:]
    ) async throws -> ExecutionResultWithOutput {

        logger.info("Executing capability: \(capability.id)")

        // Validate capability is user-level
        guard await canExecute(capability) else {
            throw UserExecutorError.notUserLevel("Capability \(capability.id) requires \(capability.privilegeLevel.rawValue) privilege")
        }

        // Update state
        isExecuting = true
        currentCapability = capability
        defer {
            isExecuting = false
            currentCapability = nil
        }

        // Run preflight validation with PreflightEngine
        let preflightResult = await preflightEngine.validate(capability)
        guard preflightResult.canExecute else {
            logger.error("Preflight validation failed: \(preflightResult.summary)")
            throw UserExecutorError.preflightValidationFailed(preflightResult)
        }

        logger.debug("Preflight validation passed for \(capability.id)")

        // Interpolate command template with arguments
        let (command, commandArgs) = try interpolateCommand(capability, arguments: arguments)

        // Execute command
        let startTime = Date()
        let processResult: ExecutionResult

        do {
            processResult = try await processRunner.execute(
                command: command,
                arguments: commandArgs,
                workingDirectory: capability.workingDirectory.map { URL(fileURLWithPath: $0) },
                timeout: capability.timeout,
                onStdout: { line in
                    self.logger.debug("[stdout] \(line)")
                },
                onStderr: { line in
                    self.logger.warning("[stderr] \(line)")
                }
            )
        } catch {
            let endTime = Date()
            let status: ExecutionStatus = {
                if error is ProcessRunnerError {
                    switch error as! ProcessRunnerError {
                    case .timeout:
                        return .timeout
                    case .cancelled:
                        return .cancelled
                    default:
                        return .failed
                    }
                }
                return .failed
            }()

            // Create failed result
            let result = ExecutionResultWithOutput(
                capabilityId: capability.id,
                startTime: startTime,
                endTime: endTime,
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                parsedOutput: nil,
                status: status
            )

            // Log the failure
            try await logExecution(capability, arguments: arguments, result: result)

            throw UserExecutorError.executionFailed(error.localizedDescription)
        }

        let endTime = Date()

        // Determine status
        let status: ExecutionStatus = {
            if processResult.didTimeout {
                return .timeout
            } else if processResult.exitCode == 0 {
                return .success
            } else {
                return .failed
            }
        }()

        // Parse output
        let parsedOutput = parseOutput(capability, stdout: processResult.stdout)

        // Create result
        let result = ExecutionResultWithOutput(
            capabilityId: capability.id,
            startTime: startTime,
            endTime: endTime,
            exitCode: processResult.exitCode,
            stdout: processResult.stdout,
            stderr: processResult.stderr,
            parsedOutput: parsedOutput,
            status: status
        )

        // Log the execution
        try await logExecution(capability, arguments: arguments, result: result)

        // Store for UI
        lastExecution = result

        logger.info("Execution completed: \(capability.id), status=\(status.rawValue), exitCode=\(processResult.exitCode)")

        return result
    }

    // MARK: - Preflight Checks

    private func runPreflightChecks(_ capability: Capability) async throws {
        logger.debug("Running \(capability.preflightChecks.count) preflight checks")

        for check in capability.preflightChecks {
            try await runPreflightCheck(check)
        }
    }

    private func runPreflightCheck(_ check: PreflightCheck) async throws {
        logger.debug("Preflight check: \(check.type.rawValue) for \(check.target)")

        switch check.type {
        case .pathExists:
            let url = URL(fileURLWithPath: check.target)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw UserExecutorError.preflightCheckFailed(check.failureMessage)
            }

        case .pathWritable:
            let url = URL(fileURLWithPath: check.target)
            guard FileManager.default.isWritableFile(atPath: url.path) else {
                throw UserExecutorError.preflightCheckFailed(check.failureMessage)
            }

        case .diskSpaceAvailable:
            // Parse target as number of bytes required
            guard let requiredBytes = Int64(check.target) else {
                throw UserExecutorError.preflightCheckFailed("Invalid disk space requirement: \(check.target)")
            }

            if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
               let freeSpace = attributes[.systemFreeSize] as? Int64 {
                guard freeSpace >= requiredBytes else {
                    throw UserExecutorError.preflightCheckFailed(check.failureMessage)
                }
            }

        case .appRunning, .appNotRunning:
            // Check if application is running using NSWorkspace
            let runningApps = NSWorkspace.shared.runningApplications
            let isRunning = runningApps.contains { app in
                app.bundleIdentifier == check.target ||
                app.localizedName == check.target
            }

            if check.type == .appRunning && !isRunning {
                throw UserExecutorError.preflightCheckFailed(check.failureMessage)
            } else if check.type == .appNotRunning && isRunning {
                throw UserExecutorError.preflightCheckFailed(check.failureMessage)
            }

        case .sipStatus:
            // SIP status check (would require csrutil status parsing)
            logger.warning("SIP status check not fully implemented")

        case .automationPermission:
            // Automation permission check (requires TCC database query or AppleScript test)
            logger.warning("Automation permission check not fully implemented")
        }
    }

    // MARK: - Command Interpolation

    private func interpolateCommand(
        _ capability: Capability,
        arguments: [String: String]
    ) throws -> (command: String, arguments: [String]) {

        logger.debug("Interpolating command template: \(capability.commandTemplate)")

        // Parse command template (format: "/path/to/command arg1 {{placeholder}} arg2")
        var template = capability.commandTemplate

        // Replace all placeholders with values
        for (key, value) in arguments {
            let placeholder = "{{\(key)}}"
            template = template.replacingOccurrences(of: placeholder, with: value)
        }

        // Check for unreplaced placeholders
        let placeholderPattern = "\\{\\{[^}]+\\}\\}"
        if let regex = try? NSRegularExpression(pattern: placeholderPattern),
           regex.firstMatch(in: template, range: NSRange(template.startIndex..., in: template)) != nil {
            throw UserExecutorError.argumentInterpolationFailed("Unresolved placeholders in: \(template)")
        }

        // Split into command and arguments
        let components = template.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        guard !components.isEmpty else {
            throw UserExecutorError.argumentInterpolationFailed("Empty command template")
        }

        let command = components[0]
        let commandArgs = Array(components.dropFirst())

        logger.debug("Interpolated: \(command) \(commandArgs.joined(separator: " "))")

        return (command, commandArgs)
    }

    // MARK: - Output Parsing

    private func parseOutput(_ capability: Capability, stdout: String) -> ParsedOutput? {
        logger.debug("Parsing output with parser: \(capability.outputParser.rawValue)")

        let parser = OutputParserFactory.parser(for: capability.outputParser)
        let result = parser.parse(stdout, pattern: capability.parserPattern)

        if result == nil {
            logger.warning("Parser returned nil for \(capability.outputParser.rawValue)")
        }

        return result
    }

    // MARK: - Logging

    private func logExecution(
        _ capability: Capability,
        arguments: [String: String],
        result: ExecutionResultWithOutput
    ) async throws {

        logger.debug("Creating run record for \(capability.id)")

        // Save large outputs to files
        let stdoutPath = try await logStore.saveOutputToFile(
            result.stdout,
            prefix: "stdout",
            recordId: UUID()
        )

        let stderrPath = try await logStore.saveOutputToFile(
            result.stderr,
            prefix: "stderr",
            recordId: UUID()
        )

        // Calculate total output size
        let outputSize = result.stdout.utf8.count + result.stderr.utf8.count

        // Create parsed summary
        let parsedSummary = createParsedSummary(result.parsedOutput)

        // Encode parsed data
        let parsedData = result.parsedOutput.flatMap { try? JSONEncoder().encode($0) }

        // Get previous record hash for audit chain
        let previousHash = try await logStore.getLastRecordHash()

        // Build run record
        var builder = RunRecordBuilder()
        builder.setCapability(capability)
        builder.setArguments(arguments)
        builder.setExecution(
            startTime: result.startTime,
            endTime: result.endTime,
            exitCode: result.exitCode,
            status: result.status
        )
        builder.setOutput(
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            outputSizeBytes: outputSize
        )
        builder.setParsedData(
            summary: parsedSummary,
            data: parsedData
        )
        builder.setPreviousHash(previousHash)

        let record = builder.build()

        // Save to database
        try await logStore.save(record)

        logger.info("Run record saved: \(record.id.uuidString)")
    }

    private func createParsedSummary(_ parsed: ParsedOutput?) -> String? {
        guard let parsed = parsed else { return nil }

        switch parsed {
        case .text(let value):
            return value.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines)

        case .json(let dict):
            return "JSON: \(dict.keys.joined(separator: ", "))"

        case .regex(let captures):
            return "Captures: \(captures.count)"

        case .table(let headers, let rows):
            return "Table: \(headers.count) columns, \(rows.count) rows"

        case .memoryPressure(let info):
            return "Memory: \(info.level), \(ByteCountFormatter.string(fromByteCount: info.availableBytes, countStyle: .memory)) available"

        case .diskUsage(let entries):
            let totalSize = entries.reduce(0) { sum, entry in
                // Try to parse size string
                return sum
            }
            return "Disk: \(entries.count) entries"

        case .processTable(let processes):
            return "Processes: \(processes.count)"
        }
    }

    // MARK: - Cancellation

    func cancel() async {
        logger.warning("Cancelling current execution")
        await processRunner.cancel()
    }
}
