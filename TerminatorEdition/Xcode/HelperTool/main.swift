//
//  main.swift
//  HelperTool
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import Security
import os.log

/// Helper tool version - must match HelperConstants.currentVersion
private let helperVersion = "1.0.0"

/// Logger for helper tool
private let logger = Logger(subsystem: "ai.neuralquantum.CraigOTerminator.helper", category: "main")

/// Privileged helper tool main class
class HelperTool: NSObject, HelperProtocol, NSXPCListenerDelegate {

    // MARK: - Properties

    private let listener: NSXPCListener
    private var connections = [NSXPCConnection]()

    // MARK: - Initialization

    override init() {
        self.listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }

    // MARK: - Run

    func run() {
        logger.info("Helper tool v\(helperVersion) starting...")
        listener.resume()
        RunLoop.current.run()
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("New XPC connection request from PID: \(newConnection.processIdentifier)")

        // Configure connection
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self

        // Set up invalidation handler
        newConnection.invalidationHandler = { [weak self, weak newConnection] in
            guard let self = self, let connection = newConnection else { return }
            logger.info("Connection invalidated for PID: \(connection.processIdentifier)")
            self.connections.removeAll { $0 === connection }
        }

        // Set up interruption handler
        newConnection.interruptionHandler = { [weak newConnection] in
            guard let connection = newConnection else { return }
            logger.warning("Connection interrupted for PID: \(connection.processIdentifier)")
        }

        // Store connection and resume
        connections.append(newConnection)
        newConnection.resume()

        logger.info("Accepted connection from PID: \(newConnection.processIdentifier)")
        return true
    }

    // MARK: - HelperProtocol

    func executeCommand(
        _ command: String,
        arguments: [String],
        workingDirectory: String?,
        authData: Data?,
        reply: @escaping (Int32, String, String, Error?) -> Void
    ) {
        logger.info("Execute command request: \(command)")

        // Verify authorization
        guard let authData = authData else {
            logger.error("No authorization data provided")
            reply(-1, "", "Authorization required", HelperError.invalidAuthData)
            return
        }

        guard verifyAuthorization(authData) else {
            logger.error("Authorization verification failed")
            reply(-1, "", "Authorization denied", HelperError.authorizationDenied)
            return
        }

        // Validate command is in allowlist
        guard isCommandAllowed(command) else {
            logger.error("Command not in allowlist: \(command)")
            reply(-1, "", "Command not allowed", HelperError.commandNotAllowed(command))
            return
        }

        // Verify command exists
        guard FileManager.default.fileExists(atPath: command) else {
            logger.error("Command not found: \(command)")
            reply(-1, "", "Command not found", HelperError.commandNotFound(command))
            return
        }

        logger.info("Executing: \(command) \(arguments.joined(separator: " "))")

        // Execute command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let workingDir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set up termination handler
        var stdoutData = Data()
        var stderrData = Data()

        do {
            try process.run()

            // Read output
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let exitCode = process.terminationStatus
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            logger.info("Command completed with exit code: \(exitCode)")

            // Log to system log for audit trail
            logToSystemLog(command: command, arguments: arguments, exitCode: exitCode)

            reply(exitCode, stdout, stderr, nil)

        } catch {
            logger.error("Failed to execute command: \(error.localizedDescription)")
            reply(-1, "", error.localizedDescription, error)
        }
    }

    func getVersion(reply: @escaping (String) -> Void) {
        logger.debug("Version request")
        reply(helperVersion)
    }

    func ping(reply: @escaping (String) -> Void) {
        logger.debug("Ping request")
        reply("pong")
    }

    // MARK: - Authorization

    private func verifyAuthorization(_ authData: Data) -> Bool {
        var authRef: AuthorizationRef?

        // Convert external form to AuthorizationRef
        let authExtForm = authData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> AuthorizationExternalForm in
            var extForm = AuthorizationExternalForm()
            let pointer = bytes.baseAddress!.assumingMemoryBound(to: Int8.self)
            withUnsafeMutableBytes(of: &extForm.bytes) { destBytes in
                destBytes.copyMemory(from: UnsafeRawBufferPointer(start: pointer, count: kAuthorizationExternalFormLength))
            }
            return extForm
        }

        let status = AuthorizationCreateFromExternalForm(&authExtForm as! UnsafePointer<AuthorizationExternalForm>, &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            logger.error("Failed to create authorization from external form: \(status)")
            return false
        }

        defer {
            AuthorizationFree(auth, [])
        }

        // Define the right we're checking for
        var rightName = HelperConstants.authorizationRight
        var rightItem = AuthorizationItem(name: rightName.withCString { strdup($0) }, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &rightItem)

        // Check authorization
        let copyStatus = AuthorizationCopyRights(
            auth,
            &rights,
            nil,
            [.extendRights, .interactionAllowed],
            nil
        )

        // Free the duplicated string
        free(rightItem.name)

        if copyStatus == errAuthorizationSuccess {
            logger.info("Authorization verified successfully")
            return true
        } else {
            logger.error("Authorization check failed: \(copyStatus)")
            return false
        }
    }

    // MARK: - Command Allowlist

    private func isCommandAllowed(_ command: String) -> Bool {
        // Allowlist of commands that can be executed with elevated privileges
        // These match the catalog.json elevated capabilities
        let allowedCommands: Set<String> = [
            "/usr/sbin/diskutil",          // Disk utilities
            "/usr/bin/purge",              // Memory purge
            "/usr/bin/dscacheutil",        // DNS cache
            "/usr/bin/mdutil",             // Spotlight
            "/usr/sbin/periodic",          // Maintenance scripts
            "/usr/bin/killall",            // Process control
            "/bin/rm",                     // File operations
            "/usr/bin/log",                // System logs
            "/usr/sbin/sysctl"             // System control
        ]

        return allowedCommands.contains(command)
    }

    // MARK: - Audit Logging

    private func logToSystemLog(command: String, arguments: [String], exitCode: Int32) {
        let commandLine = "\(command) \(arguments.joined(separator: " "))"
        let logMessage = "CraigOTerminator Helper: Executed '\(commandLine)' with exit code \(exitCode)"

        // Log to os_log for system audit trail
        logger.notice("\(logMessage)")

        // Also log to ASL (Apple System Log) for compatibility
        asl_log(nil, nil, ASL_LEVEL_NOTICE, "%s", logMessage)
    }
}

// MARK: - Main Entry Point

autoreleasepool {
    logger.info("Helper tool v\(helperVersion) initializing...")

    let helper = HelperTool()
    helper.run()
}
