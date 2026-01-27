//
//  ProcessRunner.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import os.log

// MARK: - Process Runner Errors

enum ProcessRunnerError: LocalizedError {
    case processCreationFailed
    case timeout
    case cancelled
    case invalidCommand
    case outputStreamFailed

    var errorDescription: String? {
        switch self {
        case .processCreationFailed:
            return "Failed to create or launch process"
        case .timeout:
            return "Process execution timed out"
        case .cancelled:
            return "Process execution was cancelled"
        case .invalidCommand:
            return "Invalid command or arguments provided"
        case .outputStreamFailed:
            return "Failed to capture process output"
        }
    }
}

// MARK: - Execution Result

struct ExecutionResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let didTimeout: Bool
    let duration: TimeInterval
}

// MARK: - Process Runner

/// Actor-based process execution with timeout, cancellation, and streaming output
actor ProcessRunner {

    // MARK: - Private State

    private var currentProcess: Process?
    private var isCancelled: Bool = false
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "ProcessRunner")

    // MARK: - Public API

    /// Execute a command with full control over execution parameters
    /// - Parameters:
    ///   - command: Full path to executable
    ///   - arguments: Command line arguments
    ///   - workingDirectory: Optional working directory URL
    ///   - timeout: Maximum execution time in seconds
    ///   - onStdout: Optional callback for stdout line streaming
    ///   - onStderr: Optional callback for stderr line streaming
    /// - Returns: Execution result with exit code and captured output
    /// - Throws: ProcessRunnerError on failure
    func execute(
        command: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval,
        onStdout: (@Sendable (String) -> Void)? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> ExecutionResult {

        // Reset cancellation state
        isCancelled = false

        // Validate command
        guard !command.isEmpty else {
            logger.error("Invalid command: empty string")
            throw ProcessRunnerError.invalidCommand
        }

        logger.info("Executing: \(command) \(arguments.joined(separator: " "))")
        let startTime = Date()

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
            logger.debug("Working directory: \(workingDirectory.path)")
        }

        // Setup pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Store reference for cancellation
        currentProcess = process

        // Create continuations for output streams
        let stdoutTask = Task {
            await streamOutput(
                from: stdoutPipe.fileHandleForReading,
                label: "stdout",
                callback: onStdout
            )
        }

        let stderrTask = Task {
            await streamOutput(
                from: stderrPipe.fileHandleForReading,
                label: "stderr",
                callback: onStderr
            )
        }

        // Launch process
        do {
            try process.run()
        } catch {
            logger.error("Failed to launch process: \(error.localizedDescription)")
            currentProcess = nil
            throw ProcessRunnerError.processCreationFailed
        }

        // Wait for process with timeout
        let didTimeout: Bool
        do {
            didTimeout = try await waitForProcess(process, timeout: timeout)
        } catch {
            // Ensure cleanup on error
            if process.isRunning {
                process.terminate()
            }
            currentProcess = nil
            throw error
        }

        // Wait for output streams to finish
        let stdoutOutput = await stdoutTask.value
        let stderrOutput = await stderrTask.value

        let exitCode = process.terminationStatus
        let duration = Date().timeIntervalSince(startTime)

        currentProcess = nil

        logger.info("Process completed: exit=\(exitCode), duration=\(String(format: "%.2f", duration))s, timeout=\(didTimeout)")

        return ExecutionResult(
            exitCode: exitCode,
            stdout: stdoutOutput,
            stderr: stderrOutput,
            didTimeout: didTimeout,
            duration: duration
        )
    }

    /// Cancel the currently executing process
    func cancel() {
        logger.warning("Cancellation requested")
        isCancelled = true

        if let process = currentProcess, process.isRunning {
            logger.info("Terminating running process (PID: \(process.processIdentifier))")
            process.terminate()
        }
    }

    // MARK: - Private Helpers

    /// Wait for process completion with timeout
    private func waitForProcess(_ process: Process, timeout: TimeInterval) async throws -> Bool {
        return try await withThrowingTaskGroup(of: Bool.self) { group in

            // Task 1: Wait for process to complete normally
            group.addTask {
                while process.isRunning {
                    try await Task.sleep(for: .milliseconds(100))

                    // Check for cancellation
                    if await self.isCancelled {
                        process.terminate()
                        throw ProcessRunnerError.cancelled
                    }
                }
                return false // Did not timeout
            }

            // Task 2: Timeout watchdog
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    self.logger.warning("Process timeout after \(timeout)s, terminating")
                    process.terminate()
                    return true // Did timeout
                }
                return false
            }

            // Return result from first completed task
            guard let result = try await group.next() else {
                return false
            }

            // Cancel the other task
            group.cancelAll()

            return result
        }
    }

    /// Stream output from file handle line by line
    private func streamOutput(
        from fileHandle: FileHandle,
        label: String,
        callback: (@Sendable (String) -> Void)?
    ) async -> String {

        var accumulatedOutput = ""
        var buffer = Data()

        do {
            // Read data in chunks
            for try await data in fileHandle.bytes {
                buffer.append(data)

                // Process complete lines
                while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buffer.prefix(upTo: newlineIndex)
                    buffer.removeSubrange(...newlineIndex)

                    if let line = String(data: Data(lineData), encoding: .utf8) {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedLine.isEmpty {
                            accumulatedOutput += trimmedLine + "\n"
                            callback?(trimmedLine)
                        }
                    }
                }
            }

            // Process any remaining data in buffer
            if !buffer.isEmpty {
                if let remaining = String(data: buffer, encoding: .utf8) {
                    let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        accumulatedOutput += trimmed
                        callback?(trimmed)
                    }
                }
            }

        } catch {
            logger.error("Error reading \(label): \(error.localizedDescription)")
        }

        return accumulatedOutput
    }
}
