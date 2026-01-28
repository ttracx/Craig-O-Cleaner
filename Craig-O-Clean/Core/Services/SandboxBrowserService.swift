// MARK: - SandboxBrowserService.swift
// Craig-O-Clean - Sandbox-Compliant Browser Service
// Integrates with PermissionManager and AuditLogService for MAS compliance

import Foundation
import AppKit
import Combine
import os.log

// MARK: - Browser Type (Sandbox-Safe)

enum Browser: String, CaseIterable, Identifiable, Hashable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case brave = "Brave Browser"
    case arc = "Arc"
    case firefox = "Firefox"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .arc: return "company.thebrowser.Browser"
        case .firefox: return "org.mozilla.firefox"
        }
    }

    var supportsTabScripting: Bool {
        switch self {
        case .safari, .chrome, .edge, .brave, .arc:
            return true
        case .firefox:
            return false
        }
    }

    var icon: String {
        switch self {
        case .safari: return "safari"
        default: return "globe"
        }
    }

    /// SF Symbol icon name for UI display
    var iconName: String { icon }

    /// Human-readable display name
    var displayName: String { rawValue }
}

// MARK: - Tab Model

struct Tab: Identifiable, Hashable {
    let id: String
    let browser: Browser
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let isActive: Bool

    var domain: String {
        guard let url = URL(string: url), let host = url.host else { return "" }
        return host
    }

    /// Alias for domain for UI compatibility
    var urlHost: String { domain }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Window Model

struct BrowserWindowInfo: Identifiable {
    let id: String
    let browser: Browser
    let windowIndex: Int
    let title: String
    let tabs: [Tab]
    let activeTabIndex: Int?

    var tabCount: Int { tabs.count }
}

// MARK: - Browser Error

enum BrowserError: LocalizedError {
    case notInstalled(Browser)
    case notRunning(Browser)
    case permissionRequired(Browser)
    case scriptFailed(String)
    case tabNotFound
    case unsupported(Browser)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let browser):
            return "\(browser.rawValue) is not installed."
        case .notRunning(let browser):
            return "\(browser.rawValue) is not running."
        case .permissionRequired(let browser):
            return "Automation permission required for \(browser.rawValue)."
        case .scriptFailed(let message):
            return "Script failed: \(message)"
        case .tabNotFound:
            return "Tab not found."
        case .unsupported(let browser):
            return "\(browser.rawValue) doesn't support tab automation."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionRequired(let browser):
            return "Open System Settings > Privacy & Security > Automation and enable Craig-O-Clean for \(browser.rawValue)."
        default:
            return nil
        }
    }
}

// MARK: - Sandbox Browser Service

@MainActor
final class SandboxBrowserService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var installedBrowsers: [Browser] = []
    @Published private(set) var runningBrowsers: [Browser] = []
    @Published private(set) var tabsByBrowser: [Browser: [BrowserWindowInfo]] = [:]
    @Published private(set) var permissionStatus: [Browser: PermissionState] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: BrowserError?

    // MARK: - Dependencies

    private let permissionManager: PermissionManager
    private let auditLog: AuditLogService
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "SandboxBrowserService")

    // MARK: - Computed Properties

    var allTabs: [Tab] {
        tabsByBrowser.values.flatMap { $0.flatMap { $0.tabs } }
    }

    var totalTabCount: Int {
        allTabs.count
    }

    var tabsByDomain: [String: [Tab]] {
        Dictionary(grouping: allTabs, by: { $0.domain })
    }

    // MARK: - Initialization

    init(permissionManager: PermissionManager, auditLog: AuditLogService) {
        self.permissionManager = permissionManager
        self.auditLog = auditLog

        detectBrowsers()
    }

    // MARK: - Browser Detection

    func detectBrowsers() {
        installedBrowsers = Browser.allCases.filter { browser in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
        }

        updateRunningBrowsers()
        logger.info("Detected \(self.installedBrowsers.count) installed browsers")
    }

    func updateRunningBrowsers() {
        let running = NSWorkspace.shared.runningApplications
        runningBrowsers = installedBrowsers.filter { browser in
            running.contains { $0.bundleIdentifier == browser.bundleIdentifier }
        }
    }

    // MARK: - Permission Management

    /// Check permission for a browser
    func checkPermission(for browser: Browser) async -> PermissionState {
        let state = await permissionManager.checkAutomation(for: browser.bundleIdentifier)
        permissionStatus[browser] = state
        return state
    }

    /// Request permission for a browser
    func requestPermission(for browser: Browser) async -> PermissionState {
        auditLog.log(.permissionRequested, target: browser.rawValue, metadata: ["type": "automation"])

        let state = await permissionManager.requestAutomation(for: browser.bundleIdentifier)
        permissionStatus[browser] = state

        if state == .granted {
            auditLog.log(.permissionGranted, target: browser.rawValue, metadata: ["type": "automation"])
        } else {
            auditLog.log(.permissionDenied, target: browser.rawValue, metadata: ["type": "automation"])
        }

        return state
    }

    /// Open automation settings
    func openAutomationSettings() {
        permissionManager.openAutomationSettings()
    }

    // MARK: - Tab Fetching

    /// Fetch all tabs from all running browsers
    func fetchAllTabs() async {
        isLoading = true
        lastError = nil
        updateRunningBrowsers()

        var newTabs: [Browser: [BrowserWindowInfo]] = [:]

        for browser in runningBrowsers where browser.supportsTabScripting {
            // Check permission first
            let permState = await checkPermission(for: browser)

            if permState != .granted {
                logger.info("Skipping \(browser.rawValue) - permission not granted")
                continue
            }

            do {
                let windows = try await fetchTabs(for: browser)
                newTabs[browser] = windows
                logger.info("Fetched \(windows.reduce(0) { $0 + $1.tabCount }) tabs from \(browser.rawValue)")
            } catch let error as BrowserError {
                logger.error("Failed to fetch tabs from \(browser.rawValue): \(error.localizedDescription)")
                lastError = error
            } catch {
                logger.error("Unexpected error: \(error.localizedDescription)")
            }
        }

        tabsByBrowser = newTabs
        isLoading = false
    }

    /// Fetch tabs for a specific browser
    func fetchTabs(for browser: Browser) async throws -> [BrowserWindowInfo] {
        guard browser.supportsTabScripting else {
            throw BrowserError.unsupported(browser)
        }

        guard installedBrowsers.contains(browser) else {
            throw BrowserError.notInstalled(browser)
        }

        guard runningBrowsers.contains(browser) else {
            throw BrowserError.notRunning(browser)
        }

        // Check permission
        let permState = await checkPermission(for: browser)
        guard permState == .granted else {
            throw BrowserError.permissionRequired(browser)
        }

        let script = generateTabScript(for: browser)
        let output = try await executeAppleScript(script, browser: browser)
        return parseTabOutput(output, browser: browser)
    }

    // MARK: - Tab Operations

    /// Close a specific tab
    func closeTab(_ tab: Tab) async -> Result<Void, BrowserError> {
        // Check permission
        let permState = await checkPermission(for: tab.browser)
        guard permState == .granted else {
            return .failure(.permissionRequired(tab.browser))
        }

        let script = generateCloseTabScript(tab)

        do {
            _ = try await executeAppleScript(script, browser: tab.browser)
            auditLog.log(.tabClosed, target: "\(tab.browser.rawValue): \(tab.title)", metadata: [
                "url": tab.url,
                "domain": tab.domain
            ])
            await fetchAllTabs()
            return .success(())
        } catch {
            return .failure(.scriptFailed(error.localizedDescription))
        }
    }

    /// Close tabs by domain
    func closeTabsByDomain(_ domain: String, browser: Browser? = nil) async -> Result<Int, BrowserError> {
        let tabsToClose = allTabs.filter { tab in
            let domainMatch = tab.domain == domain || tab.domain.hasSuffix(".\(domain)")
            let browserMatch = browser == nil || tab.browser == browser
            return domainMatch && browserMatch
        }

        var closedCount = 0

        for tab in tabsToClose.reversed() {
            let result = await closeTab(tab)
            if case .success = result {
                closedCount += 1
            }
        }

        if closedCount > 0 {
            auditLog.log(.tabsClosedByDomain, target: domain, metadata: [
                "count": "\(closedCount)"
            ])
        }

        return .success(closedCount)
    }

    /// Close all tabs in a browser (with confirmation)
    func closeAllTabs(in browser: Browser) async -> Result<Int, BrowserError> {
        guard let windows = tabsByBrowser[browser] else {
            return .success(0)
        }

        let tabCount = windows.reduce(0) { $0 + $1.tabCount }

        let script = """
        tell application "\(browser.rawValue)"
            close every window
        end tell
        """

        do {
            _ = try await executeAppleScript(script, browser: browser)
            auditLog.log(.tabsClosedAll, target: browser.rawValue, metadata: [
                "count": "\(tabCount)"
            ])
            await fetchAllTabs()
            return .success(tabCount)
        } catch {
            return .failure(.scriptFailed(error.localizedDescription))
        }
    }

    /// Quit a browser
    func quitBrowser(_ browser: Browser) async -> Result<Void, BrowserError> {
        let permState = await checkPermission(for: browser)
        guard permState == .granted else {
            return .failure(.permissionRequired(browser))
        }

        let script = """
        tell application "\(browser.rawValue)"
            quit
        end tell
        """

        do {
            _ = try await executeAppleScript(script, browser: browser)
            auditLog.log(.browserQuit, target: browser.rawValue)
            updateRunningBrowsers()
            return .success(())
        } catch {
            return .failure(.scriptFailed(error.localizedDescription))
        }
    }

    // MARK: - Heavy Tabs

    /// Get tabs from heavy domains (streaming, social, etc.)
    func getHeavyTabs(limit: Int = 10) -> [Tab] {
        let heavyDomains = ["youtube.com", "netflix.com", "twitch.tv", "facebook.com",
                           "twitter.com", "instagram.com", "reddit.com", "discord.com",
                           "tiktok.com", "spotify.com"]

        return allTabs
            .filter { tab in
                heavyDomains.contains { tab.domain.contains($0) }
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Get top domains by tab count
    func getTopDomains(limit: Int = 5) -> [(domain: String, count: Int)] {
        tabsByDomain
            .map { (domain: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Private Methods

    private func executeAppleScript(_ script: String, browser: Browser) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard self != nil else {
                    continuation.resume(throwing: BrowserError.scriptFailed("Service deallocated"))
                    return
                }

                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(throwing: BrowserError.scriptFailed("Failed to create script"))
                    return
                }

                var error: NSDictionary?
                let output = appleScript.executeAndReturnError(&error)

                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"

                    if errorNumber == -1743 || errorNumber == -10004 || errorNumber == -1728 {
                        continuation.resume(throwing: BrowserError.permissionRequired(browser))
                    } else {
                        continuation.resume(throwing: BrowserError.scriptFailed(errorMessage))
                    }
                    return
                }

                continuation.resume(returning: output.stringValue ?? "")
            }
        }
    }

    private func generateTabScript(for browser: Browser) -> String {
        switch browser {
        case .safari:
            return """
            set output to ""
            tell application "Safari"
                set windowList to every window
                repeat with w from 1 to count of windowList
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
                        set theTab to item t of allTabs
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

        case .chrome, .edge, .brave:
            return """
            set output to ""
            tell application "\(browser.rawValue)"
                set windowList to every window
                repeat with w from 1 to count of windowList
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

        case .arc:
            return """
            set output to ""
            tell application "Arc"
                set windowList to every window
                repeat with w from 1 to count of windowList
                    set win to window w
                    set winName to ""
                    set activeTabIndex to 0
                    try
                        set winName to title of win
                    end try
                    try
                        set activeTabIndex to index of active tab of win
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

        case .firefox:
            return ""
        }
    }

    private func generateCloseTabScript(_ tab: Tab) -> String {
        """
        tell application "\(tab.browser.rawValue)"
            tell window \(tab.windowIndex)
                close tab \(tab.tabIndex)
            end tell
        end tell
        """
    }

    private func parseTabOutput(_ output: String, browser: Browser) -> [BrowserWindowInfo] {
        var windows: [BrowserWindowInfo] = []
        var currentWindowIndex = 0
        var currentWindowTitle = ""
        var currentActiveTabIndex = 0
        var currentTabs: [Tab] = []

        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("WINDOW:") {
                if currentWindowIndex > 0 {
                    windows.append(BrowserWindowInfo(
                        id: "\(browser.rawValue)-\(currentWindowIndex)",
                        browser: browser,
                        windowIndex: currentWindowIndex,
                        title: currentWindowTitle,
                        tabs: currentTabs,
                        activeTabIndex: currentActiveTabIndex
                    ))
                    currentTabs = []
                }

                let parts = line.replacingOccurrences(of: "WINDOW:", with: "").components(separatedBy: "|")
                if parts.count >= 3 {
                    currentWindowIndex = Int(parts[0]) ?? 0
                    currentWindowTitle = parts[1]
                    currentActiveTabIndex = Int(parts[2]) ?? 0
                }
            } else if line.hasPrefix("TAB:") {
                let parts = line.replacingOccurrences(of: "TAB:", with: "").components(separatedBy: "|")
                if parts.count >= 4 {
                    let tab = Tab(
                        id: "\(browser.rawValue)-\(currentWindowIndex)-\(parts[0])",
                        browser: browser,
                        windowIndex: currentWindowIndex,
                        tabIndex: Int(parts[0]) ?? 0,
                        title: parts[1],
                        url: parts[2],
                        isActive: parts[3].lowercased() == "true"
                    )
                    currentTabs.append(tab)
                }
            }
        }

        if currentWindowIndex > 0 {
            windows.append(BrowserWindowInfo(
                id: "\(browser.rawValue)-\(currentWindowIndex)",
                browser: browser,
                windowIndex: currentWindowIndex,
                title: currentWindowTitle,
                tabs: currentTabs,
                activeTabIndex: currentActiveTabIndex
            ))
        }

        return windows
    }
}
