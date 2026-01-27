// MARK: - ElevatedExecutor.swift
// Craig-O-Clean - Elevated Command Executor
// Executes commands requiring admin privileges via AppleScript with admin prompt

import Foundation
import os.log

/// Executes capabilities requiring elevated privileges
/// Uses AppleScript `do shell script ... with administrator privileges` as a fallback
/// when the XPC helper is not installed
final class ElevatedExecutor: CommandExecutor {
    private let runner = ProcessRunner()
    private var currentTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.CraigOClean", category: "ElevatedExecutor")

    func execute(
        _ capability: Capability,
        arguments: [String: String],
        progress: @escaping (ExecutionProgress) -> Void
    ) async throws -> ExecutionResult {
        let startTime = Date()

        progress(ExecutionProgress(phase: .requestingPermission, stdout: nil, stderr: nil, percentage: 0))

        // Resolve command template
        var command = capability.commandTemplate
        for (key, value) in arguments {
            command = command.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        // Escape for AppleScript
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let fullCommand = "osascript -e '\(appleScript)'"

        progress(ExecutionProgress(phase: .executing, stdout: nil, stderr: nil, percentage: 0.2))

        let (exitCode, stdout, stderr) = try await runner.run(
            command: fullCommand,
            timeout: capability.timeout,
            onStdout: { text in
                progress(ExecutionProgress(phase: .executing, stdout: text, stderr: nil, percentage: nil))
            },
            onStderr: { text in
                progress(ExecutionProgress(phase: .executing, stdout: nil, stderr: text, percentage: nil))
            }
        )

        let endTime = Date()
        let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

        let status: ExecutionStatus
        if exitCode == 0 {
            status = .success
        } else if stderr.contains("User canceled") || stderr.contains("-128") {
            status = .cancelled
        } else if stderr.contains("not allowed") || stderr.contains("-1743") {
            status = .permissionDenied
        } else {
            status = .failed
        }

        let record = RunRecord(
            id: UUID(),
            timestamp: startTime,
            capabilityId: capability.id,
            capabilityTitle: capability.title,
            privilegeLevel: capability.privilegeLevel,
            arguments: arguments,
            durationMs: durationMs,
            exitCode: exitCode,
            status: status,
            stdoutPreview: String(stdout.prefix(500)),
            stderrPreview: String(stderr.prefix(500)),
            outputSizeBytes: stdout.utf8.count + stderr.utf8.count,
            parsedSummary: exitCode == 0 ? "Completed successfully" : "Failed with exit code \(exitCode)"
        )

        progress(ExecutionProgress(phase: .complete, stdout: nil, stderr: nil, percentage: 1.0))

        return ExecutionResult(
            capabilityId: capability.id,
            startTime: startTime,
            endTime: endTime,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            parsedOutput: stdout.isEmpty ? nil : .text(stdout),
            record: record
        )
    }

    func canExecute(_ capability: Capability) async -> PreflightResult {
        PreflightResult(canExecute: true, missingPermissions: [], failedChecks: [], remediationSteps: [])
    }

    func cancel() async {
        runner.cancel()
    }
}
