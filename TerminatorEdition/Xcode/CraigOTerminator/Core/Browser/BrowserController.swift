//
//  BrowserController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import AppKit
import os.log

// MARK: - Browser Error

/// Errors that can occur during browser operations
enum BrowserError: Error, LocalizedError {
    case browserNotInstalled(BrowserApp)
    case browserNotRunning(BrowserApp)
    case permissionDenied(BrowserApp)
    case scriptExecutionFailed(Error)
    case operationNotSupported(BrowserApp, operation: String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .browserNotInstalled(let browser):
            return "\(browser.rawValue) is not installed on this system."
        case .browserNotRunning(let browser):
            return "\(browser.rawValue) is not currently running."
        case .permissionDenied(let browser):
            return "Automation permission denied for \(browser.rawValue). Please grant permission in System Settings > Privacy & Security > Automation."
        case .scriptExecutionFailed(let error):
            return "Script execution failed: \(error.localizedDescription)"
        case .operationNotSupported(let browser, let operation):
            return "\(operation) is not supported for \(browser.rawValue)."
        case .invalidResponse(let message):
            return "Invalid response from browser: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .browserNotInstalled:
            return "Install the browser and try again."
        case .browserNotRunning:
            return "Launch the browser and try again."
        case .permissionDenied:
            return "Open System Settings and grant automation permission to Craig-O-Clean."
        case .scriptExecutionFailed:
            return "Try restarting the browser and try again."
        case .operationNotSupported:
            return "This operation is not available for this browser."
        case .invalidResponse:
            return "Try closing and reopening the browser."
        }
    }
}

// MARK: - Browser Controller Protocol

/// Protocol for all browser automation controllers
protocol BrowserController {
    /// The browser app this controller manages
    var app: BrowserApp { get }

    /// Check if browser is installed on the system
    func isInstalled() -> Bool

    /// Check if browser is currently running
    func isRunning() async -> Bool

    /// Get all open tabs across all windows
    func getAllTabs() async throws -> [BrowserTab]

    /// Close tabs matching URL pattern
    /// - Parameter pattern: URL substring to match (case-insensitive)
    /// - Returns: Number of tabs closed
    func closeTabs(matching pattern: String) async throws -> Int

    /// Close tab at specific index
    /// - Parameters:
    ///   - windowIndex: Index of the window (0-based)
    ///   - tabIndex: Index of the tab within the window (0-based)
    func closeTab(byIndex windowIndex: Int, tabIndex: Int) async throws

    /// Get count of open tabs
    func tabCount() async throws -> Int

    /// Get tabs that might be consuming excessive resources
    /// - Returns: Array of tabs that match heavy tab criteria
    func getHeavyTabs() async throws -> [BrowserTab]

    /// Close all tabs (optionally excluding whitelist)
    /// - Parameter except: Array of URL patterns to exclude from closing
    /// - Returns: Number of tabs closed
    func closeAllTabs(except whitelist: [String]) async throws -> Int

    /// Quit the browser application
    func quit() async throws

    /// Force quit the browser application
    func forceQuit() async throws
}

// MARK: - Default Implementations

extension BrowserController {
    /// Check if browser is installed
    func isInstalled() -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) != nil
    }

    /// Check if browser is running
    func isRunning() async -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        return runningApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    /// Close all tabs except whitelisted URLs
    func closeAllTabs(except whitelist: [String] = []) async throws -> Int {
        let tabs = try await getAllTabs()
        var closedCount = 0

        for tab in tabs {
            let shouldKeep = whitelist.contains { pattern in
                tab.url.localizedCaseInsensitiveContains(pattern)
            }

            if !shouldKeep {
                try await closeTab(byIndex: tab.windowIndex, tabIndex: tab.tabIndex)
                closedCount += 1
            }
        }

        return closedCount
    }

    /// Default implementation for heavy tabs (pattern-based heuristic)
    func getHeavyTabs() async throws -> [BrowserTab] {
        let tabs = try await getAllTabs()

        // Heavy tab patterns (streaming, video, complex web apps)
        let heavyPatterns = [
            "youtube.com",
            "twitch.tv",
            "netflix.com",
            "spotify.com",
            "figma.com",
            "notion.so",
            "slack.com",
            "discord.com",
            "meet.google.com",
            "zoom.us",
            "vimeo.com"
        ]

        return tabs.filter { tab in
            heavyPatterns.contains { pattern in
                tab.url.localizedCaseInsensitiveContains(pattern)
            }
        }
    }

    /// Force quit using killall
    func forceQuit() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-9", app.rawValue]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 && process.terminationStatus != 1 {
            throw BrowserError.scriptExecutionFailed(
                NSError(domain: "BrowserController", code: Int(process.terminationStatus))
            )
        }
    }
}

// MARK: - Helper Extensions

extension BrowserController {
    /// Execute AppleScript and return result
    func executeAppleScript(_ source: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = NSAppleScript(source: source)
                var error: NSDictionary?
                let output = script?.executeAndReturnError(&error)

                if let error = error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"

                    // Handle specific error codes
                    if code == -1743 {
                        continuation.resume(throwing: BrowserError.permissionDenied(self.app))
                    } else if code == -1728 || code == -1700 {
                        continuation.resume(throwing: BrowserError.browserNotRunning(self.app))
                    } else {
                        let nsError = NSError(domain: "AppleScriptError", code: code, userInfo: [
                            NSLocalizedDescriptionKey: message
                        ])
                        continuation.resume(throwing: BrowserError.scriptExecutionFailed(nsError))
                    }
                } else {
                    let result = output?.stringValue ?? ""
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Log browser operations
    func log(_ message: String, level: OSLogType = .default) {
        let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "Browser")
        logger.log(level: level, "\(self.app.rawValue): \(message)")
    }
}
