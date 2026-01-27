//
//  ChromiumController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import AppKit

// MARK: - Chromium Base Controller

/// Base controller for Chromium-based browsers (Chrome, Edge, Brave, Arc)
/// Provides shared implementation for common Chromium AppleScript API
class ChromiumController: BrowserController {
    let app: BrowserApp

    init(app: BrowserApp) {
        self.app = app
    }

    // MARK: - Tab Operations

    func getAllTabs() async throws -> [BrowserTab] {
        guard isInstalled() else {
            throw BrowserError.browserNotInstalled(app)
        }

        guard await isRunning() else {
            throw BrowserError.browserNotRunning(app)
        }

        let script = """
        tell application "\(app.rawValue)"
            set tabList to {}
            set winIndex to 0
            repeat with w in windows
                set tabIndex to 0
                repeat with t in tabs of w
                    set tabInfo to {URL of t, title of t, winIndex, tabIndex}
                    set end of tabList to tabInfo
                    set tabIndex to tabIndex + 1
                end repeat
                set winIndex to winIndex + 1
            end repeat
            return tabList
        end tell
        """

        do {
            let result = try await executeAppleScript(script)
            return try parseChromiumTabs(result)
        } catch let error as BrowserError {
            throw error
        } catch {
            throw BrowserError.scriptExecutionFailed(error)
        }
    }

    func closeTabs(matching pattern: String) async throws -> Int {
        guard isInstalled() else {
            throw BrowserError.browserNotInstalled(app)
        }

        guard await isRunning() else {
            throw BrowserError.browserNotRunning(app)
        }

        let escapedPattern = pattern.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "\(app.rawValue)"
            set closedCount to 0
            repeat with w in windows
                set tabList to (tabs of w)
                repeat with t in tabList
                    try
                        if URL of t contains "\(escapedPattern)" then
                            close t
                            set closedCount to closedCount + 1
                        end if
                    end try
                end repeat
            end repeat
            return closedCount
        end tell
        """

        do {
            let result = try await executeAppleScript(script)
            return Int(result) ?? 0
        } catch let error as BrowserError {
            throw error
        } catch {
            throw BrowserError.scriptExecutionFailed(error)
        }
    }

    func closeTab(byIndex windowIndex: Int, tabIndex: Int) async throws {
        guard isInstalled() else {
            throw BrowserError.browserNotInstalled(app)
        }

        guard await isRunning() else {
            throw BrowserError.browserNotRunning(app)
        }

        // AppleScript uses 1-based indexing
        let winIdx = windowIndex + 1
        let tabIdx = tabIndex + 1

        let script = """
        tell application "\(app.rawValue)"
            try
                close tab \(tabIdx) of window \(winIdx)
            on error errMsg
                error errMsg
            end try
        end tell
        """

        do {
            _ = try await executeAppleScript(script)
        } catch let error as BrowserError {
            throw error
        } catch {
            throw BrowserError.scriptExecutionFailed(error)
        }
    }

    func tabCount() async throws -> Int {
        guard isInstalled() else {
            throw BrowserError.browserNotInstalled(app)
        }

        guard await isRunning() else {
            return 0 // Return 0 if not running instead of error
        }

        let script = """
        tell application "\(app.rawValue)"
            set tabCount to 0
            repeat with w in windows
                set tabCount to tabCount + (count of tabs of w)
            end repeat
            return tabCount
        end tell
        """

        do {
            let result = try await executeAppleScript(script)
            return Int(result) ?? 0
        } catch let error as BrowserError {
            if case .browserNotRunning = error {
                return 0
            }
            throw error
        } catch {
            throw BrowserError.scriptExecutionFailed(error)
        }
    }

    func quit() async throws {
        guard isInstalled() else {
            throw BrowserError.browserNotInstalled(app)
        }

        let script = """
        tell application "\(app.rawValue)"
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

    // MARK: - Heavy Tabs

    func getHeavyTabs() async throws -> [BrowserTab] {
        // Chromium browsers don't expose memory usage via AppleScript
        // Fall back to pattern-based detection
        let allTabs = try await getAllTabs()

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

        return allTabs.filter { tab in
            heavyPatterns.contains { pattern in
                tab.url.localizedCaseInsensitiveContains(pattern)
            }
        }
    }

    // MARK: - Private Helpers

    private func parseChromiumTabs(_ result: String) throws -> [BrowserTab] {
        // Chromium returns format: URL, title, windowIndex, tabIndex
        // Example: "https://example.com, Example, 0, 0, https://google.com, Google, 0, 1"

        var tabs: [BrowserTab] = []

        // Clean up the result string
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Split by comma, handling quoted strings
        var components: [String] = []
        var current = ""
        var inQuote = false

        for char in cleaned {
            if char == "\"" {
                inQuote.toggle()
            } else if char == "," && !inQuote {
                components.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            components.append(current.trimmingCharacters(in: .whitespaces))
        }

        // Group into sets of 4 (url, title, windowIndex, tabIndex)
        var i = 0
        while i + 3 < components.count {
            let url = components[i]
            let title = components[i + 1]
            let windowIndex = Int(components[i + 2]) ?? 0
            let tabIndex = Int(components[i + 3]) ?? 0

            let tab = BrowserTab(
                url: url,
                title: title,
                windowIndex: windowIndex,
                tabIndex: tabIndex
            )
            tabs.append(tab)

            i += 4
        }

        return tabs
    }
}
