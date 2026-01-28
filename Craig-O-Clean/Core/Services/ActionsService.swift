// MARK: - ActionsService.swift
// Craig-O-Clean - Safe Actions Service
// Provides sandbox-safe process and application management actions

import Foundation
import AppKit
import Combine
import os.log

/// Service for executing safe actions using native APIs
@MainActor
final class ActionsService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var lastActionResult: ActionResult<Void>?
    @Published private(set) var isExecutingAction = false

    // MARK: - Dependencies

    private let auditLog: AuditLogService?
    private let permissions: PermissionManager?
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "Actions")

    // MARK: - Protected Process Names

    /// Processes that should never be terminated
    private static let protectedProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "loginwindow",
        "CoreServicesUIAgent"
    ]

    /// Processes that require confirmation before termination
    private static let sensitiveProcessNames: Set<String> = [
        "Finder",
        "Dock",
        "SystemUIServer",
        "ControlCenter",
        "NotificationCenter"
    ]

    // MARK: - Initialization

    init(auditLog: AuditLogService? = nil, permissions: PermissionManager? = nil) {
        self.auditLog = auditLog
        self.permissions = permissions
    }

    // MARK: - App Lifecycle Actions

    /// Quit an app gracefully via NSRunningApplication
    /// - Parameter app: The running application to quit
    /// - Returns: Result indicating success or failure
    func quitApp(_ app: NSRunningApplication) async -> ActionResult<Void> {
        let appName = app.localizedName ?? "Unknown App"

        guard !isProtectedProcess(app) else {
            logger.warning("Attempted to quit protected process: \(appName)")
            return .failure(.processProtected(name: appName))
        }

        logger.info("Quitting app: \(appName)")
        isExecutingAction = true
        defer { isExecutingAction = false }

        let startTime = Date()
        let success = app.terminate()

        let result: ActionResult<Void>
        if success {
            // Wait briefly for termination
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Check if actually terminated
            if app.isTerminated {
                result = .success((), duration: Date().timeIntervalSince(startTime))
                auditLog?.log(.appQuit, target: appName, metadata: ["bundleId": app.bundleIdentifier ?? "unknown"])
            } else {
                // App may be prompting to save
                result = .success((), duration: Date().timeIntervalSince(startTime), metadata: ["note": "App may be prompting to save"])
                auditLog?.log(.appQuit, target: appName, metadata: ["bundleId": app.bundleIdentifier ?? "unknown", "status": "pending"])
            }
        } else {
            result = .failure(.processTerminationFailed(name: appName, reason: "terminate() returned false"))
            auditLog?.logError(.appQuit, target: appName, errorMessage: "Failed to terminate")
        }

        lastActionResult = result
        return result
    }

    /// Force quit an app via NSRunningApplication
    /// - Parameter app: The running application to force quit
    /// - Returns: Result indicating success or failure
    func forceQuitApp(_ app: NSRunningApplication) async -> ActionResult<Void> {
        let appName = app.localizedName ?? "Unknown App"

        guard !isProtectedProcess(app) else {
            logger.warning("Attempted to force quit protected process: \(appName)")
            return .failure(.processProtected(name: appName))
        }

        logger.info("Force quitting app: \(appName)")
        isExecutingAction = true
        defer { isExecutingAction = false }

        let startTime = Date()
        let success = app.forceTerminate()

        let result: ActionResult<Void>
        if success {
            result = .success((), duration: Date().timeIntervalSince(startTime))
            auditLog?.log(.appForceQuit, target: appName, metadata: ["bundleId": app.bundleIdentifier ?? "unknown"])
        } else {
            result = .failure(.processTerminationFailed(name: appName, reason: "forceTerminate() returned false"))
            auditLog?.logError(.appForceQuit, target: appName, errorMessage: "Failed to force terminate")
        }

        lastActionResult = result
        return result
    }

    /// Quit an app via AppleScript (requires automation permission)
    /// - Parameter bundleId: The bundle identifier of the app to quit
    /// - Returns: Result indicating success or failure
    func quitAppViaScript(_ bundleId: String) async -> ActionResult<Void> {
        let appName = permissions?.appName(for: bundleId) ?? bundleId

        // Check automation permission
        if let permissions = permissions {
            let state = await permissions.checkAutomation(for: bundleId)
            if state != .granted {
                return .failure(.permissionDenied(.automation(bundleId: bundleId)))
            }
        }

        logger.info("Quitting app via AppleScript: \(appName)")
        isExecutingAction = true
        defer { isExecutingAction = false }

        let script = """
        tell application id "\(bundleId)"
            quit
        end tell
        """

        let startTime = Date()
        let scriptResult = await executeAppleScript(script)

        switch scriptResult {
        case .success:
            auditLog?.log(.appQuit, target: appName, metadata: ["bundleId": bundleId, "method": "appleScript"])
            return .success((), duration: Date().timeIntervalSince(startTime))

        case .permissionDenied:
            auditLog?.logError(.appQuit, target: appName, errorMessage: "Automation permission denied")
            return .failure(.appleScriptPermissionDenied(targetApp: appName))

        case .error(let code, let message):
            auditLog?.logError(.appQuit, target: appName, errorMessage: message)
            return .failure(.scriptExecutionFailed(errorCode: code, description: message))
        }
    }

    // MARK: - Process Termination (by PID)

    /// Terminate a process by PID using POSIX signals
    /// Only works for processes owned by the current user
    /// - Parameters:
    ///   - pid: The process ID
    ///   - name: The process name (for logging)
    ///   - force: Whether to use SIGKILL instead of SIGTERM
    /// - Returns: Result indicating success or failure
    func terminateProcess(pid: pid_t, name: String, force: Bool = false) async -> ActionResult<Void> {
        // Check for protected PIDs
        guard pid > 1 else {
            logger.warning("Attempted to terminate protected PID: \(pid)")
            return .failure(.processProtected(name: name))
        }

        // Check for protected process names
        if Self.protectedProcessNames.contains(name) {
            logger.warning("Attempted to terminate protected process: \(name)")
            return .failure(.processProtected(name: name))
        }

        logger.info("Terminating process \(name) (PID: \(pid), force: \(force))")
        isExecutingAction = true
        defer { isExecutingAction = false }

        let signal = force ? SIGKILL : SIGTERM
        let startTime = Date()
        let result = kill(pid, signal)

        if result == 0 {
            let action: AuditAction = force ? .appForceQuit : .appQuit
            auditLog?.log(action, target: name, metadata: ["pid": "\(pid)", "signal": force ? "SIGKILL" : "SIGTERM"])
            return .success((), duration: Date().timeIntervalSince(startTime))
        } else {
            let errorCode = errno
            let errorMessage: String
            switch errorCode {
            case EPERM:
                errorMessage = "Permission denied - process not owned by current user"
            case ESRCH:
                errorMessage = "Process not found"
            default:
                errorMessage = "Error \(errorCode)"
            }

            auditLog?.logError(force ? .appForceQuit : .appQuit, target: name, errorMessage: errorMessage)
            return .failure(.processTerminationFailed(name: name, reason: errorMessage))
        }
    }

    // MARK: - System Actions

    /// Open Activity Monitor
    func openActivityMonitor() {
        logger.info("Opening Activity Monitor")
        let activityMonitorPath = "/System/Applications/Utilities/Activity Monitor.app"
        NSWorkspace.shared.open(URL(fileURLWithPath: activityMonitorPath))
        auditLog?.log(.appLaunched, target: "Activity Monitor")
    }

    /// Open Force Quit dialog (Cmd+Opt+Esc)
    func showForceQuitDialog() async {
        logger.info("Showing Force Quit dialog")

        // Try via System Events (requires automation permission)
        if let permissions = permissions {
            let state = await permissions.checkAutomation(for: "com.apple.systemevents")
            if state == .granted {
                let script = """
                tell application "System Events"
                    key code 53 using {command down, option down}
                end tell
                """
                _ = await executeAppleScript(script)
                return
            }
        }

        // Fallback: Just log that we can't do it
        logger.info("Cannot show Force Quit dialog - System Events automation not permitted")
    }

    /// Get instructions for terminal command (for features unavailable in MAS)
    func getTerminalInstructions(for feature: String) -> TerminalInstructions? {
        Self.terminalInstructions[feature]
    }

    // MARK: - Utility Actions

    /// Check if a process is running
    func isAppRunning(bundleId: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
    }

    /// Get all running applications
    func getRunningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            // Filter out background-only apps and system processes
            app.activationPolicy == .regular ||
            (app.activationPolicy == .accessory && app.localizedName != nil)
        }
    }

    /// Get running application by bundle ID
    func getRunningApp(bundleId: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
    }

    /// Activate (bring to front) an application
    func activateApp(_ app: NSRunningApplication) -> Bool {
        app.activate(options: [.activateIgnoringOtherApps])
    }

    /// Hide an application
    func hideApp(_ app: NSRunningApplication) -> Bool {
        app.hide()
    }

    // MARK: - Protection Checks

    /// Check if a process is protected from termination
    func isProtectedProcess(_ app: NSRunningApplication) -> Bool {
        if let name = app.localizedName, Self.protectedProcessNames.contains(name) {
            return true
        }
        return false
    }

    /// Check if a process requires confirmation before termination
    func isSensitiveProcess(_ app: NSRunningApplication) -> Bool {
        if let name = app.localizedName, Self.sensitiveProcessNames.contains(name) {
            return true
        }
        return false
    }

    /// Check if a process name is protected
    func isProtectedProcessName(_ name: String) -> Bool {
        Self.protectedProcessNames.contains(name)
    }

    // MARK: - Private Helpers

    private enum ScriptResult {
        case success
        case permissionDenied
        case error(code: Int, message: String)
    }

    private func executeAppleScript(_ source: String) async -> ScriptResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: .error(code: -1, message: "Failed to create script"))
                    return
                }

                var error: NSDictionary?
                script.executeAndReturnError(&error)

                if let error = error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"

                    if code == -1743 || code == -10004 {
                        continuation.resume(returning: .permissionDenied)
                    } else {
                        continuation.resume(returning: .error(code: code, message: message))
                    }
                    return
                }

                continuation.resume(returning: .success)
            }
        }
    }

    // MARK: - Terminal Instructions

    private static let terminalInstructions: [String: TerminalInstructions] = [
        "memory_purge": TerminalInstructions(
            title: "Purge Inactive Memory",
            description: "This feature requires administrator privileges and is not available in the App Store version.",
            command: "sudo purge",
            explanation: "The purge command releases inactive memory back to the system. macOS normally manages this automatically.",
            warning: "You will be prompted for your administrator password."
        ),
        "dns_flush": TerminalInstructions(
            title: "Flush DNS Cache",
            description: "Clear your DNS cache to resolve network issues.",
            command: "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder",
            explanation: "This clears cached DNS records, which can help resolve domain name issues.",
            warning: "You will be prompted for your administrator password."
        ),
        "restart_dock": TerminalInstructions(
            title: "Restart Dock",
            description: "Restart the Dock to fix icon or animation issues.",
            command: "killall Dock",
            explanation: "The Dock will automatically restart after being terminated.",
            warning: nil
        ),
        "restart_menubar": TerminalInstructions(
            title: "Restart Menu Bar",
            description: "Restart SystemUIServer to fix menu bar glitches.",
            command: "killall SystemUIServer",
            explanation: "The menu bar will automatically restart after being terminated.",
            warning: nil
        ),
        "restart_finder": TerminalInstructions(
            title: "Restart Finder",
            description: "Restart Finder to fix display or navigation issues.",
            command: "killall Finder",
            explanation: "Finder will automatically restart after being terminated.",
            warning: nil
        )
    ]
}

// MARK: - Terminal Instructions Model

struct TerminalInstructions {
    let title: String
    let description: String
    let command: String
    let explanation: String
    let warning: String?

    var formattedCommand: String {
        "```\n\(command)\n```"
    }
}

// MARK: - App Info Extension

extension NSRunningApplication {
    /// Convenience property for display name
    var displayName: String {
        localizedName ?? bundleIdentifier ?? "Unknown"
    }

    /// Check if this is a regular user application
    var isUserApplication: Bool {
        activationPolicy == .regular
    }

    /// Check if this is an accessory app (menu bar app)
    var isAccessoryApplication: Bool {
        activationPolicy == .accessory
    }
}
