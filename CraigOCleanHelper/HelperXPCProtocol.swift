// MARK: - HelperXPCProtocol.swift
// CraigOCleanHelper - Privileged Helper Tool XPC Protocol
// Defines the interface for secure communication between main app and helper

import Foundation

// MARK: - Helper Tool Constants

/// The bundle identifier for the helper tool
let kHelperToolMachServiceName = "com.CraigOClean.helper"

/// Authorization rights for helper installation
let kAuthorizationRightInstall = "com.CraigOClean.helper.install"

/// Authorization rights for memory cleanup
let kAuthorizationRightMemoryClean = "com.CraigOClean.helper.memoryclean"

/// Authorization rights for force killing processes
let kAuthorizationRightForceKill = "com.CraigOClean.helper.forcekill"

// MARK: - Command Result

/// Result of executing a privileged command
@objc public class HelperCommandResult: NSObject, NSSecureCoding {
    @objc public var success: Bool
    @objc public var message: String
    @objc public var errorCode: Int
    @objc public var output: String?

    @objc public init(success: Bool, message: String, errorCode: Int = 0, output: String? = nil) {
        self.success = success
        self.message = message
        self.errorCode = errorCode
        self.output = output
        super.init()
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool { true }

    public func encode(with coder: NSCoder) {
        coder.encode(success, forKey: "success")
        coder.encode(message, forKey: "message")
        coder.encode(errorCode, forKey: "errorCode")
        coder.encode(output, forKey: "output")
    }

    public required init?(coder: NSCoder) {
        success = coder.decodeBool(forKey: "success")
        message = coder.decodeObject(of: NSString.self, forKey: "message") as String? ?? ""
        errorCode = coder.decodeInteger(forKey: "errorCode")
        output = coder.decodeObject(of: NSString.self, forKey: "output") as String?
        super.init()
    }
}

// MARK: - Helper Protocol

/// Protocol defining the XPC interface for the privileged helper tool
/// This protocol defines the commands that the helper can execute with elevated privileges
@objc(HelperXPCProtocol)
public protocol HelperXPCProtocol {

    /// Get the version of the helper tool
    /// - Parameter reply: Callback with the version string
    func getVersion(reply: @escaping (String) -> Void)

    /// Execute memory cleanup (sync + purge)
    /// This runs the system commands to flush file system buffers and purge inactive memory
    /// - Parameters:
    ///   - authData: Authorization data for privilege verification
    ///   - reply: Callback with the result of the operation
    func executeMemoryCleanup(authData: Data?, reply: @escaping (HelperCommandResult) -> Void)

    /// Execute only the sync command
    /// Flushes file system buffers to disk
    /// - Parameters:
    ///   - authData: Authorization data for privilege verification
    ///   - reply: Callback with the result of the operation
    func executeSync(authData: Data?, reply: @escaping (HelperCommandResult) -> Void)

    /// Execute only the purge command
    /// Purges inactive memory - requires /usr/bin/purge to exist
    /// - Parameters:
    ///   - authData: Authorization data for privilege verification
    ///   - reply: Callback with the result of the operation
    func executePurge(authData: Data?, reply: @escaping (HelperCommandResult) -> Void)

    /// Check if the purge command is available on this system
    /// - Parameter reply: Callback with true if /usr/bin/purge exists
    func isPurgeAvailable(reply: @escaping (Bool) -> Void)

    /// Verify the helper is running and responsive
    /// - Parameter reply: Callback with true if helper is alive
    func ping(reply: @escaping (Bool) -> Void)

    /// Force kill a process by PID using SIGKILL
    /// This method uses elevated privileges to terminate stubborn processes
    /// that cannot be killed through normal means (sandbox restrictions, system processes)
    /// - Parameters:
    ///   - pid: The process ID to force kill
    ///   - authData: Authorization data for privilege verification
    ///   - reply: Callback with the result of the operation
    func forceKillProcess(pid: Int32, authData: Data?, reply: @escaping (HelperCommandResult) -> Void)

    /// Force kill a process by name using killall -9
    /// This is useful when you know the process name but not the PID
    /// - Parameters:
    ///   - processName: The name of the process to force kill
    ///   - authData: Authorization data for privilege verification
    ///   - reply: Callback with the result of the operation
    func forceKillProcessByName(processName: String, authData: Data?, reply: @escaping (HelperCommandResult) -> Void)
}

// MARK: - App Protocol (Reverse Communication)

/// Protocol for the main app to receive callbacks from the helper
/// This enables the helper to report progress or status updates
@objc(AppXPCProtocol)
public protocol AppXPCProtocol {

    /// Report progress of an operation
    /// - Parameters:
    ///   - progress: Progress value from 0.0 to 1.0
    ///   - message: Description of current step
    func reportProgress(_ progress: Double, message: String)

    /// Log a message from the helper
    /// - Parameters:
    ///   - level: Log level (debug, info, warning, error)
    ///   - message: Log message
    func logMessage(level: String, message: String)
}

// MARK: - XPC Connection Helpers

/// Helper extension for creating XPC connections
public extension NSXPCConnection {

    /// Create a connection to the privileged helper service
    static func helperConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: kHelperToolMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)

        // Configure allowed classes for secure coding
        let resultClasses = NSSet(array: [
            HelperCommandResult.self,
            NSString.self,
            NSNumber.self,
            NSData.self
        ]) as! Set<AnyHashable>

        connection.remoteObjectInterface?.setClasses(
            resultClasses,
            for: #selector(HelperXPCProtocol.executeMemoryCleanup(authData:reply:)),
            argumentIndex: 1,
            ofReply: true
        )

        connection.remoteObjectInterface?.setClasses(
            resultClasses,
            for: #selector(HelperXPCProtocol.executeSync(authData:reply:)),
            argumentIndex: 1,
            ofReply: true
        )

        connection.remoteObjectInterface?.setClasses(
            resultClasses,
            for: #selector(HelperXPCProtocol.executePurge(authData:reply:)),
            argumentIndex: 1,
            ofReply: true
        )

        connection.remoteObjectInterface?.setClasses(
            resultClasses,
            for: #selector(HelperXPCProtocol.forceKillProcess(pid:authData:reply:)),
            argumentIndex: 2,
            ofReply: true
        )

        connection.remoteObjectInterface?.setClasses(
            resultClasses,
            for: #selector(HelperXPCProtocol.forceKillProcessByName(processName:authData:reply:)),
            argumentIndex: 2,
            ofReply: true
        )

        return connection
    }
}

// MARK: - Authorization Helpers

/// Authorization helper functions
public enum AuthorizationHelper {

    /// Create authorization data for XPC calls
    /// - Parameter rights: The authorization rights to request
    /// - Returns: Serialized authorization data, or nil if failed
    public static func createAuthorizationData(rights: [String]) -> Data? {
        var authRef: AuthorizationRef?

        let status = AuthorizationCreate(nil, nil, [], &authRef)
        guard status == errAuthorizationSuccess, let auth = authRef else {
            return nil
        }

        defer { AuthorizationFree(auth, []) }

        // Request the specified rights using a single right for simplicity
        // For multiple rights, we iterate and request each
        guard let firstRight = rights.first else {
            return nil
        }

        let requestStatus = firstRight.withCString { cString -> OSStatus in
            var item = AuthorizationItem(
                name: cString,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var authRights = AuthorizationRights(count: 1, items: itemPtr)
                let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
                return AuthorizationCopyRights(auth, &authRights, nil, flags, nil)
            }
        }

        guard requestStatus == errAuthorizationSuccess else {
            return nil
        }

        // Serialize the authorization
        var externalForm = AuthorizationExternalForm()
        let externalStatus = AuthorizationMakeExternalForm(auth, &externalForm)
        guard externalStatus == errAuthorizationSuccess else {
            return nil
        }

        return Data(bytes: &externalForm, count: MemoryLayout<AuthorizationExternalForm>.size)
    }

    /// Verify authorization data
    /// - Parameters:
    ///   - data: The serialized authorization data
    ///   - right: The right to verify
    /// - Returns: True if authorization is valid for the specified right
    public static func verifyAuthorization(data: Data?, right: String) -> Bool {
        guard let data = data, data.count == MemoryLayout<AuthorizationExternalForm>.size else {
            return false
        }

        var externalForm = AuthorizationExternalForm()
        _ = data.withUnsafeBytes { bytes in
            memcpy(&externalForm, bytes.baseAddress!, MemoryLayout<AuthorizationExternalForm>.size)
        }

        var authRef: AuthorizationRef?
        let status = AuthorizationCreateFromExternalForm(&externalForm, &authRef)
        guard status == errAuthorizationSuccess, let auth = authRef else {
            return false
        }

        defer { AuthorizationFree(auth, []) }

        let copyStatus = right.withCString { cString -> OSStatus in
            var item = AuthorizationItem(
                name: cString,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                let flags: AuthorizationFlags = [.extendRights]
                return AuthorizationCopyRights(auth, &rights, nil, flags, nil)
            }
        }

        return copyStatus == errAuthorizationSuccess
    }
}
