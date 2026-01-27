//
//  PermissionCenter.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI
import AppKit
import os.log

// MARK: - Permission State

/// State of a macOS permission
enum PermissionState: String, Codable {
    case unknown        // Haven't checked yet
    case notDetermined  // macOS hasn't asked yet
    case granted        // User approved
    case denied         // User denied
}

// MARK: - Browser App

/// Supported browsers for automation
enum BrowserApp: String, CaseIterable, Codable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case brave = "Brave Browser"
    case firefox = "Firefox"
    case arc = "Arc"

    var bundleIdentifier: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .firefox: return "org.mozilla.firefox"
        case .arc: return "company.thebrowser.Browser"
        }
    }

    var icon: String {
        switch self {
        case .safari: return "safari"
        case .chrome: return "globe"
        case .edge: return "globe"
        case .brave: return "shield"
        case .firefox: return "flame"
        case .arc: return "globe"
        }
    }
}

// MARK: - Permission Type

/// Type of permission required
enum PermissionType: Hashable {
    case automation(BrowserApp)
    case fullDiskAccess
    case helper

    var displayName: String {
        switch self {
        case .automation(let browser):
            return "\(browser.rawValue) Automation"
        case .fullDiskAccess:
            return "Full Disk Access"
        case .helper:
            return "Privileged Helper"
        }
    }

    var icon: String {
        switch self {
        case .automation:
            return "applescript"
        case .fullDiskAccess:
            return "internaldrive"
        case .helper:
            return "shield.checkered"
        }
    }
}

// MARK: - Remediation Step

/// Step-by-step remediation instruction
struct RemediationStep {
    let instruction: String
    let systemSettingsPath: String?  // e.g., "Privacy & Security > Automation"
    let canOpenAutomatically: Bool
}

// MARK: - Permission Center

/// Central manager for all macOS permissions required by Craig-O-Clean
@Observable
final class PermissionCenter {

    // MARK: - State

    /// Per-browser automation permission status
    var automationPermissions: [BrowserApp: PermissionState] = [:]

    /// Full disk access permission status
    var fullDiskAccess: PermissionState = .unknown

    /// Whether privileged helper is installed
    var helperInstalled: Bool = false

    /// Last check timestamp
    var lastCheckDate: Date?

    // MARK: - Singleton

    static let shared = PermissionCenter()

    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "PermissionCenter")

    private init() {
        Task {
            await refreshAll()
        }
    }

    // MARK: - Permission Checking

    /// Check automation permission for specific browser
    func checkAutomationPermission(for app: BrowserApp) async -> PermissionState {
        logger.debug("Checking automation permission for \(app.rawValue)")

        // Check if browser is installed first
        guard isBrowserInstalled(app) else {
            logger.debug("\(app.rawValue) is not installed")
            return .notDetermined
        }

        // Use AppleScript to test permission
        let script = """
        tell application "\(app.rawValue)"
            try
                get name
            on error errMsg number errNum
                error errMsg number errNum
            end try
        end tell
        """

        do {
            try await executeAppleScript(script)
            logger.debug("Automation permission granted for \(app.rawValue)")
            return .granted
        } catch let error as NSError {
            // Error -1743 = permission denied
            if error.code == -1743 {
                logger.warning("Automation permission denied for \(app.rawValue)")
                return .denied
            }
            // Error -1728 = app not running (but permission might be granted)
            // Error -1700 = app not open yet
            if error.code == -1728 || error.code == -1700 {
                logger.debug("Cannot determine permission for \(app.rawValue) - app not running")
                return .notDetermined
            }
            logger.warning("Unknown error checking \(app.rawValue) automation: \(error.localizedDescription)")
            return .unknown
        }
    }

    /// Request automation permission (triggers system prompt)
    func requestAutomationPermission(for app: BrowserApp) async -> PermissionState {
        logger.info("Requesting automation permission for \(app.rawValue)")

        // Launch the browser if not running to trigger permission dialog
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false  // Don't bring to front

            do {
                _ = try await workspace.openApplication(at: appURL, configuration: configuration)
                // Give it a moment to launch
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            } catch {
                logger.error("Failed to launch \(app.rawValue): \(error.localizedDescription)")
            }
        }

        // Now try to interact with it (this will trigger permission dialog)
        let script = """
        tell application "\(app.rawValue)"
            try
                activate
                get name
            on error errMsg number errNum
                error errMsg number errNum
            end try
        end tell
        """

        do {
            try await executeAppleScript(script)
            return .granted
        } catch let error as NSError {
            if error.code == -1743 {
                return .denied
            }
            return .notDetermined
        }
    }

    /// Check full disk access
    func checkFullDiskAccess() async -> PermissionState {
        logger.debug("Checking full disk access")

        // Try to read protected files
        let protectedPaths = [
            NSHomeDirectory() + "/Library/Safari/History.db",
            NSHomeDirectory() + "/Library/Safari/CloudTabs.db",
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/History"
        ]

        for path in protectedPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                logger.debug("Full disk access granted (can read: \(path))")
                return .granted
            }
        }

        logger.warning("Full disk access denied - cannot read protected files")
        return .denied
    }

    /// Check if privileged helper is installed
    func checkHelperInstalled() async -> Bool {
        logger.debug("Checking privileged helper installation")

        // Try to connect to helper via XPC
        // For now, we'll check if the helper binary exists
        let helperPath = "/Library/PrivilegedHelperTools/com.neuralquantum.craigoclean.helper"
        let exists = FileManager.default.fileExists(atPath: helperPath)

        logger.debug("Privileged helper \(exists ? "installed" : "not installed")")
        return exists
    }

    /// Refresh all permissions
    func refreshAll() async {
        logger.info("Refreshing all permissions")

        await withTaskGroup(of: Void.self) { group in
            // Check all browser permissions in parallel
            for browser in BrowserApp.allCases {
                group.addTask {
                    let state = await self.checkAutomationPermission(for: browser)
                    await MainActor.run {
                        self.automationPermissions[browser] = state
                    }
                }
            }

            // Check full disk access
            group.addTask {
                let state = await self.checkFullDiskAccess()
                await MainActor.run {
                    self.fullDiskAccess = state
                }
            }

            // Check helper
            group.addTask {
                let installed = await self.checkHelperInstalled()
                await MainActor.run {
                    self.helperInstalled = installed
                }
            }
        }

        await MainActor.run {
            self.lastCheckDate = Date()
        }

        logger.info("Permission refresh complete")
    }

    // MARK: - Remediation

    /// Get remediation steps for denied permission
    func remediationSteps(for permission: PermissionType) -> [RemediationStep] {
        switch permission {
        case .automation(let browser):
            return [
                RemediationStep(
                    instruction: "Open System Settings",
                    systemSettingsPath: nil,
                    canOpenAutomatically: true
                ),
                RemediationStep(
                    instruction: "Navigate to Privacy & Security",
                    systemSettingsPath: "Privacy & Security",
                    canOpenAutomatically: true
                ),
                RemediationStep(
                    instruction: "Scroll down and click on 'Automation'",
                    systemSettingsPath: "Privacy & Security > Automation",
                    canOpenAutomatically: true
                ),
                RemediationStep(
                    instruction: "Find Craig-O-Clean in the list",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Enable the checkbox next to '\(browser.rawValue)'",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Return to Craig-O-Clean and try again",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                )
            ]

        case .fullDiskAccess:
            return [
                RemediationStep(
                    instruction: "Open System Settings",
                    systemSettingsPath: nil,
                    canOpenAutomatically: true
                ),
                RemediationStep(
                    instruction: "Navigate to Privacy & Security",
                    systemSettingsPath: "Privacy & Security",
                    canOpenAutomatically: true
                ),
                RemediationStep(
                    instruction: "Scroll down and click on 'Full Disk Access'",
                    systemSettingsPath: "Privacy & Security > Full Disk Access",
                    canOpenAutomatically: true
                ),
                RemediationStep(
                    instruction: "Click the lock icon and authenticate with your password",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Click the '+' button and add Craig-O-Clean",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Enable the checkbox next to Craig-O-Clean",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Restart Craig-O-Clean for changes to take effect",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                )
            ]

        case .helper:
            return [
                RemediationStep(
                    instruction: "Click 'Install Helper' in Craig-O-Clean settings",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Enter your administrator password when prompted",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                ),
                RemediationStep(
                    instruction: "Wait for installation to complete",
                    systemSettingsPath: nil,
                    canOpenAutomatically: false
                )
            ]
        }
    }

    /// Open System Settings to relevant permission pane
    func openSystemSettings(for permission: PermissionType) {
        let urlString: String

        switch permission {
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .helper:
            // No specific settings pane for helper installation
            logger.warning("No system settings pane for helper installation")
            return
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            logger.info("Opened System Settings for \(permission.displayName)")
        } else {
            logger.error("Invalid System Settings URL: \(urlString)")
        }
    }

    // MARK: - Helpers

    private func isBrowserInstalled(_ browser: BrowserApp) -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
    }

    private func executeAppleScript(_ source: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = NSAppleScript(source: source)
                var error: NSDictionary?
                script?.executeAndReturnError(&error)

                if let error = error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    let nsError = NSError(domain: "AppleScriptError", code: code, userInfo: [
                        NSLocalizedDescriptionKey: message
                    ])
                    continuation.resume(throwing: nsError)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
