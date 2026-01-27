// MARK: - ProcessRunner.swift
// Craig-O-Clean - Process Runner
// Executes non-privileged commands via Foundation.Process with streaming output

import Foundation
import os.log

// MARK: - Process Result

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval
    let command: String
}

// MARK: - Process Runner

actor ProcessRunner {

    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "ProcessRunner")

    /// Run a command with arguments, capturing stdout and stderr.
    /// - Parameters:
    ///   - executablePath: Absolute path to the executable
    ///   - arguments: Command arguments
    ///   - environment: Optional environment variables
    ///   - timeout: Timeout in seconds (default 120)
    ///   - onStdout: Optional callback for streaming stdout lines
    ///   - onStderr: Optional callback for streaming stderr lines
    /// - Returns: ProcessResult with captured output and exit status
    func run(
        executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 120,
        onStdout: (@Sendable (String) -> Void)? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let startTime = Date()
        let commandDescription = "\(executablePath) \(arguments.joined(separator: " "))"

        logger.info("Running: \(commandDescription)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let env = environment {
            process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()

        // Read stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                stdoutData.append(data)
                if let line = String(data: data, encoding: .utf8) {
                    onStdout?(line)
                }
            }
        }

        // Read stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                stderrData.append(data)
                if let line = String(data: data, encoding: .utf8) {
                    onStderr?(line)
                }
            }
        }

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch process: \(error.localizedDescription)")
            throw error
        }

        // Timeout handling
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                logger.warning("Process timed out after \(timeout)s, terminating: \(commandDescription)")
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        // Clean up handlers
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        // Read any remaining data
        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutData.append(remainingStdout)
        stderrData.append(remainingStderr)

        let duration = Date().timeIntervalSince(startTime)
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let result = ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration,
            command: commandDescription
        )

        if process.terminationStatus == 0 {
            logger.info("Process completed successfully in \(String(format: "%.2f", duration))s")
        } else {
            logger.warning("Process exited with code \(process.terminationStatus): \(stderr.prefix(200))")
        }

        return result
    }
}
