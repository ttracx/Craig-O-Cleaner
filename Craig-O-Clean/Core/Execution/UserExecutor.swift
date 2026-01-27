// MARK: - UserExecutor.swift
// Craig-O-Clean - Non-Privileged Command Executor
// Executes user-level and automation commands via ProcessRunner

import Foundation
import os.log

/// Executes capabilities that require no privilege elevation
final class UserExecutor: CommandExecutor {
    private let runner = ProcessRunner()
    private let logger = Logger(subsystem: "com.CraigOClean", category: "UserExecutor")

    func execute(
        _ capability: Capability,
        arguments: [String: String],
        progress: @escaping (ExecutionProgress) -> Void
    ) async throws -> ExecutionResult {
        let startTime = Date()

        progress(ExecutionProgress(phase: .preparing, stdout: nil, stderr: nil, percentage: 0))

        // Resolve command template with arguments
        var command = capability.commandTemplate
        for (key, value) in arguments {
            command = command.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        progress(ExecutionProgress(phase: .executing, stdout: nil, stderr: nil, percentage: 0.1))

        let (exitCode, stdout, stderr) = try await runner.run(
            command: command,
            workingDirectory: capability.workingDirectory,
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

        // Parse output
        progress(ExecutionProgress(phase: .parsing, stdout: nil, stderr: nil, percentage: 0.9))
        let parsedOutput = parseOutput(stdout, parser: capability.outputParser, pattern: capability.parserPattern)

        let status: ExecutionStatus
        if exitCode == 0 {
            status = .success
        } else if !stderr.isEmpty && exitCode == 0 {
            status = .partialSuccess
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
            parsedSummary: summarize(parsedOutput)
        )

        progress(ExecutionProgress(phase: .complete, stdout: nil, stderr: nil, percentage: 1.0))

        return ExecutionResult(
            capabilityId: capability.id,
            startTime: startTime,
            endTime: endTime,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            parsedOutput: parsedOutput,
            record: record
        )
    }

    func canExecute(_ capability: Capability) async -> PreflightResult {
        PreflightResult(canExecute: true, missingPermissions: [], failedChecks: [], remediationSteps: [])
    }

    func cancel() async {
        runner.cancel()
    }

    // MARK: - Output Parsing

    private func parseOutput(_ output: String, parser: OutputParser, pattern: String?) -> ParsedOutput? {
        guard !output.isEmpty else { return nil }

        switch parser {
        case .text:
            return .text(output)
        case .regex:
            guard let pattern = pattern else { return .text(output) }
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
                var groups: [String] = []
                for i in 0..<match.numberOfRanges {
                    if let range = Range(match.range(at: i), in: output) {
                        groups.append(String(output[range]))
                    }
                }
                return .lines(groups)
            }
            return .text(output)
        case .processTable:
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            return .lines(lines)
        case .diskUsage:
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            return .lines(lines)
        case .memoryPressure:
            return .text(output)
        case .json:
            return .text(output)
        case .table:
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            return .lines(lines)
        }
    }

    private func summarize(_ output: ParsedOutput?) -> String? {
        guard let output = output else { return nil }
        switch output {
        case .text(let s): return String(s.prefix(200))
        case .lines(let lines): return "\(lines.count) lines"
        case .keyValue(let kv): return "\(kv.count) entries"
        case .table(_, let rows): return "\(rows.count) rows"
        case .json: return "JSON output"
        case .memoryInfo(let used, let free, let pressure):
            return "Used: \(used), Free: \(free), Pressure: \(pressure)"
        case .diskInfo(let total, let used, let free):
            return "Total: \(total), Used: \(used), Free: \(free)"
        }
    }
}
