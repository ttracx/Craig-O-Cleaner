// MARK: - BrowserController.swift
// Craig-O-Clean - Browser Controller Protocol & Implementations
// Provides unified interface for browser tab management across Safari, Chrome, etc.

import Foundation
import AppKit
import os.log

// MARK: - Browser Tab Model

struct BrowserTab: Identifiable, Hashable {
    let id: String
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let browserApp: String

    init(windowIndex: Int, tabIndex: Int, title: String, url: String, browserApp: String = "") {
        self.id = "\(browserApp)-\(windowIndex)-\(tabIndex)"
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.title = title
        self.url = url
        self.browserApp = browserApp
    }

    /// Heuristic: tabs from known heavy sites are flagged
    var isEstimatedHeavy: Bool {
        let heavyPatterns = ["youtube.com", "facebook.com", "twitter.com", "twitch.tv",
                            "netflix.com", "reddit.com", "instagram.com", "tiktok.com"]
        return heavyPatterns.contains { url.localizedCaseInsensitiveContains($0) }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool { lhs.id == rhs.id }
}

// MARK: - Browser Controller Protocol

protocol BrowserController {
    var browserName: String { get }
    var bundleIdentifier: String { get }

    func isRunning() -> Bool
    func isAutomationPermissionGranted() async -> Bool
    func getAllTabs() async throws -> [BrowserTab]
    func getTabCount() async throws -> Int
    func closeTab(windowIndex: Int, tabIndex: Int) async throws
    func closeTabs(matching pattern: String) async throws -> Int
    func closeAllTabs(except whitelist: [String]) async throws -> Int
    func quit() async throws
    func forceQuit() async throws
}

// MARK: - AppleScript Browser Controller Base

class AppleScriptBrowserController: BrowserController {
    let browserName: String
    let bundleIdentifier: String
    private let logger: Logger

    init(name: String, bundleId: String) {
        self.browserName = name
        self.bundleIdentifier = bundleId
        self.logger = Logger(subsystem: "com.CraigOClean", category: "BrowserController.\(name)")
    }

    func isRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    func isAutomationPermissionGranted() async -> Bool {
        let script = """
        tell application "\(browserName)"
            return name
        end tell
        """
        do {
            _ = try await runAppleScript(script)
            return true
        } catch {
            return false
        }
    }

    func getAllTabs() async throws -> [BrowserTab] {
        guard isRunning() else { return [] }

        let script = """
        tell application "\(browserName)"
            set output to ""
            set wIdx to 0
            repeat with w in windows
                set wIdx to wIdx + 1
                set tIdx to 0
                repeat with t in tabs of w
                    set tIdx to tIdx + 1
                    try
                        set tabTitle to name of t
                        set tabURL to URL of t
                        set output to output & wIdx & "\\t" & tIdx & "\\t" & tabTitle & "\\t" & tabURL & "\\n"
                    end try
                end repeat
            end repeat
            return output
        end tell
        """

        let result = try await runAppleScript(script)
        return parseTabOutput(result)
    }

    func getTabCount() async throws -> Int {
        guard isRunning() else { return 0 }

        let script = """
        tell application "\(browserName)"
            set tc to 0
            repeat with w in windows
                set tc to tc + (count of tabs of w)
            end repeat
            return tc
        end tell
        """

        let result = try await runAppleScript(script)
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func closeTab(windowIndex: Int, tabIndex: Int) async throws {
        guard isRunning() else { throw BrowserControllerError.notRunning(browserName) }

        let script = """
        tell application "\(browserName)"
            tell window \(windowIndex)
                close tab \(tabIndex)
            end tell
        end tell
        """

        _ = try await runAppleScript(script)
        logger.info("Closed tab \(tabIndex) in window \(windowIndex) of \(self.browserName)")
    }

    func closeTabs(matching pattern: String) async throws -> Int {
        guard isRunning() else { return 0 }

        let escapedPattern = pattern.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "\(browserName)"
            set closed to 0
            repeat with w in windows
                set tabList to tabs of w
                repeat with t in tabList
                    try
                        if URL of t contains "\(escapedPattern)" then
                            close t
                            set closed to closed + 1
                        end if
                    end try
                end repeat
            end repeat
            return closed
        end tell
        """

        let result = try await runAppleScript(script)
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func closeAllTabs(except whitelist: [String] = []) async throws -> Int {
        guard isRunning() else { return 0 }
        let count = try await getTabCount()

        if whitelist.isEmpty {
            let script = """
            tell application "\(browserName)"
                repeat with w in windows
                    try
                        close tabs of w
                    end try
                end repeat
            end tell
            """
            _ = try await runAppleScript(script)
        } else {
            // Close tabs not matching whitelist patterns
            let tabs = try await getAllTabs()
            var closed = 0
            for tab in tabs.reversed() {
                let isWhitelisted = whitelist.contains { pattern in
                    tab.url.localizedCaseInsensitiveContains(pattern)
                }
                if !isWhitelisted {
                    try await closeTab(windowIndex: tab.windowIndex, tabIndex: tab.tabIndex)
                    closed += 1
                }
            }
            return closed
        }

        return count
    }

    func quit() async throws {
        guard isRunning() else { return }

        let script = """
        tell application "\(browserName)"
            quit
        end tell
        """

        _ = try await runAppleScript(script)
        logger.info("Quit \(self.browserName)")
    }

    func forceQuit() async throws {
        guard isRunning() else { return }

        // Use killall for immediate termination
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-9", browserName]
        try process.run()
        process.waitUntilExit()
        logger.info("Force quit \(self.browserName)")
    }

    // MARK: - Helpers

    private func runAppleScript(_ source: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)

                if let error = error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    self.logger.error("AppleScript error \(code): \(message)")
                    continuation.resume(throwing: BrowserControllerError.appleScriptError(code: code, message: message))
                } else {
                    continuation.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }

    private func parseTabOutput(_ output: String) -> [BrowserTab] {
        output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 4,
                      let wIdx = Int(parts[0]),
                      let tIdx = Int(parts[1]) else { return nil }
                return BrowserTab(
                    windowIndex: wIdx,
                    tabIndex: tIdx,
                    title: parts[2],
                    url: parts[3],
                    browserApp: self.browserName
                )
            }
    }
}

// MARK: - Errors

enum BrowserControllerError: LocalizedError {
    case appleScriptError(code: Int, message: String)
    case notRunning(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptError(let code, let message):
            if code == -1743 {
                return "Automation permission denied. Grant access in System Settings > Privacy & Security > Automation."
            }
            return "AppleScript error (\(code)): \(message)"
        case .notRunning(let app):
            return "\(app) is not running"
        case .permissionDenied(let app):
            return "Automation permission denied for \(app)"
        }
    }
}

// MARK: - Concrete Controllers

final class SafariController: AppleScriptBrowserController {
    init() { super.init(name: "Safari", bundleId: "com.apple.Safari") }
}

final class ChromeController: AppleScriptBrowserController {
    init() { super.init(name: "Google Chrome", bundleId: "com.google.Chrome") }
}

final class EdgeController: AppleScriptBrowserController {
    init() { super.init(name: "Microsoft Edge", bundleId: "com.microsoft.edgemac") }
}

final class BraveController: AppleScriptBrowserController {
    init() { super.init(name: "Brave Browser", bundleId: "com.brave.Browser") }
}

final class ArcController: AppleScriptBrowserController {
    init() { super.init(name: "Arc", bundleId: "company.thebrowser.Browser") }
}

/// Firefox has limited AppleScript support; tab listing is not supported
final class FirefoxController: AppleScriptBrowserController {
    init() { super.init(name: "Firefox", bundleId: "org.mozilla.firefox") }

    override func getAllTabs() async throws -> [BrowserTab] {
        // Firefox does not expose tabs via AppleScript
        return []
    }

    override func getTabCount() async throws -> Int {
        return 0
    }

    override func closeTab(windowIndex: Int, tabIndex: Int) async throws {
        throw BrowserControllerError.appleScriptError(code: -1, message: "Firefox does not support AppleScript tab management")
    }

    override func closeTabs(matching pattern: String) async throws -> Int {
        return 0
    }

    override func closeAllTabs(except whitelist: [String]) async throws -> Int {
        return 0
    }
}

// MARK: - Browser Controller Registry

@MainActor
final class BrowserControllerRegistry: ObservableObject {
    static let shared = BrowserControllerRegistry()

    let controllers: [BrowserController] = [
        SafariController(),
        ChromeController(),
        EdgeController(),
        BraveController(),
        ArcController(),
        FirefoxController()
    ]

    func controller(for name: String) -> BrowserController? {
        controllers.first { $0.browserName == name }
    }

    var runningBrowsers: [BrowserController] {
        controllers.filter { $0.isRunning() }
    }
}
