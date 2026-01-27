// MARK: - CommandExecutor.swift
// Craig-O-Clean - Command Execution Service
// Allowlist-only execution of capabilities with logging and preflight checks

import Foundation
import os.log

// MARK: - Execution Error

enum ExecutionError: LocalizedError {
    case capabilityNotFound(String)
    case preflightFailed(String)
    case permissionDenied(String)
    case privilegeRequired(String)
    case executionFailed(String)
    case automationDenied(String)

    var errorDescription: String? {
        switch self {
        case .capabilityNotFound(let id): return "Capability '\(id)' not found in catalog"
        case .preflightFailed(let msg): return "Preflight check failed: \(msg)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .privilegeRequired(let msg): return "Elevated privileges required: \(msg)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        case .automationDenied(let msg): return "Automation permission denied: \(msg)"
        }
    }
}

// MARK: - Execution Result

struct ExecutionResult {
    let capabilityId: String
    let success: Bool
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let duration: TimeInterval
    let parsedSummary: String?
    let remediationHint: String?
    let timestamp: Date
}

// MARK: - Command Executor

@MainActor
final class CommandExecutor: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isExecuting = false
    @Published private(set) var currentCapabilityId: String?
    @Published private(set) var lastResult: ExecutionResult?
    @Published var stdoutStream: String = ""
    @Published var stderrStream: String = ""

    // MARK: - Dependencies

    private let catalogStore: CatalogStore
    private let preflightEngine: PreflightEngine
    private let logStore: LogStore
    private let processRunner = ProcessRunner()
    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "CommandExecutor")

    // MARK: - Initialization

    init(catalogStore: CatalogStore, preflightEngine: PreflightEngine, logStore: LogStore) {
        self.catalogStore = catalogStore
        self.preflightEngine = preflightEngine
        self.logStore = logStore
    }

    // MARK: - Execution

    /// Execute a capability by ID. This is the single entry point for all operations.
    /// - Parameters:
    ///   - capabilityId: The capability ID from the catalog
    ///   - args: Optional runtime arguments (e.g., URL pattern for browser tab close)
    ///   - skipConfirmation: If true, skips UI confirmation (only for safe capabilities)
    /// - Returns: ExecutionResult
    func execute(capabilityId: String, args: [String: String] = [:]) async -> ExecutionResult {
        // 1. Allowlist check
        guard let capability = catalogStore.capability(byId: capabilityId) else {
            logger.error("Capability not in allowlist: \(capabilityId)")
            return makeErrorResult(capabilityId: capabilityId, error: "Capability not found in catalog")
        }

        // 2. Preflight checks
        let preflightResult = await preflightEngine.runChecks(for: capability)
        if !preflightResult.passed {
            logger.warning("Preflight failed for \(capabilityId): \(preflightResult.failureMessages.joined(separator: ", "))")
            return makeErrorResult(
                capabilityId: capabilityId,
                error: preflightResult.failureMessages.joined(separator: "\n"),
                remediation: preflightResult.remediationHint
            )
        }

        isExecuting = true
        currentCapabilityId = capabilityId
        stdoutStream = ""
        stderrStream = ""

        defer {
            isExecuting = false
            currentCapabilityId = nil
        }

        let result: ExecutionResult

        switch capability.executorType {
        case .process:
            result = await executeProcess(capability: capability, args: args)
        case .appleEvents:
            result = await executeAppleEvents(capability: capability, args: args)
        case .helperXpc:
            result = await executeHelperXpc(capability: capability, args: args)
        }

        // Log the run
        await logStore.recordRun(from: result, capability: capability)
        lastResult = result
        return result
    }

    // MARK: - Process Execution

    private func executeProcess(capability: Capability, args: [String: String]) async -> ExecutionResult {
        guard let commandTemplate = capability.commandTemplate else {
            return makeErrorResult(capabilityId: capability.id, error: "No command template")
        }

        // Build arguments - handle special cases for cleanup commands
        var finalArgs = capability.args ?? []

        // For rm -rf commands, resolve the target path
        if commandTemplate == "/bin/rm" {
            let targetPath = resolveCleanupPath(for: capability)
            if let path = targetPath {
                finalArgs.append(path)
            } else {
                return makeErrorResult(capabilityId: capability.id, error: "Could not resolve target path for cleanup")
            }
        }

        // For find command, add home dir and size args
        if commandTemplate == "/usr/bin/find" && capability.id == "disk.large_files_home" {
            finalArgs = [NSHomeDirectory(), "-type", "f", "-size", "+1G"]
        }

        // For du command, add home dir
        if commandTemplate == "/usr/bin/du" && capability.id == "disk.home_usage" {
            finalArgs.append(NSHomeDirectory())
        }

        // Substitute args
        for (key, value) in args {
            finalArgs = finalArgs.map { $0.replacingOccurrences(of: "__\(key.uppercased())__", with: value) }
        }

        let startTime = Date()

        do {
            let processResult = try await processRunner.run(
                executablePath: commandTemplate,
                arguments: finalArgs,
                onStdout: { @Sendable [weak self] line in
                    Task { @MainActor in
                        self?.stdoutStream += line
                    }
                },
                onStderr: { @Sendable [weak self] line in
                    Task { @MainActor in
                        self?.stderrStream += line
                    }
                }
            )

            return ExecutionResult(
                capabilityId: capability.id,
                success: processResult.exitCode == 0,
                stdout: processResult.stdout,
                stderr: processResult.stderr,
                exitCode: processResult.exitCode,
                duration: processResult.duration,
                parsedSummary: parseSummary(for: capability, output: processResult.stdout),
                remediationHint: processResult.exitCode != 0 ? "Command exited with code \(processResult.exitCode). Check stderr for details." : nil,
                timestamp: startTime
            )
        } catch {
            return makeErrorResult(
                capabilityId: capability.id,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - AppleEvents Execution

    private func executeAppleEvents(capability: Capability, args: [String: String]) async -> ExecutionResult {
        guard var script = capability.appleScript else {
            return makeErrorResult(capabilityId: capability.id, error: "No AppleScript defined")
        }

        // Substitute args into the script
        for (key, value) in args {
            // Sanitize the value to prevent AppleScript injection
            let sanitized = value
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\\", with: "\\\\")
            script = script.replacingOccurrences(of: "__\(key.uppercased())__", with: sanitized)
        }

        let startTime = Date()

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)

        let duration = Date().timeIntervalSince(startTime)

        if let error = errorDict {
            let errorNum = error[NSAppleScript.errorNumber] as? Int ?? -1
            let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"

            // Detect automation permission denial
            if errorNum == -1743 || errorNum == -10004 {
                let browserName = capability.requiredPermissions.compactMap { $0.automationBrowserName }.first ?? "the target app"
                return ExecutionResult(
                    capabilityId: capability.id,
                    success: false,
                    stdout: "",
                    stderr: errorMsg,
                    exitCode: Int32(errorNum),
                    duration: duration,
                    parsedSummary: nil,
                    remediationHint: "Automation permission denied for \(browserName). Go to System Settings > Privacy & Security > Automation and enable Craig-O-Clean for \(browserName).",
                    timestamp: startTime
                )
            }

            return ExecutionResult(
                capabilityId: capability.id,
                success: false,
                stdout: "",
                stderr: errorMsg,
                exitCode: Int32(errorNum),
                duration: duration,
                parsedSummary: nil,
                remediationHint: nil,
                timestamp: startTime
            )
        }

        let output = result?.stringValue ?? ""

        return ExecutionResult(
            capabilityId: capability.id,
            success: true,
            stdout: output,
            stderr: "",
            exitCode: 0,
            duration: duration,
            parsedSummary: parseSummary(for: capability, output: output),
            remediationHint: nil,
            timestamp: startTime
        )
    }

    // MARK: - Helper XPC Execution

    private func executeHelperXpc(capability: Capability, args: [String: String]) async -> ExecutionResult {
        // Delegate to PrivilegeService for elevated operations
        // This is a placeholder — the actual implementation uses the existing PrivilegeService
        let startTime = Date()

        return ExecutionResult(
            capabilityId: capability.id,
            success: false,
            stdout: "",
            stderr: "Helper XPC execution requires PrivilegeService integration",
            exitCode: -1,
            duration: Date().timeIntervalSince(startTime),
            parsedSummary: nil,
            remediationHint: "Install the privileged helper via the Permissions Center to enable elevated operations.",
            timestamp: startTime
        )
    }

    // MARK: - Dry Run

    /// Execute a dry run for a capability (preview what would happen)
    func dryRun(capabilityId: String) async -> ExecutionResult {
        guard let capability = catalogStore.capability(byId: capabilityId) else {
            return makeErrorResult(capabilityId: capabilityId, error: "Capability not found")
        }

        guard capability.dryRunSupport, let dryRunCommand = capability.dryRunVariant else {
            return makeErrorResult(capabilityId: capabilityId, error: "Dry run not supported for this capability")
        }

        // Parse dry run command (simple split)
        let parts = dryRunCommand.components(separatedBy: " ")
        guard let executable = parts.first else {
            return makeErrorResult(capabilityId: capabilityId, error: "Invalid dry run command")
        }

        let dryArgs = Array(parts.dropFirst()).map { arg -> String in
            // Expand ~ to home directory
            if arg.hasPrefix("~") {
                return arg.replacingOccurrences(of: "~", with: NSHomeDirectory())
            }
            return arg
        }

        let startTime = Date()

        do {
            let result = try await processRunner.run(
                executablePath: executable,
                arguments: dryArgs
            )

            return ExecutionResult(
                capabilityId: capabilityId,
                success: result.exitCode == 0,
                stdout: result.stdout,
                stderr: result.stderr,
                exitCode: result.exitCode,
                duration: result.duration,
                parsedSummary: "Preview: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))",
                remediationHint: nil,
                timestamp: startTime
            )
        } catch {
            return makeErrorResult(capabilityId: capabilityId, error: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func resolveCleanupPath(for capability: Capability) -> String? {
        // Map capability IDs to their target paths
        let pathMap: [String: String] = [
            "clean.user_caches": "~/Library/Caches/*",
            "clean.user_logs": "~/Library/Logs/*",
            "clean.crash_reports": "~/Library/Application Support/CrashReporter/*",
            "clean.saved_app_state": "~/Library/Saved Application State/*",
            "clean.trash": "~/.Trash/*",
            "dev.xcode_derived_data": "~/Library/Developer/Xcode/DerivedData/*",
            "dev.xcode_archives": "~/Library/Developer/Xcode/Archives/*",
            "dev.simulator_caches": "~/Library/Developer/CoreSimulator/Caches/*",
            "dev.ios_device_support": "~/Library/Developer/Xcode/iOS DeviceSupport/*",
            "dev.cocoapods_cache": "~/Library/Caches/CocoaPods/*",
            "dev.swiftpm_cache": "~/Library/Caches/org.swift.swiftpm/*",
            "browser.safari.clear_cache": "~/Library/Caches/com.apple.Safari/*",
            "browser.chrome.clear_cache": "~/Library/Caches/Google/Chrome/*",
            "browser.edge.clear_cache": "~/Library/Caches/Microsoft Edge/*",
            "browser.brave.clear_cache": "~/Library/Caches/BraveSoftware/*",
            "browser.firefox.clear_cache": "~/Library/Caches/Firefox/*",
            "browser.arc.clear_cache": "~/Library/Caches/company.thebrowser.Browser/*",
        ]

        guard let pattern = pathMap[capability.id] else { return nil }
        return pattern.replacingOccurrences(of: "~", with: NSHomeDirectory())
    }

    private func parseSummary(for capability: Capability, output: String) -> String? {
        guard capability.outputParsing != .none else { return nil }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Completed successfully" }

        // For diagnostics, return first few lines
        let lines = trimmed.components(separatedBy: .newlines)
        if lines.count <= 5 {
            return trimmed
        }
        return lines.prefix(5).joined(separator: "\n") + "\n... (\(lines.count) lines total)"
    }

    private func makeErrorResult(capabilityId: String, error: String, remediation: String? = nil) -> ExecutionResult {
        return ExecutionResult(
            capabilityId: capabilityId,
            success: false,
            stdout: "",
            stderr: error,
            exitCode: -1,
            duration: 0,
            parsedSummary: nil,
            remediationHint: remediation,
            timestamp: Date()
        )
    }
}
