//
//  HelperProtocol.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

/// XPC protocol for communication between the sandboxed app and the privileged helper
/// This protocol defines the interface for executing commands with elevated privileges
@objc protocol HelperProtocol {

    /// Execute a command with elevated privileges
    /// - Parameters:
    ///   - command: The full path to the command to execute
    ///   - arguments: Array of command-line arguments
    ///   - workingDirectory: Optional working directory path
    ///   - authData: Authorization data in external form
    ///   - reply: Completion handler with exit code, stdout, stderr, and optional error
    func executeCommand(
        _ command: String,
        arguments: [String],
        workingDirectory: String?,
        authData: Data?,
        reply: @escaping (Int32, String, String, Error?) -> Void
    )

    /// Get the helper tool version
    /// - Parameter reply: Completion handler with version string
    func getVersion(reply: @escaping (String) -> Void)

    /// Verify the helper tool is responsive
    /// - Parameter reply: Completion handler with status message
    func ping(reply: @escaping (String) -> Void)
}

/// Helper status information
enum HelperStatus: Equatable {
    case notInstalled
    case installed(version: String)
    case outdated(current: String, required: String)
    case unknown

    var isInstalled: Bool {
        switch self {
        case .installed, .outdated:
            return true
        default:
            return false
        }
    }

    var needsUpdate: Bool {
        if case .outdated = self {
            return true
        }
        return false
    }

    var displayText: String {
        switch self {
        case .notInstalled:
            return "Not Installed"
        case .installed(let version):
            return "Installed (v\(version))"
        case .outdated(let current, let required):
            return "Outdated (v\(current), requires v\(required))"
        case .unknown:
            return "Unknown"
        }
    }
}

/// Errors related to the privileged helper
enum HelperError: LocalizedError {
    case notInstalled
    case outdated(current: String, required: String)
    case connectionFailed(Error)
    case authorizationDenied
    case installationFailed(Error)
    case commandNotAllowed(String)
    case executionFailed(String)
    case invalidResponse
    case helperNotResponding
    case invalidAuthData
    case commandNotFound(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Privileged helper is not installed. Please install it to execute elevated commands."

        case .outdated(let current, let required):
            return "Privileged helper is outdated (current: v\(current), required: v\(required)). Please update it."

        case .connectionFailed(let error):
            return "Failed to connect to privileged helper: \(error.localizedDescription)"

        case .authorizationDenied:
            return "Authorization denied. Administrator privileges are required for this operation."

        case .installationFailed(let error):
            return "Failed to install privileged helper: \(error.localizedDescription)"

        case .commandNotAllowed(let command):
            return "Command not allowed by helper: \(command). Only pre-approved commands can be executed."

        case .executionFailed(let message):
            return "Command execution failed: \(message)"

        case .invalidResponse:
            return "Invalid response from privileged helper."

        case .helperNotResponding:
            return "Privileged helper is not responding. Try reinstalling it."

        case .invalidAuthData:
            return "Invalid authorization data. Please try again."

        case .commandNotFound(let command):
            return "Command not found: \(command)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notInstalled, .outdated:
            return "Click the 'Install Helper' button to install or update the privileged helper."

        case .connectionFailed, .helperNotResponding:
            return "Try reinstalling the privileged helper. If the problem persists, restart your Mac."

        case .authorizationDenied:
            return "Enter your administrator password when prompted."

        case .commandNotAllowed:
            return "This operation requires a different privilege level."

        default:
            return nil
        }
    }
}

/// Helper configuration constants
enum HelperConstants {
    /// Helper bundle identifier
    static let bundleID = "ai.neuralquantum.CraigOTerminator.helper"

    /// Current helper version
    static let currentVersion = "1.0.0"

    /// Mach service name (must match launchd.plist)
    static let machServiceName = "ai.neuralquantum.CraigOTerminator.helper"

    /// Authorization right name
    static let authorizationRight = "ai.neuralquantum.CraigOTerminator.bless"

    /// Maximum command execution timeout (seconds)
    static let maxTimeout: TimeInterval = 300 // 5 minutes

    /// XPC connection timeout (seconds)
    static let connectionTimeout: TimeInterval = 10
}
