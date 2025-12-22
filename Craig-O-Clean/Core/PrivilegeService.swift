// MARK: - PrivilegeService.swift
// Craig-O-Clean - Privilege Management Service
// Manages installation and communication with the privileged helper tool

import Foundation
import ServiceManagement
import os.log

// MARK: - Helper Tool Constants (shared with helper)

/// The bundle identifier for the helper tool
private let kHelperToolMachServiceName = "com.CraigOClean.helper"

/// Authorization rights for helper installation
private let kAuthorizationRightInstall = "com.CraigOClean.helper.install"

/// Authorization rights for memory cleanup
private let kAuthorizationRightMemoryClean = "com.CraigOClean.helper.memoryclean"

// MARK: - Privilege Service Result

/// Result of a privileged operation
public struct PrivilegeOperationResult: Equatable {
    public let success: Bool
    public let message: String
    public let errorCode: Int
    public let output: String?

    public init(success: Bool, message: String, errorCode: Int = 0, output: String? = nil) {
        self.success = success
        self.message = message
        self.errorCode = errorCode
        self.output = output
    }

    public static func == (lhs: PrivilegeOperationResult, rhs: PrivilegeOperationResult) -> Bool {
        return lhs.success == rhs.success &&
               lhs.message == rhs.message &&
               lhs.errorCode == rhs.errorCode &&
               lhs.output == rhs.output
    }
}

// MARK: - Helper Status

/// Status of the privileged helper
public enum HelperStatus: Equatable {
    case notInstalled
    case installed(version: String)
    case needsUpdate(currentVersion: String, requiredVersion: String)
    case installationFailed(error: String)
    case unknown

    public var isInstalled: Bool {
        switch self {
        case .installed, .needsUpdate:
            return true
        default:
            return false
        }
    }
}

// MARK: - Privilege Service Protocol

/// Protocol for privilege service to enable testing
public protocol PrivilegeServiceProtocol {
    var helperStatus: HelperStatus { get }
    var isHelperInstalled: Bool { get }
    var isPurgeAvailable: Bool { get }

    func checkHelperStatus() async
    func installHelper() async -> PrivilegeOperationResult
    func executeMemoryCleanup() async -> PrivilegeOperationResult
    func executeSync() async -> PrivilegeOperationResult
    func executePurge() async -> PrivilegeOperationResult
}

// MARK: - Privilege Service

/// Service for managing privileged operations via the helper tool
/// Handles helper installation (SMJobBless) and XPC communication
@MainActor
public final class PrivilegeService: ObservableObject, PrivilegeServiceProtocol {

    // MARK: - Published Properties

    @Published public private(set) var helperStatus: HelperStatus = .unknown
    @Published public private(set) var isHelperInstalled: Bool = false
    @Published public private(set) var isPurgeAvailable: Bool = false
    @Published public private(set) var isOperationInProgress: Bool = false
    @Published public private(set) var lastOperationResult: PrivilegeOperationResult?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "PrivilegeService")
    private var xpcConnection: NSXPCConnection?
    private let requiredHelperVersion = "1.0.0"

    // MARK: - Debug Mode

    /// Whether to use the debug fallback (osascript) instead of the helper
    /// This is automatically enabled when the helper is not installed and we're in a debug build
    #if DEBUG
    private var useDebugFallback: Bool = true
    #else
    private var useDebugFallback: Bool = false
    #endif

    // MARK: - Initialization

    public init() {
        logger.info("PrivilegeService initialized")
    }

    deinit {
        invalidateConnection()
    }

    // MARK: - Public Methods

    /// Check the current status of the helper tool
    public func checkHelperStatus() async {
        logger.info("Checking helper status...")

        // Try to connect and get version
        do {
            let version = try await getHelperVersion()

            if version == requiredHelperVersion {
                helperStatus = .installed(version: version)
                isHelperInstalled = true
                logger.info("Helper installed with correct version: \(version)")
            } else {
                helperStatus = .needsUpdate(currentVersion: version, requiredVersion: requiredHelperVersion)
                isHelperInstalled = true
                logger.warning("Helper needs update: \(version) -> \(self.requiredHelperVersion)")
            }

            // Check purge availability
            isPurgeAvailable = await checkPurgeAvailability()

        } catch {
            helperStatus = .notInstalled
            isHelperInstalled = false
            logger.info("Helper not installed or not responding: \(error.localizedDescription)")

            // In debug mode, check if purge exists on the system
            #if DEBUG
            isPurgeAvailable = FileManager.default.fileExists(atPath: "/usr/bin/purge")
            #endif
        }
    }

    /// Install the privileged helper tool using SMJobBless
    public func installHelper() async -> PrivilegeOperationResult {
        logger.info("Attempting to install helper...")
        isOperationInProgress = true

        defer {
            Task { @MainActor in
                isOperationInProgress = false
            }
        }

        // Request authorization for installation
        guard let authRef = createAuthorizationRef() else {
            let result = PrivilegeOperationResult(
                success: false,
                message: "Failed to create authorization. Please try again.",
                errorCode: -1
            )
            lastOperationResult = result
            return result
        }

        defer { AuthorizationFree(authRef, []) }

        // Install helper using SMJobBless
        var error: Unmanaged<CFError>?

        // Note: SMJobBless requires proper code signing and entitlements
        // The helper's Info.plist must have SMAuthorizedClients
        // The app's Info.plist must have SMPrivilegedExecutables

        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            kHelperToolMachServiceName as CFString,
            authRef,
            &error
        )

        if success {
            logger.info("Helper installed successfully")
            await checkHelperStatus()
            let result = PrivilegeOperationResult(
                success: true,
                message: "Helper tool installed successfully. You can now use advanced memory cleanup features.",
                errorCode: 0
            )
            lastOperationResult = result
            return result
        } else {
            let errorMessage = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            logger.error("Helper installation failed: \(errorMessage)")

            helperStatus = .installationFailed(error: errorMessage)

            #if DEBUG
            // In debug builds, provide instructions
            let debugMessage = """
            Helper installation failed: \(errorMessage)

            In Debug mode, the app will use AppleScript as a fallback for privileged operations.
            For Release builds, proper code signing is required.

            See HELPER_SETUP.md for code signing requirements.
            """
            let result = PrivilegeOperationResult(
                success: false,
                message: debugMessage,
                errorCode: -2
            )
            #else
            let result = PrivilegeOperationResult(
                success: false,
                message: "Helper installation failed: \(errorMessage). Please ensure the app is properly signed and try again.",
                errorCode: -2
            )
            #endif

            lastOperationResult = result
            return result
        }
    }

    /// Execute memory cleanup (sync + purge) via the helper
    public func executeMemoryCleanup() async -> PrivilegeOperationResult {
        logger.info("Executing memory cleanup...")
        isOperationInProgress = true

        defer {
            Task { @MainActor in
                isOperationInProgress = false
            }
        }

        // Check if we should use debug fallback
        if shouldUseDebugFallback() {
            return await executeMemoryCleanupViaAppleScript()
        }

        // Use helper via XPC
        return await executeViaHelper { helper, authData, reply in
            helper.executeMemoryCleanup(authData: authData, reply: reply)
        }
    }

    /// Execute only the sync command
    public func executeSync() async -> PrivilegeOperationResult {
        logger.info("Executing sync...")
        isOperationInProgress = true

        defer {
            Task { @MainActor in
                isOperationInProgress = false
            }
        }

        if shouldUseDebugFallback() {
            return await executeSyncViaAppleScript()
        }

        return await executeViaHelper { helper, authData, reply in
            helper.executeSync(authData: authData, reply: reply)
        }
    }

    /// Execute only the purge command
    public func executePurge() async -> PrivilegeOperationResult {
        logger.info("Executing purge...")
        isOperationInProgress = true

        defer {
            Task { @MainActor in
                isOperationInProgress = false
            }
        }

        if shouldUseDebugFallback() {
            return await executePurgeViaAppleScript()
        }

        return await executeViaHelper { helper, authData, reply in
            helper.executePurge(authData: authData, reply: reply)
        }
    }

    // MARK: - Private Methods - XPC

    /// Get or create the XPC connection to the helper
    private func getConnection() -> NSXPCConnection {
        if let connection = xpcConnection {
            return connection
        }

        let connection = NSXPCConnection(machServiceName: kHelperToolMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocolProxy.self)

        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.xpcConnection = nil
                self?.logger.info("XPC connection invalidated")
            }
        }

        connection.interruptionHandler = { [weak self] in
            self?.logger.warning("XPC connection interrupted")
        }

        connection.resume()
        xpcConnection = connection
        return connection
    }

    /// Invalidate the current XPC connection
    private func invalidateConnection() {
        xpcConnection?.invalidate()
        xpcConnection = nil
    }

    /// Get the helper version via XPC
    private func getHelperVersion() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = getConnection()

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(throwing: error)
            }) as? HelperXPCProtocolProxy else {
                continuation.resume(throwing: NSError(domain: "PrivilegeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get proxy"]))
                return
            }

            proxy.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }

    /// Check if purge is available via the helper
    private func checkPurgeAvailability() async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = getConnection()

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                continuation.resume(returning: false)
            }) as? HelperXPCProtocolProxy else {
                continuation.resume(returning: false)
                return
            }

            proxy.isPurgeAvailable { available in
                continuation.resume(returning: available)
            }
        }
    }

    /// Execute a command via the helper
    private func executeViaHelper(
        command: @escaping (HelperXPCProtocolProxy, Data?, @escaping (HelperCommandResultProxy) -> Void) -> Void
    ) async -> PrivilegeOperationResult {

        // Create authorization data
        guard let authData = createAuthorizationData() else {
            let result = PrivilegeOperationResult(
                success: false,
                message: "Failed to obtain authorization. Please grant administrator privileges and try again.",
                errorCode: -1
            )
            lastOperationResult = result
            return result
        }

        return await withCheckedContinuation { continuation in
            let connection = getConnection()

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                let result = PrivilegeOperationResult(
                    success: false,
                    message: "Connection to helper failed: \(error.localizedDescription)",
                    errorCode: -2
                )
                Task { @MainActor [weak self] in
                    self?.lastOperationResult = result
                }
                continuation.resume(returning: result)
            }) as? HelperXPCProtocolProxy else {
                let result = PrivilegeOperationResult(
                    success: false,
                    message: "Failed to connect to helper tool.",
                    errorCode: -3
                )
                Task { @MainActor [weak self] in
                    self?.lastOperationResult = result
                }
                continuation.resume(returning: result)
                return
            }

            command(proxy, authData) { commandResult in
                let result = PrivilegeOperationResult(
                    success: commandResult.success,
                    message: commandResult.message,
                    errorCode: commandResult.errorCode,
                    output: commandResult.output
                )
                Task { @MainActor [weak self] in
                    self?.lastOperationResult = result
                }
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Private Methods - Authorization

    /// Create an authorization reference
    private func createAuthorizationRef() -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            logger.error("Failed to create authorization reference")
            return nil
        }

        // Request rights for installation
        var installItem = kAuthorizationRightInstall.withCString { cString in
            AuthorizationItem(
                name: cString,
                valueLength: 0,
                value: nil,
                flags: 0
            )
        }

        var rights = AuthorizationRights(count: 1, items: &installItem)

        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        let copyStatus = AuthorizationCopyRights(auth, &rights, nil, flags, nil)

        guard copyStatus == errAuthorizationSuccess else {
            logger.error("Failed to copy authorization rights")
            AuthorizationFree(auth, [])
            return nil
        }

        return auth
    }

    /// Create authorization data for XPC calls
    private func createAuthorizationData() -> Data? {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            return nil
        }

        defer { AuthorizationFree(auth, []) }

        // Request memory clean rights
        var cleanItem = kAuthorizationRightMemoryClean.withCString { cString in
            AuthorizationItem(
                name: cString,
                valueLength: 0,
                value: nil,
                flags: 0
            )
        }

        var rights = AuthorizationRights(count: 1, items: &cleanItem)
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]

        let copyStatus = AuthorizationCopyRights(auth, &rights, nil, flags, nil)
        guard copyStatus == errAuthorizationSuccess else {
            return nil
        }

        var externalForm = AuthorizationExternalForm()
        let externalStatus = AuthorizationMakeExternalForm(auth, &externalForm)
        guard externalStatus == errAuthorizationSuccess else {
            return nil
        }

        return Data(bytes: &externalForm, count: MemoryLayout<AuthorizationExternalForm>.size)
    }

    // MARK: - Private Methods - Debug Fallback

    /// Check if we should use the debug fallback
    private func shouldUseDebugFallback() -> Bool {
        #if DEBUG
        return !isHelperInstalled && useDebugFallback
        #else
        return false
        #endif
    }

    /// Execute memory cleanup via AppleScript (debug fallback)
    private func executeMemoryCleanupViaAppleScript() async -> PrivilegeOperationResult {
        logger.warning("Using AppleScript fallback for memory cleanup (Debug mode)")

        // First run sync
        let syncResult = await executeSyncViaAppleScript()
        guard syncResult.success else {
            return syncResult
        }

        // Check if purge exists
        guard FileManager.default.fileExists(atPath: "/usr/bin/purge") else {
            let result = PrivilegeOperationResult(
                success: true,
                message: "Sync completed. Note: purge command is not available on this system.",
                errorCode: 0,
                output: syncResult.output
            )
            lastOperationResult = result
            return result
        }

        // Run purge
        let purgeResult = await executePurgeViaAppleScript()

        if purgeResult.success {
            let result = PrivilegeOperationResult(
                success: true,
                message: "[Debug Mode] Memory cleanup completed. File system buffers flushed and inactive memory purged.",
                errorCode: 0,
                output: "Sync: OK, Purge: OK"
            )
            lastOperationResult = result
            return result
        } else {
            let result = PrivilegeOperationResult(
                success: false,
                message: "[Debug Mode] Sync completed but purge failed: \(purgeResult.message)",
                errorCode: purgeResult.errorCode
            )
            lastOperationResult = result
            return result
        }
    }

    /// Execute sync via AppleScript (debug fallback)
    private func executeSyncViaAppleScript() async -> PrivilegeOperationResult {
        let script = """
        do shell script "/bin/sync" with administrator privileges
        """
        return await runAppleScript(script, operation: "sync")
    }

    /// Execute purge via AppleScript (debug fallback)
    private func executePurgeViaAppleScript() async -> PrivilegeOperationResult {
        let script = """
        do shell script "/usr/bin/purge" with administrator privileges
        """
        return await runAppleScript(script, operation: "purge")
    }

    /// Run an AppleScript with error handling
    private func runAppleScript(_ source: String, operation: String) async -> PrivilegeOperationResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let appleScript = NSAppleScript(source: source)
                var errorInfo: NSDictionary?
                appleScript?.executeAndReturnError(&errorInfo)

                let result: PrivilegeOperationResult
                if let error = errorInfo {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    self?.logger.error("AppleScript \(operation) failed: \(message)")
                    result = PrivilegeOperationResult(
                        success: false,
                        message: "[\(operation)] \(message)",
                        errorCode: -1
                    )
                } else {
                    self?.logger.info("AppleScript \(operation) succeeded")
                    result = PrivilegeOperationResult(
                        success: true,
                        message: "[\(operation)] completed successfully",
                        errorCode: 0
                    )
                }

                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - XPC Protocol Proxy

/// Proxy protocol for XPC communication (mirrors HelperXPCProtocol)
/// This avoids importing the helper module directly
@objc protocol HelperXPCProtocolProxy {
    func getVersion(reply: @escaping (String) -> Void)
    func executeMemoryCleanup(authData: Data?, reply: @escaping (HelperCommandResultProxy) -> Void)
    func executeSync(authData: Data?, reply: @escaping (HelperCommandResultProxy) -> Void)
    func executePurge(authData: Data?, reply: @escaping (HelperCommandResultProxy) -> Void)
    func isPurgeAvailable(reply: @escaping (Bool) -> Void)
    func ping(reply: @escaping (Bool) -> Void)
}

/// Proxy for helper command result (mirrors HelperCommandResult)
@objc class HelperCommandResultProxy: NSObject, NSSecureCoding {
    @objc var success: Bool
    @objc var message: String
    @objc var errorCode: Int
    @objc var output: String?

    static var supportsSecureCoding: Bool { true }

    @objc init(success: Bool, message: String, errorCode: Int, output: String?) {
        self.success = success
        self.message = message
        self.errorCode = errorCode
        self.output = output
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(success, forKey: "success")
        coder.encode(message, forKey: "message")
        coder.encode(errorCode, forKey: "errorCode")
        coder.encode(output, forKey: "output")
    }

    required init?(coder: NSCoder) {
        success = coder.decodeBool(forKey: "success")
        message = coder.decodeObject(of: NSString.self, forKey: "message") as String? ?? ""
        errorCode = coder.decodeInteger(forKey: "errorCode")
        output = coder.decodeObject(of: NSString.self, forKey: "output") as String?
        super.init()
    }
}
