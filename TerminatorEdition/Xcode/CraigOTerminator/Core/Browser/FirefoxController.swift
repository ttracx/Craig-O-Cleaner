//
//  FirefoxController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

// MARK: - Firefox Controller

/// Controller for Firefox browser automation
/// Note: Firefox has limited AppleScript support. Only quit operations are reliably supported.
final class FirefoxController: BrowserController {
    let app: BrowserApp = .firefox

    init() {}

    // MARK: - Limited Support

    func getAllTabs() async throws -> [BrowserTab] {
        throw BrowserError.operationNotSupported(app, operation: "Tab listing")
    }

    func closeTabs(matching pattern: String) async throws -> Int {
        throw BrowserError.operationNotSupported(app, operation: "Tab closing by pattern")
    }

    func closeTab(byIndex windowIndex: Int, tabIndex: Int) async throws {
        throw BrowserError.operationNotSupported(app, operation: "Tab closing by index")
    }

    func tabCount() async throws -> Int {
        // Firefox doesn't support tab counting via AppleScript
        // Return 0 to indicate unknown without throwing error
        return 0
    }

    func getHeavyTabs() async throws -> [BrowserTab] {
        throw BrowserError.operationNotSupported(app, operation: "Heavy tab detection")
    }

    // MARK: - Supported Operations

    func quit() async throws {
        guard isInstalled() else {
            throw BrowserError.browserNotInstalled(app)
        }

        let script = """
        tell application "Firefox"
            quit
        end tell
        """

        do {
            _ = try await executeAppleScript(script)
        } catch let error as BrowserError {
            // Ignore "not running" errors when quitting
            if case .browserNotRunning = error {
                return
            }
            throw error
        } catch {
            throw BrowserError.scriptExecutionFailed(error)
        }
    }
}
