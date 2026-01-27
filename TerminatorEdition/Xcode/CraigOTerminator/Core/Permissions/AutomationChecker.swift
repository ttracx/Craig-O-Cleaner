//
//  AutomationChecker.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import AppKit
import os.log

/// Specialized checker for browser automation permissions
final class AutomationChecker {

    private static let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "AutomationChecker")

    // MARK: - Permission Checking

    /// Check if we have automation permission for browser
    static func checkPermission(for browser: BrowserApp) async -> PermissionState {
        logger.debug("Checking automation permission for \(browser.rawValue)")

        // Check if browser is installed first
        guard isInstalled(browser) else {
            logger.debug("\(browser.rawValue) not installed")
            return .notDetermined
        }

        // Try to send a no-op AppleScript command
        let script = createTestScript(for: browser)

        do {
            try await executeAppleScript(script)
            logger.debug("Permission granted for \(browser.rawValue)")
            return .granted
        } catch let error as NSError {
            // Error -1743 = permission denied
            if error.code == -1743 {
                logger.warning("Permission denied for \(browser.rawValue)")
                return .denied
            }
            // Error -1728 = app not running (but permission might be granted)
            // Error -1700 = app not open yet
            if error.code == -1728 || error.code == -1700 {
                logger.debug("\(browser.rawValue) not running - permission unknown")
                return .notDetermined
            }
            logger.warning("Error checking \(browser.rawValue): code=\(error.code), message=\(error.localizedDescription)")
            return .unknown
        }
    }

    /// Request permission (triggers system dialog)
    static func requestPermission(for browser: BrowserApp) async -> PermissionState {
        logger.info("Requesting automation permission for \(browser.rawValue)")

        // Check if browser is installed
        guard isInstalled(browser) else {
            logger.warning("Cannot request permission - \(browser.rawValue) not installed")
            return .notDetermined
        }

        // Launch browser if not running
        do {
            try await launchBrowser(browser)
        } catch {
            logger.error("Failed to launch \(browser.rawValue): \(error.localizedDescription)")
        }

        // Try to interact with it (this will trigger permission dialog if needed)
        let script = createRequestScript(for: browser)

        do {
            try await executeAppleScript(script)
            logger.info("Permission granted for \(browser.rawValue)")
            return .granted
        } catch let error as NSError {
            if error.code == -1743 {
                logger.warning("Permission denied by user for \(browser.rawValue)")
                return .denied
            }
            logger.warning("Error requesting permission for \(browser.rawValue): \(error.localizedDescription)")
            return .notDetermined
        }
    }

    // MARK: - Script Generation

    private static func createTestScript(for browser: BrowserApp) -> String {
        // Minimal AppleScript that tests permission without side effects
        switch browser {
        case .safari, .chrome, .edge, .brave, .arc:
            return """
            tell application "\(browser.rawValue)"
                try
                    get name
                on error errMsg number errNum
                    error errMsg number errNum
                end try
            end tell
            """

        case .firefox:
            // Firefox has limited AppleScript support
            return """
            tell application "\(browser.rawValue)"
                try
                    activate
                    get name
                on error errMsg number errNum
                    error errMsg number errNum
                end try
            end tell
            """
        }
    }

    private static func createRequestScript(for browser: BrowserApp) -> String {
        // Script that triggers permission dialog if not granted
        switch browser {
        case .safari:
            return """
            tell application "\(browser.rawValue)"
                try
                    activate
                    tell window 1
                        get current tab
                    end tell
                on error errMsg number errNum
                    error errMsg number errNum
                end try
            end tell
            """

        case .chrome, .edge, .brave:
            return """
            tell application "\(browser.rawValue)"
                try
                    activate
                    tell window 1
                        get active tab
                    end tell
                on error errMsg number errNum
                    error errMsg number errNum
                end try
            end tell
            """

        case .arc:
            return """
            tell application "\(browser.rawValue)"
                try
                    activate
                    get name
                on error errMsg number errNum
                    error errMsg number errNum
                end try
            end tell
            """

        case .firefox:
            return """
            tell application "\(browser.rawValue)"
                try
                    activate
                    get name
                on error errMsg number errNum
                    error errMsg number errNum
                end try
            end tell
            """
        }
    }

    // MARK: - Helpers

    private static func isInstalled(_ browser: BrowserApp) -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
    }

    private static func launchBrowser(_ browser: BrowserApp) async throws {
        let workspace = NSWorkspace.shared

        guard let appURL = workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) else {
            throw NSError(domain: "AutomationChecker", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Browser not installed: \(browser.rawValue)"
            ])
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false  // Don't bring to front
        configuration.promptsUserIfNeeded = false

        _ = try await workspace.openApplication(at: appURL, configuration: configuration)

        // Give it a moment to launch
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
    }

    private static func executeAppleScript(_ source: String) async throws {
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

    // MARK: - System Settings

    /// Generate System Settings URL for automation permission
    static func systemSettingsURL(for browser: BrowserApp) -> URL? {
        // Deep link to Automation privacy pane
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    /// Open System Settings to automation permission pane
    static func openSystemSettings(for browser: BrowserApp) {
        if let url = systemSettingsURL(for: browser) {
            NSWorkspace.shared.open(url)
            logger.info("Opened System Settings for \(browser.rawValue) automation permission")
        }
    }
}
