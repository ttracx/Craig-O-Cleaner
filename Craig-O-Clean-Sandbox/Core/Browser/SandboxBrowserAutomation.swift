// MARK: - SandboxBrowserAutomation.swift
// Craig-O-Clean Sandbox Edition - Browser Tab Management
// Provides permission-gated browser automation via AppleScript

import Foundation
import AppKit
import os.log

// MARK: - Browser Types

enum SandboxSupportedBrowser: String, CaseIterable, Identifiable, Hashable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case brave = "Brave Browser"
    case arc = "Arc"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .arc: return "company.thebrowser.Browser"
        }
    }

    var icon: String {
        switch self {
        case .safari: return "safari"
        default: return "globe"
        }
    }

    /// Check if this browser supports AppleScript tab management
    var supportsTabScripting: Bool {
        return true  // All listed browsers support it
    }
}

// MARK: - Browser Tab

struct SandboxBrowserTab: Identifiable, Hashable {
    let id: String
    let browser: SandboxSupportedBrowser
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let isActive: Bool

    var domain: String {
        guard let url = URL(string: url), let host = url.host else { return "" }
        return host
    }

    var isHeavyTab: Bool {
        let heavyDomains = ["youtube.com", "netflix.com", "twitch.tv", "facebook.com",
                           "twitter.com", "instagram.com", "reddit.com", "discord.com",
                           "figma.com", "canva.com", "google.com/maps"]
        return heavyDomains.contains { domain.contains($0) }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SandboxBrowserTab, rhs: SandboxBrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Browser Window

struct SandboxBrowserWindow: Identifiable {
    let id: String
    let browser: SandboxSupportedBrowser
    let windowIndex: Int
    let title: String
    let tabs: [SandboxBrowserTab]
    let activeTabIndex: Int?

    var tabCount: Int { tabs.count }
}

// MARK: - Browser Automation Error

enum BrowserAutomationError: LocalizedError {
    case browserNotInstalled(SandboxSupportedBrowser)
    case browserNotRunning(SandboxSupportedBrowser)
    case permissionDenied(SandboxSupportedBrowser)
    case scriptFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .browserNotInstalled(let browser):
            return "\(browser.rawValue) is not installed."
        case .browserNotRunning(let browser):
            return "\(browser.rawValue) is not running."
        case .permissionDenied(let browser):
            return """
            Automation permission required for \(browser.rawValue).

            To fix this:
            1. Open System Settings
            2. Go to Privacy & Security > Automation
            3. Enable \(browser.rawValue) under Craig-O-Clean
            """
        case .scriptFailed(let message):
            return "Script failed: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

// MARK: - Sandbox Browser Automation Service

/// Provides browser tab management with proper permission gating
/// All automation requires user-granted Automation permission via TCC
@MainActor
final class SandboxBrowserAutomation: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var installedBrowsers: [SandboxSupportedBrowser] = []
    @Published private(set) var runningBrowsers: [SandboxSupportedBrowser] = []
    @Published private(set) var browserTabs: [SandboxSupportedBrowser: [SandboxBrowserWindow]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: BrowserAutomationError?
    @Published private(set) var permissionStatus: [SandboxSupportedBrowser: Bool] = [:]

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.craigoclean.sandbox", category: "BrowserAutomation")
    private let permissionsManager: SandboxPermissionsManager

    // MARK: - Computed Properties

    var allTabs: [SandboxBrowserTab] {
        browserTabs.values.flatMap { $0.flatMap { $0.tabs } }
    }

    var totalTabCount: Int {
        allTabs.count
    }

    var heavyTabs: [SandboxBrowserTab] {
        allTabs.filter { $0.isHeavyTab }
    }

    // MARK: - Initialization

    init(permissionsManager: SandboxPermissionsManager) {
        self.permissionsManager = permissionsManager
        logger.info("SandboxBrowserAutomation initialized")
        detectBrowsers()
    }

    // MARK: - Public Methods

    /// Detect installed and running browsers
    func detectBrowsers() {
        installedBrowsers = SandboxSupportedBrowser.allCases.filter { browser in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
        }

        updateRunningBrowsers()
        logger.info("Detected browsers: \(self.installedBrowsers.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Update list of running browsers
    func updateRunningBrowsers() {
        let running = NSWorkspace.shared.runningApplications
        runningBrowsers = installedBrowsers.filter { browser in
            running.contains { $0.bundleIdentifier == browser.bundleIdentifier }
        }
    }

    /// Fetch tabs from all running browsers (with permission checks)
    func fetchAllTabs() async {
        isLoading = true
        lastError = nil
        updateRunningBrowsers()

        logger.info("Fetching tabs from \(self.runningBrowsers.count) browsers")

        var newTabs: [SandboxSupportedBrowser: [SandboxBrowserWindow]] = [:]

        for browser in runningBrowsers {
            do {
                let windows = try await fetchTabs(for: browser)
                newTabs[browser] = windows
                permissionStatus[browser] = true
                logger.info("Fetched \(windows.flatMap { $0.tabs }.count) tabs from \(browser.rawValue)")
            } catch let error as BrowserAutomationError {
                if case .permissionDenied = error {
                    permissionStatus[browser] = false
                }
                lastError = error
                logger.error("Failed to fetch tabs from \(browser.rawValue): \(error.localizedDescription)")
            } catch {
                logger.error("Unexpected error for \(browser.rawValue): \(error.localizedDescription)")
            }
        }

        browserTabs = newTabs
        isLoading = false
    }

    /// Fetch tabs for a specific browser
    func fetchTabs(for browser: SandboxSupportedBrowser) async throws -> [SandboxBrowserWindow] {
        guard installedBrowsers.contains(browser) else {
            throw BrowserAutomationError.browserNotInstalled(browser)
        }

        guard runningBrowsers.contains(browser) else {
            throw BrowserAutomationError.browserNotRunning(browser)
        }

        let script = generateTabScript(for: browser)
        let output = try await executeAppleScript(script, for: browser)
        return parseTabOutput(output, for: browser)
    }

    /// Close a specific tab
    func closeTab(_ tab: SandboxBrowserTab) async throws {
        let script: String

        switch tab.browser {
        case .safari:
            script = """
            tell application "Safari"
                tell window \(tab.windowIndex)
                    close tab \(tab.tabIndex)
                end tell
            end tell
            """
        default:
            script = """
            tell application "\(tab.browser.rawValue)"
                tell window \(tab.windowIndex)
                    close tab \(tab.tabIndex)
                end tell
            end tell
            """
        }

        _ = try await executeAppleScript(script, for: tab.browser)
        logger.info("Closed tab: \(tab.title) in \(tab.browser.rawValue)")

        // Refresh tabs
        await fetchAllTabs()
    }

    /// Close multiple tabs
    func closeTabs(_ tabs: [SandboxBrowserTab]) async throws {
        // Sort by index descending to avoid index shifting
        let sortedTabs = tabs.sorted { $0.tabIndex > $1.tabIndex }

        for tab in sortedTabs {
            try await closeTab(tab)
        }
    }

    /// Close all tabs for a specific domain
    func closeTabsByDomain(_ domain: String) async throws {
        let tabsToClose = allTabs.filter { $0.domain.contains(domain) }
        try await closeTabs(tabsToClose)
    }

    /// Close heavy/resource-intensive tabs
    func closeHeavyTabs() async throws {
        try await closeTabs(heavyTabs)
    }

    /// Request permission for a browser
    func requestPermission(for browser: SandboxSupportedBrowser) async -> Bool {
        guard let permissionType = browserToPermissionType(browser) else { return false }
        return await permissionsManager.requestAutomationPermission(for: permissionType)
    }

    // MARK: - Private Methods

    private func executeAppleScript(_ script: String, for browser: SandboxSupportedBrowser) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(throwing: BrowserAutomationError.scriptFailed("Failed to create script"))
                    return
                }

                var error: NSDictionary?
                let output = appleScript.executeAndReturnError(&error)

                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"

                    // Permission denied error codes
                    if errorNumber == -1743 || errorNumber == -10004 || errorNumber == -1728 {
                        continuation.resume(throwing: BrowserAutomationError.permissionDenied(browser))
                    } else {
                        continuation.resume(throwing: BrowserAutomationError.scriptFailed(errorMessage))
                    }
                    return
                }

                continuation.resume(returning: output.stringValue ?? "")
            }
        }
    }

    private func generateTabScript(for browser: SandboxSupportedBrowser) -> String {
        switch browser {
        case .safari:
            return """
            set output to ""
            tell application "Safari"
                set windowList to every window
                set windowCount to count of windowList
                repeat with w from 1 to windowCount
                    set win to window w
                    set winName to name of win
                    set activeTabIndex to 0
                    try
                        set activeTabIndex to index of current tab of win
                    end try
                    set allTabs to tabs of win
                    set tabCount to count of allTabs
                    set output to output & "WINDOW:" & w & "|" & winName & "|" & activeTabIndex & linefeed
                    repeat with t from 1 to tabCount
                        set theTab to tab t of win
                        set tabName to ""
                        set tabURL to ""
                        try
                            set tabName to name of theTab
                        end try
                        try
                            set tabURL to URL of theTab
                        end try
                        set isActive to (t = activeTabIndex)
                        set output to output & "TAB:" & t & "|" & tabName & "|" & tabURL & "|" & isActive & linefeed
                    end repeat
                end repeat
            end tell
            return output
            """

        default:
            // Chrome-based browsers
            return """
            set output to ""
            tell application "\(browser.rawValue)"
                set windowList to every window
                set windowCount to count of windowList
                repeat with w from 1 to windowCount
                    set win to window w
                    set winName to ""
                    set activeTabIndex to 0
                    try
                        set winName to title of win
                    end try
                    try
                        set activeTabIndex to active tab index of win
                    end try
                    set allTabs to tabs of win
                    set tabCount to count of allTabs
                    set output to output & "WINDOW:" & w & "|" & winName & "|" & activeTabIndex & linefeed
                    repeat with t from 1 to tabCount
                        set theTab to tab t of win
                        set tabName to ""
                        set tabURL to ""
                        try
                            set tabName to title of theTab
                        end try
                        try
                            set tabURL to URL of theTab
                        end try
                        set isActive to (t = activeTabIndex)
                        set output to output & "TAB:" & t & "|" & tabName & "|" & tabURL & "|" & isActive & linefeed
                    end repeat
                end repeat
            end tell
            return output
            """
        }
    }

    private func parseTabOutput(_ output: String, for browser: SandboxSupportedBrowser) -> [SandboxBrowserWindow] {
        var windows: [SandboxBrowserWindow] = []
        var currentWindowIndex = 0
        var currentWindowTitle = ""
        var currentActiveTabIndex = 0
        var currentTabs: [SandboxBrowserTab] = []

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("WINDOW:") {
                // Save previous window
                if currentWindowIndex > 0 {
                    windows.append(SandboxBrowserWindow(
                        id: "\(browser.rawValue)-window-\(currentWindowIndex)",
                        browser: browser,
                        windowIndex: currentWindowIndex,
                        title: currentWindowTitle,
                        tabs: currentTabs,
                        activeTabIndex: currentActiveTabIndex
                    ))
                    currentTabs = []
                }

                // Parse window info
                let parts = line.replacingOccurrences(of: "WINDOW:", with: "").components(separatedBy: "|")
                if parts.count >= 3 {
                    currentWindowIndex = Int(parts[0]) ?? 0
                    currentWindowTitle = parts[1]
                    currentActiveTabIndex = Int(parts[2]) ?? 0
                }
            } else if line.hasPrefix("TAB:") {
                let parts = line.replacingOccurrences(of: "TAB:", with: "").components(separatedBy: "|")
                if parts.count >= 4 {
                    let tabIndex = Int(parts[0]) ?? 0
                    let tab = SandboxBrowserTab(
                        id: "\(browser.rawValue)-\(currentWindowIndex)-\(tabIndex)",
                        browser: browser,
                        windowIndex: currentWindowIndex,
                        tabIndex: tabIndex,
                        title: parts[1],
                        url: parts[2],
                        isActive: parts[3].lowercased() == "true"
                    )
                    currentTabs.append(tab)
                }
            }
        }

        // Don't forget the last window
        if currentWindowIndex > 0 {
            windows.append(SandboxBrowserWindow(
                id: "\(browser.rawValue)-window-\(currentWindowIndex)",
                browser: browser,
                windowIndex: currentWindowIndex,
                title: currentWindowTitle,
                tabs: currentTabs,
                activeTabIndex: currentActiveTabIndex
            ))
        }

        return windows
    }

    private func browserToPermissionType(_ browser: SandboxSupportedBrowser) -> SandboxPermissionType? {
        switch browser {
        case .safari: return .automationSafari
        case .chrome: return .automationChrome
        case .edge: return .automationEdge
        case .brave: return .automationBrave
        case .arc: return .automationArc
        }
    }
}

// MARK: - Tab Statistics

extension SandboxBrowserAutomation {

    /// Get tab statistics
    func getTabStatistics() -> (total: Int, byBrowser: [SandboxSupportedBrowser: Int], byDomain: [String: Int]) {
        var byBrowser: [SandboxSupportedBrowser: Int] = [:]
        for (browser, windows) in browserTabs {
            byBrowser[browser] = windows.reduce(0) { $0 + $1.tabCount }
        }

        var byDomain: [String: Int] = [:]
        for tab in allTabs {
            byDomain[tab.domain, default: 0] += 1
        }

        return (totalTabCount, byBrowser, byDomain)
    }

    /// Get top domains by tab count
    func getTopDomains(limit: Int = 5) -> [(domain: String, count: Int)] {
        let stats = getTabStatistics()
        return stats.byDomain
            .map { (domain: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
}
