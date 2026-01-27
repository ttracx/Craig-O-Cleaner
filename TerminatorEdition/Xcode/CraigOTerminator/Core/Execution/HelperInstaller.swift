//
//  HelperInstaller.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import ServiceManagement
import Security
import os.log

/// Manages the installation and lifecycle of the privileged helper tool
@Observable
final class HelperInstaller {

    // MARK: - Singleton

    static let shared = HelperInstaller()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "HelperInstaller")
    private var xpcConnection: NSXPCConnection?

    // MARK: - Observable State

    private(set) var status: HelperStatus = .unknown
    private(set) var isInstalling = false
    private(set) var lastError: HelperError?

    // MARK: - Initialization

    private init() {
        Task {
            await checkStatus()
        }
    }

    // MARK: - Status Checking

    /// Check the current status of the helper tool
    @MainActor
    func checkStatus() async {
        logger.info("Checking helper status...")

        // Try to connect to helper
        guard let connection = createConnection() else {
            status = .notInstalled
            logger.info("Helper is not installed")
            return
        }

        defer {
            connection.invalidate()
        }

        do {
            let version = try await getHelperVersion(connection: connection)
            logger.info("Helper version: \(version)")

            if version == HelperConstants.currentVersion {
                status = .installed(version: version)
            } else {
                status = .outdated(current: version, required: HelperConstants.currentVersion)
            }
        } catch {
            logger.error("Failed to get helper version: \(error.localizedDescription)")
            status = .notInstalled
        }
    }

    /// Check if helper is installed
    func isInstalled() async -> Bool {
        await checkStatus()
        return status.isInstalled
    }

    // MARK: - Installation

    /// Install or update the helper tool using SMJobBless
    @MainActor
    func install() async throws {
        logger.info("Installing helper tool...")

        guard !isInstalling else {
            throw HelperError.installationFailed(NSError(
                domain: "HelperInstaller",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Installation already in progress"]
            ))
        }

        isInstalling = true
        defer { isInstalling = false }

        // Get authorization
        let authRef = try await requestAuthorization()
        defer {
            AuthorizationFree(authRef, [])
        }

        // Use SMJobBless to install helper
        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            HelperConstants.bundleID as CFString,
            authRef,
            &error
        )

        if let error = error?.takeRetainedValue() {
            logger.error("SMJobBless failed: \(error.localizedDescription)")
            throw HelperError.installationFailed(error as Error)
        }

        guard success else {
            throw HelperError.installationFailed(NSError(
                domain: "HelperInstaller",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "SMJobBless returned false"]
            ))
        }

        logger.info("Helper tool installed successfully")

        // Verify installation
        await checkStatus()

        guard status.isInstalled else {
            throw HelperError.installationFailed(NSError(
                domain: "HelperInstaller",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Helper installation completed but verification failed"]
            ))
        }
    }

    /// Uninstall the helper tool
    @MainActor
    func uninstall() async throws {
        logger.info("Uninstalling helper tool...")

        // Get authorization
        let authRef = try await requestAuthorization()
        defer {
            AuthorizationFree(authRef, [])
        }

        // Create authorization item
        var rightName = HelperConstants.authorizationRight
        var rightItem = AuthorizationItem(name: rightName.withCString { strdup($0) }, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &rightItem)

        // Remove helper using SMJobRemove
        var error: Unmanaged<CFError>?
        let success = SMJobRemove(
            kSMDomainSystemLaunchd,
            HelperConstants.bundleID as CFString,
            authRef,
            true,
            &error
        )

        // Free the duplicated string
        free(rightItem.name)

        if let error = error?.takeRetainedValue() {
            logger.error("SMJobRemove failed: \(error.localizedDescription)")
            throw HelperError.installationFailed(error as Error)
        }

        guard success else {
            throw HelperError.installationFailed(NSError(
                domain: "HelperInstaller",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "SMJobRemove returned false"]
            ))
        }

        logger.info("Helper tool uninstalled successfully")

        // Update status
        status = .notInstalled
    }

    // MARK: - Authorization

    private func requestAuthorization() async throws -> AuthorizationRef {
        logger.info("Requesting authorization...")

        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(
            name: kSMRightBlessPrivilegedHelper,
            valueLength: 0,
            value: nil,
            flags: 0
        )
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            logger.error("Authorization failed with status: \(status)")

            if status == errAuthorizationCanceled {
                throw HelperError.authorizationDenied
            }

            throw HelperError.installationFailed(NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Authorization failed"]
            ))
        }

        logger.info("Authorization granted")
        return auth
    }

    // MARK: - XPC Connection

    /// Create an XPC connection to the helper tool
    func createConnection() -> NSXPCConnection? {
        logger.debug("Creating XPC connection to helper...")

        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)

        connection.invalidationHandler = { [weak self] in
            self?.logger.info("XPC connection invalidated")
            self?.xpcConnection = nil
        }

        connection.interruptionHandler = { [weak self] in
            self?.logger.warning("XPC connection interrupted")
        }

        connection.resume()

        // Test connection with a ping
        let proxy = connection.synchronousRemoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("XPC connection error: \(error.localizedDescription)")
        }

        // Try to ping the helper to verify connection
        let semaphore = DispatchSemaphore(value: 0)
        var isConnected = false

        if let helper = proxy as? HelperProtocol {
            helper.ping { _ in
                isConnected = true
                semaphore.signal()
            }

            // Wait up to 2 seconds for response
            let timeout = DispatchTime.now() + .seconds(2)
            if semaphore.wait(timeout: timeout) == .timedOut {
                logger.warning("Helper ping timeout")
                connection.invalidate()
                return nil
            }
        }

        if !isConnected {
            connection.invalidate()
            return nil
        }

        logger.debug("XPC connection established")
        return connection
    }

    /// Get a connection to the helper tool, creating one if needed
    func getConnection() -> NSXPCConnection? {
        if let existing = xpcConnection {
            return existing
        }

        let connection = createConnection()
        xpcConnection = connection
        return connection
    }

    // MARK: - Helper Communication

    private func getHelperVersion(connection: NSXPCConnection) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: HelperError.connectionFailed(error))
            }

            guard let helper = proxy as? HelperProtocol else {
                continuation.resume(throwing: HelperError.invalidResponse)
                return
            }

            helper.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }

    /// Execute a command via the helper tool
    func executeCommand(
        _ command: String,
        arguments: [String],
        workingDirectory: String?,
        authData: Data
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {

        guard let connection = getConnection() else {
            throw HelperError.connectionFailed(NSError(
                domain: "HelperInstaller",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create XPC connection"]
            ))
        }

        return try await withCheckedThrowingContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: HelperError.connectionFailed(error))
            }

            guard let helper = proxy as? HelperProtocol else {
                continuation.resume(throwing: HelperError.invalidResponse)
                return
            }

            helper.executeCommand(
                command,
                arguments: arguments,
                workingDirectory: workingDirectory,
                authData: authData
            ) { exitCode, stdout, stderr, error in
                if let error = error {
                    continuation.resume(throwing: HelperError.executionFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: (exitCode, stdout, stderr))
                }
            }
        }
    }

    // MARK: - Authorization Data

    /// Create authorization data for helper communication
    func createAuthorizationData() async throws -> Data {
        let authRef = try await requestAuthorization()
        defer {
            AuthorizationFree(authRef, [])
        }

        var authExtForm = AuthorizationExternalForm()
        let status = AuthorizationMakeExternalForm(authRef, &authExtForm)

        guard status == errAuthorizationSuccess else {
            throw HelperError.invalidAuthData
        }

        return Data(bytes: &authExtForm.bytes, count: kAuthorizationExternalFormLength)
    }
}
