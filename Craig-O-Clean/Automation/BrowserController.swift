// MARK: - BrowserController.swift
// Craig-O-Clean - Browser Controller Protocol & Implementations
// Provides unified interface for browser tab management across Safari, Chrome, etc.

import Foundation
import AppKit
import os.log

// MARK: - Browser Tab Model (Legacy - for BrowserController protocol)

struct ControllerBrowserTab: Identifiable {
    let id = UUID()
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
}

// MARK: - Browser Controller Protocol

protocol BrowserController {
    var browserName: String { get }
    var bundleIdentifier: String { get }

    func isRunning() -> Bool
    func getAllTabs() async throws -> [ControllerBrowserTab]
    func closeTabs(matching pattern: String) async throws -> Int
    func closeAllTabs() async throws -> Int
    func tabCount() async throws -> Int
}

// MARK: - AppleScript Browser Controller Base

class AppleScriptBrowserController: BrowserController, @unchecked Sendable {
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

    func getAllTabs() async throws -> [ControllerBrowserTab] {
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

    func closeTabs(matching pattern: String) async throws -> Int {
        guard isRunning() else { return 0 }

        let script = """
        tell application "\(browserName)"
            set closed to 0
            repeat with w in windows
                set tabList to tabs of w
                repeat with t in tabList
                    try
                        if URL of t contains "\(pattern)" then
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

    func closeAllTabs() async throws -> Int {
        guard isRunning() else { return 0 }
        let count = try await tabCount()

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
        return count
    }

    func tabCount() async throws -> Int {
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

    private func parseTabOutput(_ output: String) -> [ControllerBrowserTab] {
        output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 4,
                      let wIdx = Int(parts[0]),
                      let tIdx = Int(parts[1]) else { return nil }
                return ControllerBrowserTab(
                    windowIndex: wIdx,
                    tabIndex: tIdx,
                    title: parts[2],
                    url: parts[3]
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
    override init(name: String, bundleId: String) {
        super.init(name: name, bundleId: bundleId)
    }

    convenience init() {
        self.init(name: "Safari", bundleId: "com.apple.Safari")
    }
}

final class ChromeController: AppleScriptBrowserController {
    override init(name: String, bundleId: String) {
        super.init(name: name, bundleId: bundleId)
    }

    convenience init() {
        self.init(name: "Google Chrome", bundleId: "com.google.Chrome")
    }
}

final class EdgeController: AppleScriptBrowserController {
    override init(name: String, bundleId: String) {
        super.init(name: name, bundleId: bundleId)
    }

    convenience init() {
        self.init(name: "Microsoft Edge", bundleId: "com.microsoft.edgemac")
    }
}

final class BraveController: AppleScriptBrowserController {
    override init(name: String, bundleId: String) {
        super.init(name: name, bundleId: bundleId)
    }

    convenience init() {
        self.init(name: "Brave Browser", bundleId: "com.brave.Browser")
    }
}

final class ArcController: AppleScriptBrowserController {
    override init(name: String, bundleId: String) {
        super.init(name: name, bundleId: bundleId)
    }

    convenience init() {
        self.init(name: "Arc", bundleId: "company.thebrowser.Browser")
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
        ArcController()
    ]

    func controller(for name: String) -> BrowserController? {
        controllers.first { $0.browserName == name }
    }

    var runningBrowsers: [BrowserController] {
        controllers.filter { $0.isRunning() }
    }
}
