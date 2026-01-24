import Foundation

// MARK: - Command Executor
/// Core component for executing shell commands safely and efficiently

@MainActor
public final class CommandExecutor: ObservableObject {

    // MARK: - Singleton

    public static let shared = CommandExecutor()

    // MARK: - Types

    public struct CommandResult: Sendable {
        public let output: String
        public let errorOutput: String
        public let exitCode: Int32
        public let duration: TimeInterval

        public var isSuccess: Bool { exitCode == 0 }
    }

    public enum ExecutionMode {
        case standard
        case privileged
        case background
    }

    public enum CommandError: Error, LocalizedError {
        case executionFailed(exitCode: Int32, error: String)
        case timeout
        case invalidCommand

        public var errorDescription: String? {
            switch self {
            case .executionFailed(let code, let error):
                return "Command failed with exit code \(code): \(error)"
            case .timeout:
                return "Command execution timed out"
            case .invalidCommand:
                return "Invalid command"
            }
        }
    }

    // MARK: - Properties

    @Published public private(set) var isExecuting = false
    @Published public private(set) var lastCommand: String?
    @Published public private(set) var lastResult: CommandResult?

    private let defaultTimeout: TimeInterval = 30

    // MARK: - Initialization

    private init() {}

    // MARK: - Execution

    /// Execute a shell command
    public func execute(
        _ command: String,
        mode: ExecutionMode = .standard,
        timeout: TimeInterval? = nil,
        workingDirectory: String? = nil
    ) async throws -> CommandResult {

        isExecuting = true
        lastCommand = command

        defer { isExecuting = false }

        let startTime = Date()

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

        // Set environment
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw CommandError.executionFailed(exitCode: -1, error: error.localizedDescription)
        }

        // Handle timeout
        let effectiveTimeout = timeout ?? defaultTimeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        let result = CommandResult(
            output: output,
            errorOutput: errorOutput,
            exitCode: process.terminationStatus,
            duration: Date().timeIntervalSince(startTime)
        )

        lastResult = result

        if process.terminationStatus != 0 && !errorOutput.isEmpty {
            // Don't throw for common non-critical errors
            if !errorOutput.contains("No such file") && !errorOutput.contains("Permission denied") {
                // Log but don't throw
            }
        }

        return result
    }

    /// Execute a privileged command using osascript for authorization
    public func executePrivileged(
        _ command: String,
        timeout: TimeInterval? = nil
    ) async throws -> CommandResult {

        let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "\(escapedCommand)" with administrator privileges
        """

        return try await executeAppleScript(script)
    }

    /// Execute an AppleScript
    public func executeAppleScript(_ script: String) async throws -> CommandResult {
        let startTime = Date()

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw CommandError.executionFailed(exitCode: -1, error: error.localizedDescription)
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            output: String(data: outputData, encoding: .utf8) ?? "",
            errorOutput: String(data: errorData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Convenience Methods

    /// Execute multiple commands in sequence
    public func executeSequence(_ commands: [String]) async throws -> [CommandResult] {
        var results: [CommandResult] = []
        for command in commands {
            let result = try await execute(command)
            results.append(result)
        }
        return results
    }

    /// Execute multiple commands in parallel
    public func executeParallel(_ commands: [String]) async throws -> [CommandResult] {
        try await withThrowingTaskGroup(of: CommandResult.self) { group in
            for command in commands {
                group.addTask {
                    try await self.execute(command)
                }
            }

            var results: [CommandResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}
