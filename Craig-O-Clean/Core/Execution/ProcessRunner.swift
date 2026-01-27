// MARK: - ProcessRunner.swift
// Craig-O-Clean - Foundation.Process Wrapper
// Safe, timeout-managed process execution with streaming output

import Foundation
import os.log

// MARK: - Process Runner Errors

enum ProcessRunnerError: LocalizedError {
    case timeout(TimeInterval)
    case cancelled
    case launchFailed(String)
    case invalidCommand(String)

    var errorDescription: String? {
        switch self {
        case .timeout(let duration):
            return "Command timed out after \(Int(duration)) seconds"
        case .cancelled:
            return "Command was cancelled"
        case .launchFailed(let reason):
            return "Failed to launch command: \(reason)"
        case .invalidCommand(let cmd):
            return "Invalid command: \(cmd)"
        }
    }
}

// MARK: - Process Runner

/// Wraps Foundation.Process for safe, streaming command execution
final class ProcessRunner: @unchecked Sendable {
    private var process: Process?
    private var isCancelled = false
    private let logger = Logger(subsystem: "com.CraigOClean", category: "ProcessRunner")

    /// Run a shell command with timeout and streaming output
    func run(
        command: String,
        workingDirectory: String? = nil,
        timeout: TimeInterval = 120,
        onStdout: @escaping (String) -> Void = { _ in },
        onStderr: @escaping (String) -> Void = { _ in }
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        isCancelled = false

        let process = Process()
        self.process = process

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        // Set clean environment
        var env = Foundation.ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Use actor-isolated storage for concurrent data mutations
        actor DataBuffer {
            var stdout = Data()
            var stderr = Data()

            func appendStdout(_ data: Data) {
                stdout.append(data)
            }

            func appendStderr(_ data: Data) {
                stderr.append(data)
            }

            func getBuffers() -> (stdout: Data, stderr: Data) {
                return (stdout, stderr)
            }
        }

        let buffer = DataBuffer()

        // Stream stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                Task {
                    await buffer.appendStdout(data)
                }
                if let str = String(data: data, encoding: .utf8) {
                    onStdout(str)
                }
            }
        }

        // Stream stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                Task {
                    await buffer.appendStderr(data)
                }
                if let str = String(data: data, encoding: .utf8) {
                    onStderr(str)
                }
            }
        }

        // Launch
        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        // Timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        // Wait for completion
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { [weak self] proc in
                timeoutTask.cancel()

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Read remaining data
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                // Retrieve buffered data and combine with remaining data
                Task {
                    await buffer.appendStdout(remainingStdout)
                    await buffer.appendStderr(remainingStderr)

                    let buffers = await buffer.getBuffers()
                    let stdout = String(data: buffers.stdout, encoding: .utf8) ?? ""
                    let stderr = String(data: buffers.stderr, encoding: .utf8) ?? ""

                    self?.logger.debug("Process exited with code \(proc.terminationStatus)")

                    continuation.resume(returning: (proc.terminationStatus, stdout, stderr))
                }
            }
        }
    }

    /// Cancel the running process
    func cancel() {
        isCancelled = true
        if let p = process, p.isRunning {
            p.terminate()
        }
    }
}
