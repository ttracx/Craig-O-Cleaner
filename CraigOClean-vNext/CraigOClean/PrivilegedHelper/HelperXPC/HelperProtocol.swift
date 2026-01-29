// File: CraigOClean-vNext/CraigOClean/PrivilegedHelper/HelperXPC/HelperProtocol.swift
// Craig-O-Clean - Privileged Helper Protocol
// XPC protocol for communication with the privileged helper

import Foundation

/// Protocol for XPC communication with the privileged helper tool.
/// The helper runs with elevated privileges and can perform operations
/// that the main app cannot do in sandbox mode.
@objc public protocol HelperProtocol {

    // MARK: - Version & Status

    /// Returns the helper version string
    /// - Parameter reply: Callback with version string
    func getVersion(reply: @escaping (String) -> Void)

    /// Checks if the helper is ready to accept commands
    /// - Parameter reply: Callback with readiness status
    func isReady(reply: @escaping (Bool) -> Void)

    // MARK: - File Operations

    /// Deletes files at the specified paths
    /// - Parameters:
    ///   - paths: Array of file paths to delete
    ///   - reply: Callback with success status and error message if any
    func deleteFiles(
        atPaths paths: [String],
        reply: @escaping (Bool, String?) -> Void
    )

    /// Calculates the size of a directory
    /// - Parameters:
    ///   - path: Directory path
    ///   - reply: Callback with size in bytes
    func calculateDirectorySize(
        atPath path: String,
        reply: @escaping (UInt64) -> Void
    )

    /// Lists contents of a directory with file sizes
    /// - Parameters:
    ///   - path: Directory path
    ///   - reply: Callback with array of (path, size) tuples encoded as Data
    func listDirectory(
        atPath path: String,
        reply: @escaping (Data?) -> Void
    )

    // MARK: - System Operations

    /// Clears system caches that require elevated privileges
    /// - Parameter reply: Callback with bytes freed and error message if any
    func clearSystemCaches(
        reply: @escaping (UInt64, String?) -> Void
    )

    /// Clears DNS cache
    /// - Parameter reply: Callback with success status
    func flushDNSCache(reply: @escaping (Bool) -> Void)

    // MARK: - Uninstall

    /// Removes the helper from the system
    /// - Parameter reply: Callback with success status
    func uninstallHelper(reply: @escaping (Bool) -> Void)
}

// MARK: - Helper Constants

public enum HelperConstants {
    public static let machServiceName = "com.craigosoft.CraigOClean.Helper"
    public static let helperToolLocation = "/Library/PrivilegedHelperTools/\(machServiceName)"
    public static let launchdPlistLocation = "/Library/LaunchDaemons/\(machServiceName).plist"
    public static let currentVersion = "1.0.0"
}

// MARK: - Helper Error

public enum HelperError: Error, LocalizedError {
    case connectionFailed
    case notInstalled
    case operationFailed(reason: String)
    case permissionDenied
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to privileged helper"
        case .notInstalled:
            return "Privileged helper is not installed"
        case .operationFailed(let reason):
            return "Helper operation failed: \(reason)"
        case .permissionDenied:
            return "Permission denied by helper"
        case .invalidResponse:
            return "Invalid response from helper"
        }
    }
}
