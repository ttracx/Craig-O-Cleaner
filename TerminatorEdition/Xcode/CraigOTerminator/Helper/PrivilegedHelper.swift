import Foundation
import Security

// MARK: - Privileged Helper Protocol
/// Protocol for privileged operations that require elevated permissions

@objc protocol PrivilegedHelperProtocol {
    func purgeMemory(reply: @escaping (Bool, String?) -> Void)
    func flushDNS(reply: @escaping (Bool, String?) -> Void)
    func clearSystemCaches(reply: @escaping (Bool, String?) -> Void)
    func clearTempFiles(reply: @escaping (Bool, String?) -> Void)
    func executePrivilegedCommand(_ command: String, reply: @escaping (Bool, String?, String?) -> Void)
}

// MARK: - Privileged Helper Manager
/// Manager for installing and communicating with the privileged helper

@MainActor
final class PrivilegedHelperManager: ObservableObject {

    static let shared = PrivilegedHelperManager()

    @Published var isHelperInstalled = false
    @Published var lastError: String?

    private let helperIdentifier = "com.craigtracey.CraigOTerminator.Helper"

    private init() {
        checkHelperInstallation()
    }

    // MARK: - Installation

    func checkHelperInstallation() {
        // Check if helper is installed via launchd
        let helperPath = "/Library/PrivilegedHelperTools/\(helperIdentifier)"
        isHelperInstalled = FileManager.default.fileExists(atPath: helperPath)
    }

    func installHelper() async throws {
        // This would use SMJobBless to install the helper
        // For now, we'll use osascript for privileged operations
        isHelperInstalled = true
    }

    // MARK: - Privileged Operations

    /// Purge inactive memory
    func purgeMemory() async throws {
        let script = "do shell script \"sync && purge\" with administrator privileges"
        try await executeAppleScript(script)
    }

    /// Flush DNS cache
    func flushDNS() async throws {
        let script = "do shell script \"dscacheutil -flushcache && killall -HUP mDNSResponder\" with administrator privileges"
        try await executeAppleScript(script)
    }

    /// Clear system caches
    func clearSystemCaches() async throws {
        let script = """
        do shell script "rm -rf /Library/Caches/* 2>/dev/null; rm -rf /System/Library/Caches/* 2>/dev/null" with administrator privileges
        """
        try await executeAppleScript(script)
    }

    /// Clear system temp files
    func clearTempFiles() async throws {
        let script = """
        do shell script "rm -rf /private/var/tmp/* 2>/dev/null; rm -rf /private/var/folders/*/*/*/C/* 2>/dev/null" with administrator privileges
        """
        try await executeAppleScript(script)
    }

    /// Execute a privileged command
    func executePrivilegedCommand(_ command: String) async throws -> String {
        let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        return try await executeAppleScript(script)
    }

    // MARK: - Private

    @discardableResult
    private func executeAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus == 0 {
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: HelperError.executionFailed(error))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    enum HelperError: Error, LocalizedError {
        case notInstalled
        case executionFailed(String)
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Privileged helper is not installed"
            case .executionFailed(let message):
                return "Execution failed: \(message)"
            case .authorizationDenied:
                return "Authorization denied by user"
            }
        }
    }
}

// MARK: - Authorization

extension PrivilegedHelperManager {

    /// Request authorization for privileged operations
    func requestAuthorization() async throws -> Bool {
        // Test if we can get authorization by running a simple command
        do {
            try await executeAppleScript("do shell script \"echo authorized\" with administrator privileges")
            return true
        } catch {
            throw HelperError.authorizationDenied
        }
    }
}
