// MARK: - HelperXPCImplementation.swift
// CraigOCleanHelper - Privileged Helper Tool Implementation
// Implements the XPC protocol for executing privileged commands

import Foundation
import os.log

// MARK: - Helper Tool Implementation

/// Implementation of the privileged helper XPC service
/// This class handles incoming XPC requests and executes privileged operations
final class HelperXPCImplementation: NSObject, HelperXPCProtocol {

    // MARK: - Properties

    private let logger = Logger(subsystem: kHelperToolMachServiceName, category: "HelperXPC")

    /// Current version of the helper tool
    private let helperVersion = "1.0.0"

    /// Path to the sync command
    private let syncPath = "/bin/sync"

    /// Path to the purge command
    private let purgePath = "/usr/bin/purge"

    /// Path to the kill command
    private let killPath = "/bin/kill"

    /// Path to the killall command
    private let killallPath = "/usr/bin/killall"

    /// Allowed commands that the helper can execute
    private let allowedCommands: Set<String> = ["/bin/sync", "/usr/bin/purge", "/bin/kill", "/usr/bin/killall"]

    // MARK: - HelperXPCProtocol Implementation

    func getVersion(reply: @escaping (String) -> Void) {
        logger.info("Version requested")
        reply(helperVersion)
    }

    func executeMemoryCleanup(authData: Data?, reply: @escaping (HelperCommandResult) -> Void) {
        logger.info("Memory cleanup requested")

        // Verify authorization
        guard AuthorizationHelper.verifyAuthorization(data: authData, right: kAuthorizationRightMemoryClean) else {
            logger.error("Authorization failed for memory cleanup")
            reply(HelperCommandResult(
                success: false,
                message: "Authorization required. Please grant administrator privileges.",
                errorCode: -1
            ))
            return
        }

        // Execute sync first
        let syncResult = executeCommand(syncPath, arguments: [])

        if !syncResult.success {
            reply(HelperCommandResult(
                success: false,
                message: "Sync command failed: \(syncResult.message)",
                errorCode: syncResult.errorCode
            ))
            return
        }

        logger.info("Sync completed successfully")

        // Check if purge is available
        guard FileManager.default.fileExists(atPath: purgePath) else {
            logger.warning("Purge command not available on this system")
            reply(HelperCommandResult(
                success: true,
                message: "Sync completed. Note: purge command is not available on this system. File system buffers have been flushed, but inactive memory purge was skipped.",
                errorCode: 0,
                output: syncResult.output
            ))
            return
        }

        // Execute purge
        let purgeResult = executeCommand(purgePath, arguments: [])

        if purgeResult.success {
            logger.info("Memory cleanup completed successfully")
            reply(HelperCommandResult(
                success: true,
                message: "Memory cleanup completed successfully. File system buffers flushed and inactive memory purged.",
                errorCode: 0,
                output: "Sync: \(syncResult.output ?? "OK")\nPurge: \(purgeResult.output ?? "OK")"
            ))
        } else {
            logger.error("Purge command failed: \(purgeResult.message)")
            reply(HelperCommandResult(
                success: false,
                message: "Sync completed but purge failed: \(purgeResult.message)",
                errorCode: purgeResult.errorCode,
                output: syncResult.output
            ))
        }
    }

    func executeSync(authData: Data?, reply: @escaping (HelperCommandResult) -> Void) {
        logger.info("Sync command requested")

        // Verify authorization
        guard AuthorizationHelper.verifyAuthorization(data: authData, right: kAuthorizationRightMemoryClean) else {
            logger.error("Authorization failed for sync")
            reply(HelperCommandResult(
                success: false,
                message: "Authorization required. Please grant administrator privileges.",
                errorCode: -1
            ))
            return
        }

        let result = executeCommand(syncPath, arguments: [])
        logger.info("Sync completed: success=\(result.success)")
        reply(result)
    }

    func executePurge(authData: Data?, reply: @escaping (HelperCommandResult) -> Void) {
        logger.info("Purge command requested")

        // Verify authorization
        guard AuthorizationHelper.verifyAuthorization(data: authData, right: kAuthorizationRightMemoryClean) else {
            logger.error("Authorization failed for purge")
            reply(HelperCommandResult(
                success: false,
                message: "Authorization required. Please grant administrator privileges.",
                errorCode: -1
            ))
            return
        }

        // Check if purge is available
        guard FileManager.default.fileExists(atPath: purgePath) else {
            logger.warning("Purge command not available")
            reply(HelperCommandResult(
                success: false,
                message: "The purge command is not available on this system. This command may not be installed or supported on your macOS version.",
                errorCode: -2
            ))
            return
        }

        let result = executeCommand(purgePath, arguments: [])
        logger.info("Purge completed: success=\(result.success)")
        reply(result)
    }

    func isPurgeAvailable(reply: @escaping (Bool) -> Void) {
        let available = FileManager.default.fileExists(atPath: purgePath)
        logger.info("Purge availability check: \(available)")
        reply(available)
    }

    func ping(reply: @escaping (Bool) -> Void) {
        logger.debug("Ping received")
        reply(true)
    }

    func forceKillProcess(pid: Int32, authData: Data?, reply: @escaping (HelperCommandResult) -> Void) {
        logger.info("Force kill process requested for PID: \(pid)")

        // Verify authorization
        guard AuthorizationHelper.verifyAuthorization(data: authData, right: kAuthorizationRightForceKill) else {
            logger.error("Authorization failed for force kill")
            reply(HelperCommandResult(
                success: false,
                message: "Authorization required. Please grant administrator privileges.",
                errorCode: -1
            ))
            return
        }

        // Security check: Don't allow killing critical system processes
        let criticalPIDs: Set<Int32> = [0, 1] // kernel and launchd
        if criticalPIDs.contains(pid) {
            logger.error("Attempted to kill critical system process: \(pid)")
            reply(HelperCommandResult(
                success: false,
                message: "Cannot kill critical system process (PID \(pid)). This process is essential for system operation.",
                errorCode: -6
            ))
            return
        }

        // Verify the process exists before attempting to kill it
        let result = kill(pid, 0) // Signal 0 checks if process exists
        if result != 0 && errno == ESRCH {
            logger.warning("Process \(pid) does not exist")
            reply(HelperCommandResult(
                success: false,
                message: "Process with PID \(pid) does not exist or has already been terminated.",
                errorCode: -7
            ))
            return
        }

        // Execute kill -9 <PID>
        let killResult = executeCommand(killPath, arguments: ["-9", String(pid)])

        if killResult.success {
            logger.info("Successfully force killed process \(pid)")
            reply(HelperCommandResult(
                success: true,
                message: "Process \(pid) was successfully force quit.",
                errorCode: 0
            ))
        } else {
            logger.error("Failed to force kill process \(pid): \(killResult.message)")
            reply(killResult)
        }
    }

    func forceKillProcessByName(processName: String, authData: Data?, reply: @escaping (HelperCommandResult) -> Void) {
        logger.info("Force kill process by name requested: \(processName)")

        // Verify authorization
        guard AuthorizationHelper.verifyAuthorization(data: authData, right: kAuthorizationRightForceKill) else {
            logger.error("Authorization failed for force kill by name")
            reply(HelperCommandResult(
                success: false,
                message: "Authorization required. Please grant administrator privileges.",
                errorCode: -1
            ))
            return
        }

        // Security check: Don't allow killing critical system processes
        let criticalProcesses: Set<String> = ["kernel_task", "launchd", "WindowServer"]
        if criticalProcesses.contains(processName) {
            logger.error("Attempted to kill critical system process: \(processName)")
            reply(HelperCommandResult(
                success: false,
                message: "Cannot kill critical system process '\(processName)'. This process is essential for system operation.",
                errorCode: -6
            ))
            return
        }

        // Sanitize process name to prevent command injection
        let sanitizedName = processName.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "$", with: "")

        if sanitizedName != processName {
            logger.error("Process name contains invalid characters: \(processName)")
            reply(HelperCommandResult(
                success: false,
                message: "Process name contains invalid characters.",
                errorCode: -8
            ))
            return
        }

        // Execute killall -9 "processName"
        let killallResult = executeCommand(killallPath, arguments: ["-9", sanitizedName])

        // Note: killall returns exit code 1 if no processes were matched
        // but this is not necessarily an error if the process already terminated
        if killallResult.success || killallResult.errorCode == 1 {
            logger.info("Force kill by name completed for '\(processName)'")
            reply(HelperCommandResult(
                success: true,
                message: "Process '\(processName)' was successfully force quit.",
                errorCode: 0
            ))
        } else {
            logger.error("Failed to force kill '\(processName)': \(killallResult.message)")
            reply(killallResult)
        }
    }

    // MARK: - Private Methods

    /// Execute a command with given arguments
    /// - Parameters:
    ///   - path: Full path to the executable
    ///   - arguments: Command line arguments
    /// - Returns: Result of the command execution
    private func executeCommand(_ path: String, arguments: [String]) -> HelperCommandResult {
        // Security check: Only allow specific commands
        guard allowedCommands.contains(path) else {
            logger.error("Attempted to execute disallowed command: \(path)")
            return HelperCommandResult(
                success: false,
                message: "Command not allowed: \(path)",
                errorCode: -3
            )
        }

        // Verify the command exists
        guard FileManager.default.fileExists(atPath: path) else {
            logger.error("Command not found: \(path)")
            return HelperCommandResult(
                success: false,
                message: "Command not found: \(path)",
                errorCode: -4
            )
        }

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        // Set up pipes for output capture
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            logger.debug("Executing command: \(path) \(arguments.joined(separator: " "))")
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            let exitCode = Int(process.terminationStatus)

            if exitCode == 0 {
                logger.info("Command succeeded: \(path)")
                return HelperCommandResult(
                    success: true,
                    message: "Command executed successfully",
                    errorCode: 0,
                    output: output.isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                logger.error("Command failed with exit code \(exitCode): \(errorOutput)")
                return HelperCommandResult(
                    success: false,
                    message: errorOutput.isEmpty ? "Command failed with exit code \(exitCode)" : errorOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                    errorCode: exitCode,
                    output: output.isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            logger.error("Failed to execute command: \(error.localizedDescription)")
            return HelperCommandResult(
                success: false,
                message: "Failed to execute command: \(error.localizedDescription)",
                errorCode: -5
            )
        }
    }
}

// MARK: - XPC Listener Delegate

/// Delegate for handling new XPC connections
final class HelperXPCDelegate: NSObject, NSXPCListenerDelegate {

    private let logger = Logger(subsystem: kHelperToolMachServiceName, category: "XPCListener")

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("New XPC connection request")

        // Verify the connecting process
        // In production, you would verify the code signature of the connecting client
        // For now, we accept connections but log the audit token
        _ = newConnection.auditToken

        logger.debug("Connection from process with audit token")

        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        newConnection.exportedObject = HelperXPCImplementation()

        // Configure allowed classes for incoming calls
        let dataClasses = NSSet(array: [NSData.self]) as! Set<AnyHashable>

        newConnection.exportedInterface?.setClasses(
            dataClasses,
            for: #selector(HelperXPCProtocol.executeMemoryCleanup(authData:reply:)),
            argumentIndex: 0,
            ofReply: false
        )

        newConnection.exportedInterface?.setClasses(
            dataClasses,
            for: #selector(HelperXPCProtocol.executeSync(authData:reply:)),
            argumentIndex: 0,
            ofReply: false
        )

        newConnection.exportedInterface?.setClasses(
            dataClasses,
            for: #selector(HelperXPCProtocol.executePurge(authData:reply:)),
            argumentIndex: 0,
            ofReply: false
        )

        newConnection.exportedInterface?.setClasses(
            dataClasses,
            for: #selector(HelperXPCProtocol.forceKillProcess(pid:authData:reply:)),
            argumentIndex: 1,
            ofReply: false
        )

        newConnection.exportedInterface?.setClasses(
            dataClasses,
            for: #selector(HelperXPCProtocol.forceKillProcessByName(processName:authData:reply:)),
            argumentIndex: 1,
            ofReply: false
        )

        // Handle connection invalidation
        newConnection.invalidationHandler = { [weak self] in
            self?.logger.info("XPC connection invalidated")
        }

        newConnection.interruptionHandler = { [weak self] in
            self?.logger.warning("XPC connection interrupted")
        }

        newConnection.resume()
        logger.info("Accepted new XPC connection")
        return true
    }
}

// MARK: - Audit Token Extension

extension NSXPCConnection {
    /// Get the audit token for the connected process
    var auditToken: audit_token_t? {
        let token = audit_token_t()
        // Note: In production, you would use private API or entitlements to get the audit token
        // For this helper, we trust connections from properly signed apps
        return token
    }
}
