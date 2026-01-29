// File: CraigOClean-vNext/CraigOClean/PrivilegedHelper/HelperXPC/HelperClient.swift
// Craig-O-Clean - Helper Client
// Client-side XPC connection to the privileged helper

import Foundation

/// Client for communicating with the privileged helper via XPC.
/// This class manages the XPC connection and provides async/await wrappers
/// for helper operations.
@MainActor
public final class HelperClient: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var helperVersion: String?

    private var connection: NSXPCConnection?
    private let logger: Logger

    // MARK: - Initialization

    public init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Connection Management

    /// Establishes connection to the helper
    public func connect() async throws {
        logger.debug("Connecting to privileged helper...", category: .system)

        // Check if helper is installed
        guard isHelperInstalled() else {
            throw HelperError.notInstalled
        }

        // Create XPC connection
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)

        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.handleInvalidation()
            }
        }

        connection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.handleInterruption()
            }
        }

        connection.resume()
        self.connection = connection

        // Verify connection
        do {
            helperVersion = try await getVersion()
            isConnected = true
            logger.info("Connected to helper v\(helperVersion ?? "unknown")", category: .system)
        } catch {
            disconnect()
            throw HelperError.connectionFailed
        }
    }

    /// Disconnects from the helper
    public func disconnect() {
        connection?.invalidate()
        connection = nil
        isConnected = false
        helperVersion = nil
        logger.debug("Disconnected from privileged helper", category: .system)
    }

    // MARK: - Helper Operations

    /// Gets the helper version
    public func getVersion() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            guard let helper = helper else {
                continuation.resume(throwing: HelperError.connectionFailed)
                return
            }

            helper.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }

    /// Deletes files at the specified paths
    public func deleteFiles(atPaths paths: [String]) async throws {
        logger.debug("Requesting deletion of \(paths.count) files via helper", category: .cleanup)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = helper else {
                continuation.resume(throwing: HelperError.connectionFailed)
                return
            }

            helper.deleteFiles(atPaths: paths) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HelperError.operationFailed(reason: errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    /// Calculates directory size
    public func calculateDirectorySize(atPath path: String) async throws -> UInt64 {
        try await withCheckedThrowingContinuation { continuation in
            guard let helper = helper else {
                continuation.resume(throwing: HelperError.connectionFailed)
                return
            }

            helper.calculateDirectorySize(atPath: path) { size in
                continuation.resume(returning: size)
            }
        }
    }

    /// Clears system caches
    public func clearSystemCaches() async throws -> UInt64 {
        logger.info("Requesting system cache clear via helper", category: .cleanup)

        return try await withCheckedThrowingContinuation { continuation in
            guard let helper = helper else {
                continuation.resume(throwing: HelperError.connectionFailed)
                return
            }

            helper.clearSystemCaches { bytesFreed, errorMessage in
                if let error = errorMessage {
                    continuation.resume(throwing: HelperError.operationFailed(reason: error))
                } else {
                    continuation.resume(returning: bytesFreed)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private var helper: HelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("XPC error: \(error.localizedDescription)", category: .system)
        } as? HelperProtocol
    }

    private func handleInvalidation() {
        logger.warning("Helper connection invalidated", category: .system)
        isConnected = false
        connection = nil
    }

    private func handleInterruption() {
        logger.warning("Helper connection interrupted", category: .system)
        isConnected = false
    }

    private func isHelperInstalled() -> Bool {
        FileManager.default.fileExists(atPath: HelperConstants.helperToolLocation)
    }
}

// MARK: - Helper Installation

extension HelperClient {

    /// Installs the privileged helper using SMJobBless
    public func installHelper() async throws {
        logger.info("Installing privileged helper...", category: .system)

        // TODO: Implement SMJobBless installation
        // This requires:
        // 1. Proper code signing with matching team ID
        // 2. Info.plist with SMPrivilegedExecutables
        // 3. Helper's Info.plist with SMAuthorizedClients
        // 4. Launchd plist embedded in helper

        throw HelperError.operationFailed(reason: "Helper installation not yet implemented")
    }

    /// Uninstalls the privileged helper
    public func uninstallHelper() async throws {
        logger.info("Uninstalling privileged helper...", category: .system)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = helper else {
                continuation.resume(throwing: HelperError.connectionFailed)
                return
            }

            helper.uninstallHelper { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HelperError.operationFailed(reason: "Uninstall failed"))
                }
            }
        }

        disconnect()
    }
}
