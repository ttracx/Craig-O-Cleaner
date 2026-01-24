import Foundation

// MARK: - Command Executor
/// Core execution engine for running terminal commands with full read/write permissions
/// Designed for autonomous macOS Silicon device management

@MainActor
public final class CommandExecutor: ObservableObject {

    // MARK: - Types

    public struct CommandResult: Sendable {
        public let command: String
        public let output: String
        public let error: String
        public let exitCode: Int32
        public let executionTime: TimeInterval
        public let timestamp: Date

        public var isSuccess: Bool { exitCode == 0 }

        public var description: String {
            """
            Command: \(command)
            Exit Code: \(exitCode)
            Execution Time: \(String(format: "%.2f", executionTime))s
            Output: \(output.isEmpty ? "(none)" : output)
            Error: \(error.isEmpty ? "(none)" : error)
            """
        }
    }

    public enum ExecutionMode {
        case standard          // Normal execution
        case privileged        // Requires sudo
        case background        // Run in background
        case silent           // Suppress output
    }

    public enum CommandError: Error, LocalizedError {
        case executionFailed(String)
        case timeout
        case permissionDenied
        case commandNotFound(String)
        case invalidCommand

        public var errorDescription: String? {
            switch self {
            case .executionFailed(let msg): return "Execution failed: \(msg)"
            case .timeout: return "Command timed out"
            case .permissionDenied: return "Permission denied - sudo may be required"
            case .commandNotFound(let cmd): return "Command not found: \(cmd)"
            case .invalidCommand: return "Invalid command"
            }
        }
    }

    // MARK: - Properties

    @Published public private(set) var isExecuting = false
    @Published public private(set) var lastResult: CommandResult?
    @Published public private(set) var executionHistory: [CommandResult] = []

    private let historyLimit = 100
    private let defaultTimeout: TimeInterval = 30

    public static let shared = CommandExecutor()

    // MARK: - Initialization

    private init() {}

    // MARK: - Core Execution

    /// Execute a shell command and return the result
    public func execute(
        _ command: String,
        mode: ExecutionMode = .standard,
        timeout: TimeInterval? = nil,
        workingDirectory: String? = nil
    ) async throws -> CommandResult {

        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommandError.invalidCommand
        }

        isExecuting = true
        defer { isExecuting = false }

        let startTime = Date()
        let effectiveTimeout = timeout ?? defaultTimeout

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let dir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        return try await withCheckedThrowingContinuation { continuation in
            // Timeout task
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
                process.waitUntilExit()
                timeoutTask.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let executionTime = Date().timeIntervalSince(startTime)

                let result = CommandResult(
                    command: command,
                    output: output,
                    error: error,
                    exitCode: process.terminationStatus,
                    executionTime: executionTime,
                    timestamp: Date()
                )

                Task { @MainActor in
                    self.lastResult = result
                    self.addToHistory(result)
                }

                continuation.resume(returning: result)

            } catch {
                timeoutTask.cancel()
                continuation.resume(throwing: CommandError.executionFailed(error.localizedDescription))
            }
        }
    }

    /// Execute multiple commands sequentially
    public func executeSequence(_ commands: [String], stopOnError: Bool = true) async throws -> [CommandResult] {
        var results: [CommandResult] = []

        for command in commands {
            let result = try await execute(command)
            results.append(result)

            if stopOnError && !result.isSuccess {
                break
            }
        }

        return results
    }

    /// Execute multiple commands in parallel
    public func executeParallel(_ commands: [String]) async -> [CommandResult] {
        await withTaskGroup(of: CommandResult?.self) { group in
            for command in commands {
                group.addTask {
                    try? await self.execute(command)
                }
            }

            var results: [CommandResult] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
    }

    /// Execute command with sudo (requires password or Touch ID)
    public func executePrivileged(_ command: String, timeout: TimeInterval? = nil) async throws -> CommandResult {
        // Note: In production, this would use the PrivilegedHelper via XPC
        // For direct execution, we use osascript to prompt for password
        let sudoCommand = "sudo \(command)"
        return try await execute(sudoCommand, mode: .privileged, timeout: timeout)
    }

    /// Execute AppleScript
    public func executeAppleScript(_ script: String) async throws -> CommandResult {
        let escapedScript = script.replacingOccurrences(of: "\"", with: "\\\"")
        let command = "osascript -e \"\(escapedScript)\""
        return try await execute(command)
    }

    /// Execute AppleScript from multi-line script
    public func executeAppleScriptBlock(_ script: String) async throws -> CommandResult {
        // Write script to temp file and execute
        let tempFile = "/tmp/terminator_script_\(UUID().uuidString).scpt"
        let writeCommand = "cat > \(tempFile) << 'APPLESCRIPT_EOF'\n\(script)\nAPPLESCRIPT_EOF"
        _ = try await execute(writeCommand)

        defer {
            Task {
                _ = try? await self.execute("rm -f \(tempFile)")
            }
        }

        return try await execute("osascript \(tempFile)")
    }

    // MARK: - History Management

    private func addToHistory(_ result: CommandResult) {
        executionHistory.insert(result, at: 0)
        if executionHistory.count > historyLimit {
            executionHistory.removeLast()
        }
    }

    public func clearHistory() {
        executionHistory.removeAll()
    }

    // MARK: - Utility Methods

    /// Check if a command exists
    public func commandExists(_ command: String) async -> Bool {
        let result = try? await execute("which \(command)")
        return result?.isSuccess ?? false
    }

    /// Get command path
    public func commandPath(_ command: String) async -> String? {
        let result = try? await execute("which \(command)")
        return result?.isSuccess == true ? result?.output : nil
    }
}

// MARK: - Command Builder

public struct CommandBuilder {
    private var components: [String] = []

    public init() {}

    public mutating func add(_ component: String) -> CommandBuilder {
        components.append(component)
        return self
    }

    public mutating func pipe(_ command: String) -> CommandBuilder {
        components.append("|")
        components.append(command)
        return self
    }

    public mutating func and(_ command: String) -> CommandBuilder {
        components.append("&&")
        components.append(command)
        return self
    }

    public mutating func or(_ command: String) -> CommandBuilder {
        components.append("||")
        components.append(command)
        return self
    }

    public mutating func redirect(to path: String, append: Bool = false) -> CommandBuilder {
        components.append(append ? ">>" : ">")
        components.append(path)
        return self
    }

    public func build() -> String {
        components.joined(separator: " ")
    }
}

// MARK: - Command Templates

public enum CommandTemplate {

    // Process commands
    public static func killProcess(pid: Int, force: Bool = false) -> String {
        force ? "kill -9 \(pid)" : "kill \(pid)"
    }

    public static func killAllByName(_ name: String, force: Bool = false) -> String {
        let signal = force ? "-9 " : ""
        return "killall \(signal)\"\(name)\""
    }

    public static func findProcess(name: String) -> String {
        "pgrep -l \"\(name)\""
    }

    // Memory commands
    public static let purgeMemory = "sudo purge"
    public static let syncAndPurge = "sync && sudo purge"
    public static let flushDNS = "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"

    // System info
    public static let memoryStatus = "top -l 1 -s 0 | grep PhysMem"
    public static let diskUsage = "df -h /"
    public static let cpuUsage = "top -l 1 -s 0 | grep 'CPU usage'"

    // Cleanup
    public static func clearDirectory(_ path: String) -> String {
        "rm -rf \(path)/*"
    }

    public static func emptyTrash() -> String {
        "rm -rf ~/.Trash/*"
    }
}
