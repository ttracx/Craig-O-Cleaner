//
//  ElevatedExecutor.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import os.log

/// Executor for elevated (privileged) commands using the privileged helper tool
@Observable
final class ElevatedExecutor: CapabilityExecutor {

    // MARK: - Dependencies

    private let helperInstaller: HelperInstaller
    private let logStore: SQLiteLogStore
    private let preflightEngine: PreflightEngine
    private let autoPermissionHandler: AutoPermissionHandler
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "ElevatedExecutor")

    // MARK: - Observable State

    private(set) var isExecuting: Bool = false
    private(set) var currentCapability: Capability?
    private(set) var lastExecution: ExecutionResultWithOutput?

    // MARK: - Initialization

    init(
        helperInstaller: HelperInstaller = .shared,
        logStore: SQLiteLogStore = .shared,
        preflightEngine: PreflightEngine = PreflightEngine(),
        autoPermissionHandler: AutoPermissionHandler = .shared
    ) {
        self.helperInstaller = helperInstaller
        self.logStore = logStore
        self.preflightEngine = preflightEngine
        self.autoPermissionHandler = autoPermissionHandler
    }

    // MARK: - Command Executor Protocol

    func canExecute(_ capability: Capability) async -> Bool {
        capability.privilegeLevel == .elevated
    }

    func execute(
        _ capability: Capability,
        arguments: [String: String] = [:]
    ) async throws -> ExecutionResultWithOutput {

        logger.info("Executing elevated capability: \(capability.id)")

        // Validate capability is elevated
        guard await canExecute(capability) else {
            throw HelperError.commandNotAllowed("Capability \(capability.id) does not require elevation")
        }

        // Check if helper is installed
        guard await helperInstaller.isInstalled() else {
            logger.error("Helper not installed")
            throw HelperError.notInstalled
        }

        // Check if helper needs update
        if helperInstaller.status.needsUpdate {
            logger.warning("Helper is outdated")
            throw HelperError.outdated(
                current: "unknown",
                required: HelperConstants.currentVersion
            )
        }

        // Update state
        isExecuting = true
        currentCapability = capability
        defer {
            isExecuting = false
            currentCapability = nil
        }

        // Run preflight validation
        let preflightResult = await preflightEngine.validate(capability)

        // Handle missing permissions with auto-remediation
        if !preflightResult.missingPermissions.isEmpty {
            logger.warning("Missing permissions detected: \(preflightResult.missingPermissions.map { $0.displayName })")

            // Trigger auto-remediation
            await autoPermissionHandler.handleMissingPermissions(
                preflightResult.missingPermissions,
                for: capability
            )

            // After auto-remediation, still fail the execution
            // User needs to re-run after granting permissions
            throw UserExecutorError.preflightValidationFailed(preflightResult)
        }

        guard preflightResult.canExecute else {
            logger.error("Preflight validation failed: \(preflightResult.summary)")
            throw UserExecutorError.preflightValidationFailed(preflightResult)
        }

        logger.debug("Preflight validation passed for \(capability.id)")

        // Interpolate command template
        let (command, commandArgs) = try interpolateCommand(capability, arguments: arguments)

        // Get authorization data
        logger.info("Requesting authorization...")
        let authData = try await helperInstaller.createAuthorizationData()

        // Execute via helper
        let startTime = Date()
        logger.info("Executing via helper: \(command) \(commandArgs.joined(separator: " "))")

        let result: (exitCode: Int32, stdout: String, stderr: String)

        do {
            result = try await helperInstaller.executeCommand(
                command,
                arguments: commandArgs,
                workingDirectory: capability.workingDirectory,
                authData: authData
            )
        } catch let error as HelperError {
            let endTime = Date()
            logger.error("Helper execution failed: \(error.localizedDescription)")

            // Create failed result
            let executionResult = ExecutionResultWithOutput(
                capabilityId: capability.id,
                startTime: startTime,
                endTime: endTime,
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                parsedOutput: nil,
                status: .failed
            )

            // Log the failure
            try await logExecution(capability, arguments: arguments, result: executionResult)

            throw error
        } catch {
            let endTime = Date()
            logger.error("Execution failed: \(error.localizedDescription)")

            // Create failed result
            let executionResult = ExecutionResultWithOutput(
                capabilityId: capability.id,
                startTime: startTime,
                endTime: endTime,
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                parsedOutput: nil,
                status: .failed
            )

            // Log the failure
            try await logExecution(capability, arguments: arguments, result: executionResult)

            throw HelperError.executionFailed(error.localizedDescription)
        }

        let endTime = Date()

        // Determine status
        let status: ExecutionStatus = result.exitCode == 0 ? .success : .failed

        // Parse output
        let parsedOutput = parseOutput(capability, stdout: result.stdout)

        // Create result
        let executionResult = ExecutionResultWithOutput(
            capabilityId: capability.id,
            startTime: startTime,
            endTime: endTime,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            parsedOutput: parsedOutput,
            status: status
        )

        // Log the execution
        try await logExecution(capability, arguments: arguments, result: executionResult)

        // Store for UI
        lastExecution = executionResult

        logger.info("Elevated execution completed: \(capability.id), status=\(status.rawValue), exitCode=\(result.exitCode)")

        return executionResult
    }

    // MARK: - Command Interpolation

    private func interpolateCommand(
        _ capability: Capability,
        arguments: [String: String]
    ) throws -> (command: String, arguments: [String]) {

        logger.debug("Interpolating command template: \(capability.commandTemplate)")

        // Parse command template
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

        logger.debug("Creating run record for elevated execution: \(capability.id)")

        // Save large outputs to files
        let stdoutPath = try await logStore.saveOutputToFile(
            result.stdout,
            prefix: "stdout-elevated",
            recordId: UUID()
        )

        let stderrPath = try await logStore.saveOutputToFile(
            result.stderr,
            prefix: "stderr-elevated",
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

        // NOTE: Metadata not yet implemented in RunRecord
        // Future: Add metadata indicating elevated execution
        // - executionType: "elevated"
        // - helperVersion: HelperConstants.currentVersion

        let record = builder.build()

        // Save to database
        try await logStore.save(record)

        logger.info("Elevated run record saved: \(record.id.uuidString)")
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
            return "Disk: \(entries.count) entries"

        case .processTable(let processes):
            return "Processes: \(processes.count)"
        }
    }
}
