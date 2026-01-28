// MARK: - BrowserAutomationService.swift
// CraigOClean Control Center - Browser Tab Management Service
// Manages browser tabs across Safari, Chrome, Edge, Brave, Arc using AppleScript
// Requires Automation permission for each browser

import Foundation
import Combine
import AppKit
import os.log

// MARK: - Browser Types

enum SupportedBrowser: String, CaseIterable, Identifiable, Hashable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case brave = "Brave Browser"
    case arc = "Arc"
    case firefox = "Firefox"

    var id: String { rawValue }

    /// Primary bundle identifier for the browser
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

    /// All possible bundle identifiers for this browser (including Beta, Dev, Canary versions)
    var allBundleIdentifiers: [String] {
        switch self {
        case .safari:
            return ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]
        case .chrome:
            return ["com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary"]
        case .edge:
            return ["com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary"]
        case .brave:
            return ["com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly"]
        case .arc:
            return ["company.thebrowser.Browser"]
        case .firefox:
            return ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"]
        }
    }

    var icon: String {
        switch self {
        case .safari: return "safari"
        case .chrome: return "globe"
        case .edge: return "globe"
        case .brave: return "globe"
        case .arc: return "globe"
        case .firefox: return "globe"
        }
    }

    var supportsTabScripting: Bool {
        switch self {
        case .safari, .chrome, .edge, .brave, .arc:
            return true
        case .firefox:
            return false // Firefox has limited AppleScript support
        }
    }
}

// MARK: - Browser Tab Model

struct BrowserTab: Identifiable, Hashable {
    let id: String
    let browser: SupportedBrowser
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let isActive: Bool
    
    var domain: String {
        guard let url = URL(string: url),
              let host = url.host else {
            return ""
        }
        return host
    }
    
    var faviconURL: URL? {
        guard let url = URL(string: url),
              let scheme = url.scheme,
              let host = url.host else {
            return nil
        }
        return URL(string: "\(scheme)://\(host)/favicon.ico")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Browser Window Model

struct BrowserWindow: Identifiable {
    let id: String
    let browser: SupportedBrowser
    let windowIndex: Int
    let title: String
    let tabs: [BrowserTab]
    let activeTabIndex: Int?
    
    var tabCount: Int { tabs.count }
}

// MARK: - Browser Automation Errors

enum BrowserAutomationError: LocalizedError {
    case browserNotInstalled(SupportedBrowser)
    case browserNotRunning(SupportedBrowser)
    case automationPermissionDenied(SupportedBrowser)
    case scriptExecutionFailed(String)
    case parseError(String)
    case unsupportedBrowser(SupportedBrowser)
    case tabNotFound
    case windowNotFound
    
    var errorDescription: String? {
        switch self {
        case .browserNotInstalled(let browser):
            return "\(browser.rawValue) is not installed on this Mac."
        case .browserNotRunning(let browser):
            return "\(browser.rawValue) is not currently running. Please open \(browser.rawValue) and try again."
        case .automationPermissionDenied(let browser):
            return """
            Automation permission required for \(browser.rawValue).

            To fix this:
            1. Open System Settings
            2. Go to Privacy & Security → Automation
            3. Find Craig-O-Clean and enable \(browser.rawValue)
            4. Restart \(browser.rawValue) if needed
            5. Click 'Refresh' in Browser Tabs view

            Tip: Run './grant-safari-permission.sh' from the project folder for guided setup.
            """
        case .scriptExecutionFailed(let message):
            return "Script execution failed: \(message)"
        case .parseError(let message):
            return "Failed to parse browser data: \(message)"
        case .unsupportedBrowser(let browser):
            return "\(browser.rawValue) does not support tab automation through AppleScript."
        case .tabNotFound:
            return "The specified tab could not be found. It may have been closed."
        case .windowNotFound:
            return "The specified window could not be found. It may have been closed."
        }
    }
}

// MARK: - Browser Automation Service

@MainActor
final class BrowserAutomationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var installedBrowsers: [SupportedBrowser] = []
    @Published private(set) var runningBrowsers: [SupportedBrowser] = []
    @Published private(set) var browserTabs: [SupportedBrowser: [BrowserWindow]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: BrowserAutomationError?
    @Published private(set) var permissionStatus: [SupportedBrowser: Bool] = [:]
    
    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "BrowserAutomation")
    private var refreshTimer: Timer?
    /// Maps browser type to its currently running application name (for AppleScript)
    private var runningBrowserAppNames: [SupportedBrowser: String] = [:]
    
    // MARK: - Computed Properties
    
    var allTabs: [BrowserTab] {
        browserTabs.values.flatMap { $0.flatMap { $0.tabs } }
    }
    
    var totalTabCount: Int {
        allTabs.count
    }
    
    var tabsByDomain: [String: [BrowserTab]] {
        Dictionary(grouping: allTabs, by: { $0.domain })
    }
    
    // MARK: - Initialization

    init() {
        logger.info("BrowserAutomationService initialized")
        detectInstalledBrowsers()

        // Check if we should prompt for Safari permissions on first launch
        Task { @MainActor in
            await checkAndRequestSafariPermissionIfNeeded()
        }
    }

    /// Setup integration with PermissionsService for auto-enablement
    func setupPermissionAutoEnablement(permissionService: PermissionsService) {
        logger.info("Setting up permission auto-enablement integration")

        // Register callback for when permissions are granted
        permissionService.permissionManager.onPermissionGranted { [weak self] bundleIdentifier in
            guard let self = self else { return }

            Task { @MainActor in
                self.logger.info("🎉 Permission granted for \(bundleIdentifier) - auto-enabling browser features")

                // Auto-fetch tabs for the newly enabled browser
                await self.fetchAllTabs()

                // Start auto-refresh if not already running
                if self.refreshTimer == nil {
                    self.logger.info("Starting auto-refresh timer after permission grant")
                    // Auto-refresh could be enabled here if desired
                }
            }
        }
    }

    /// Proactively request Safari automation permission on first launch
    func checkAndRequestSafariPermissionIfNeeded() async {
        let hasRequestedKey = "hasRequestedSafariAutomation"

        // Only do this once - don't spam the user
        guard !UserDefaults.standard.bool(forKey: hasRequestedKey) else {
            logger.info("Safari permission already requested previously")
            return
        }

        // Check if Safari is installed
        guard installedBrowsers.contains(.safari) else {
            logger.info("Safari not installed, skipping permission request")
            return
        }

        logger.info("First launch - will request Safari automation permission")

        // Mark as requested (even if user denies, we don't want to keep prompting)
        UserDefaults.standard.set(true, forKey: hasRequestedKey)

        // Launch Safari if it's not running to ensure the permission prompt appears
        let safariRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Safari"
        }

        if !safariRunning {
            logger.info("Launching Safari to trigger permission prompt")
            // Launch Safari in the background using modern API
            if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false // Don't bring Safari to front
                configuration.hides = false

                _ = try? await NSWorkspace.shared.openApplication(at: safariURL, configuration: configuration)
                // Wait for Safari to launch
                try? await Task.sleep(for: .seconds(2))
            }
        }

        // Now trigger the permission prompt with a simple AppleScript
        await triggerSafariPermissionPrompt()
    }

    /// Trigger the macOS permission prompt for Safari automation
    func triggerSafariPermissionPrompt() async {
        logger.info("Triggering Safari automation permission prompt")

        let script = """
        tell application "Safari"
            get name
        end tell
        """

        do {
            _ = try await executeAppleScript(script)
            logger.info("Safari permission prompt triggered successfully")
        } catch {
            logger.warning("Safari permission prompt failed (may be denied): \(error.localizedDescription)")
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods

    /// Detect which supported browsers are installed (checks all variants: stable, beta, dev, canary)
    func detectInstalledBrowsers() {
        installedBrowsers = SupportedBrowser.allCases.filter { browser in
            // Check if any variant of the browser is installed
            browser.allBundleIdentifiers.contains { bundleId in
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
            }
        }
        logger.info("Detected installed browsers: \(self.installedBrowsers.map { $0.rawValue }.joined(separator: ", "))")
        updateRunningBrowsers()
    }

    /// Update list of currently running browsers (checks all variants)
    func updateRunningBrowsers() {
        let running = NSWorkspace.shared.runningApplications
        runningBrowserAppNames.removeAll()

        runningBrowsers = installedBrowsers.filter { browser in
            // Check if any variant of the browser is running
            for bundleId in browser.allBundleIdentifiers {
                if let runningApp = running.first(where: { $0.bundleIdentifier == bundleId }) {
                    // Store the actual app name for AppleScript usage
                    if let appName = runningApp.localizedName {
                        runningBrowserAppNames[browser] = appName
                    }
                    return true
                }
            }
            return false
        }

        logger.debug("Running browsers: \(self.runningBrowsers.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Get the actual application name for AppleScript (handles browser variants)
    func getAppleScriptAppName(for browser: SupportedBrowser) -> String {
        // Return the detected running app name, or fall back to the default name
        return runningBrowserAppNames[browser] ?? browser.rawValue
    }
    
    /// Fetch all tabs from all running browsers
    func fetchAllTabs() async {
        isLoading = true
        lastError = nil
        updateRunningBrowsers()

        logger.info("Starting to fetch tabs from \(self.runningBrowsers.count) running browsers")

        var newTabs: [SupportedBrowser: [BrowserWindow]] = [:]

        for browser in runningBrowsers where browser.supportsTabScripting {
            logger.info("Fetching tabs for \(browser.rawValue)")
            do {
                let windows = try await fetchTabs(for: browser)
                logger.info("Successfully fetched \(windows.count) windows with \(windows.reduce(0) { $0 + $1.tabs.count }) total tabs for \(browser.rawValue)")
                newTabs[browser] = windows
                permissionStatus[browser] = true
            } catch let error as BrowserAutomationError {
                logger.error("Failed to fetch tabs for \(browser.rawValue): \(error.localizedDescription)")
                if case .automationPermissionDenied = error {
                    permissionStatus[browser] = false
                }
                lastError = error
            } catch {
                logger.error("Unexpected error fetching tabs for \(browser.rawValue): \(error.localizedDescription)")
            }
        }

        browserTabs = newTabs
        let totalTabs = allTabs.count
        logger.info("Fetch complete. Total tabs: \(totalTabs)")
        isLoading = false
    }
    
    /// Fetch tabs for a specific browser
    func fetchTabs(for browser: SupportedBrowser) async throws -> [BrowserWindow] {
        guard browser.supportsTabScripting else {
            throw BrowserAutomationError.unsupportedBrowser(browser)
        }
        
        guard installedBrowsers.contains(browser) else {
            throw BrowserAutomationError.browserNotInstalled(browser)
        }
        
        guard runningBrowsers.contains(browser) else {
            throw BrowserAutomationError.browserNotRunning(browser)
        }
        
        let script: String
        
        switch browser {
        case .safari:
            script = safariTabScript()
        case .chrome, .edge, .brave:
            script = chromiumTabScript(for: browser)
        case .arc:
            script = arcTabScript()
        case .firefox:
            throw BrowserAutomationError.unsupportedBrowser(browser)
        }
        
        let output = try await executeAppleScript(script, for: browser)
        return try parseTabOutput(output, for: browser)
    }
    
    /// Close a specific tab
    func closeTab(_ tab: BrowserTab) async throws {
        let appName = getAppleScriptAppName(for: tab.browser)
        let script: String

        switch tab.browser {
        case .safari:
            script = """
            tell application "\(appName)"
                tell window \(tab.windowIndex)
                    close tab \(tab.tabIndex)
                end tell
            end tell
            """
        case .chrome, .edge, .brave:
            script = """
            tell application "\(appName)"
                tell window \(tab.windowIndex)
                    close tab \(tab.tabIndex)
                end tell
            end tell
            """
        case .arc:
            script = """
            tell application "\(appName)"
                tell window \(tab.windowIndex)
                    close tab \(tab.tabIndex)
                end tell
            end tell
            """
        case .firefox:
            throw BrowserAutomationError.unsupportedBrowser(tab.browser)
        }

        _ = try await executeAppleScript(script, for: tab.browser)
        logger.info("Closed tab: \(tab.title) in \(appName)")

        // Refresh tabs after closing
        await fetchAllTabs()
    }
    
    /// Close all tabs for a specific domain
    func closeTabsByDomain(_ domain: String, browser: SupportedBrowser? = nil) async throws {
        let tabsToClose = allTabs.filter { tab in
            let domainMatch = tab.domain == domain || tab.domain.hasSuffix(".\(domain)")
            let browserMatch = browser == nil || tab.browser == browser
            return domainMatch && browserMatch
        }
        
        for tab in tabsToClose.reversed() { // Reverse to close from end to preserve indices
            try await closeTab(tab)
        }
        
        logger.info("Closed \(tabsToClose.count) tabs for domain: \(domain)")
    }
    
    /// Close all tabs in a window
    func closeAllTabsInWindow(browser: SupportedBrowser, windowIndex: Int) async throws {
        let appName = getAppleScriptAppName(for: browser)
        let script = """
        tell application "\(appName)"
            close window \(windowIndex)
        end tell
        """

        _ = try await executeAppleScript(script, for: browser)
        logger.info("Closed all tabs in window \(windowIndex) of \(appName)")

        await fetchAllTabs()
    }
    
    /// Close all tabs except the active one
    func closeOtherTabs(in browser: SupportedBrowser, windowIndex: Int) async throws {
        guard let windows = browserTabs[browser],
              let window = windows.first(where: { $0.windowIndex == windowIndex }) else {
            throw BrowserAutomationError.windowNotFound
        }
        
        let inactiveTabs = window.tabs.filter { !$0.isActive }
        
        for tab in inactiveTabs.reversed() {
            try await closeTab(tab)
        }
        
        logger.info("Closed \(inactiveTabs.count) inactive tabs in window \(windowIndex) of \(browser.rawValue)")
    }
    
    /// Get heavy tabs (high memory consumers)
    func getHeavyTabs(limit: Int = 10) -> [BrowserTab] {
        // Since we can't directly measure tab memory via AppleScript,
        // we use heuristics: tabs with streaming domains, lots of media, etc.
        let heavyDomains = ["youtube.com", "netflix.com", "twitch.tv", "facebook.com", 
                           "twitter.com", "instagram.com", "reddit.com", "discord.com"]
        
        return allTabs
            .sorted { tab1, tab2 in
                let isHeavy1 = heavyDomains.contains { tab1.domain.contains($0) }
                let isHeavy2 = heavyDomains.contains { tab2.domain.contains($0) }
                if isHeavy1 != isHeavy2 { return isHeavy1 }
                return tab1.title < tab2.title
            }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Start auto-refresh
    func startAutoRefresh(interval: TimeInterval = 10.0) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAllTabs()
            }
        }
    }
    
    /// Stop auto-refresh
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func executeAppleScript(_ script: String, for browser: SupportedBrowser? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let output = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0

                    self?.logger.error("AppleScript error \(errorNumber): \(errorMessage)")

                    // Handle various permission-related error codes
                    // -1743 = "Not authorized to send Apple events"
                    // -10004 = "A privilege violation occurred"
                    // -1728 = "Can't get <object>" (often means permission denied)
                    // -600 = "Application isn't running" or permission issue
                    if errorNumber == -1743 || errorNumber == -10004 || errorNumber == -1728 {
                        // Use the provided browser, or default to Safari for backwards compatibility
                        let targetBrowser = browser ?? .safari
                        self?.logger.warning("Automation permission denied for \(targetBrowser.rawValue). User needs to grant permission in System Settings.")
                        continuation.resume(throwing: BrowserAutomationError.automationPermissionDenied(targetBrowser))
                    } else {
                        continuation.resume(throwing: BrowserAutomationError.scriptExecutionFailed(errorMessage))
                    }
                    return
                }

                let result = output?.stringValue ?? ""
                self?.logger.debug("AppleScript output: \(result.prefix(200))...")
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - AppleScript Generators
    
    private func safariTabScript() -> String {
        // Safari 15+ (macOS Monterey) uses Tab Groups
        // We need to iterate through all tab groups to get all tabs
        // Falls back to direct tab access for older Safari versions
        let appName = getAppleScriptAppName(for: .safari)
        return """
        set output to ""
        tell application "\(appName)"
            set windowList to every window
            set windowCount to count of windowList
            repeat with w from 1 to windowCount
                set win to window w
                set winName to name of win
                set activeTabIndex to 0
                try
                    set activeTabIndex to index of current tab of win
                end try

                -- Try to get tabs from Tab Groups first (Safari 15+)
                set allTabs to {}
                set hasTabGroups to false
                try
                    set tabGroupList to tab groups of win
                    if (count of tabGroupList) > 0 then
                        set hasTabGroups to true
                        repeat with tg in tabGroupList
                            set groupTabs to tabs of tg
                            repeat with gt in groupTabs
                                set end of allTabs to gt
                            end repeat
                        end repeat
                    end if
                end try

                -- If no tab groups or tab groups failed, get tabs directly from window
                if not hasTabGroups then
                    try
                        set allTabs to tabs of win
                    end try
                end if

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
    }
    
    private func chromiumTabScript(for browser: SupportedBrowser) -> String {
        // Chromium browsers (Chrome, Edge, Brave) expose tabs directly
        // Tab groups exist but are not exposed via AppleScript - tabs are still accessible
        let appName = getAppleScriptAppName(for: browser)
        return """
        set output to ""
        tell application "\(appName)"
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

                set allTabs to {}
                try
                    set allTabs to tabs of win
                end try
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
    
    private func arcTabScript() -> String {
        // Arc browser has a unique tab model with spaces and pinned tabs
        // The standard tabs of window should return all accessible tabs
        let appName = getAppleScriptAppName(for: .arc)
        return """
        set output to ""
        tell application "\(appName)"
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
                    set activeTabIndex to index of active tab of win
                end try

                set allTabs to {}
                try
                    set allTabs to tabs of win
                end try
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
    
    // MARK: - Parsing
    
    private func parseTabOutput(_ output: String, for browser: SupportedBrowser) throws -> [BrowserWindow] {
        var windows: [BrowserWindow] = []
        var currentWindowIndex = 0
        var currentWindowTitle = ""
        var currentActiveTabIndex = 0
        var currentTabs: [BrowserTab] = []
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("WINDOW:") {
                // Save previous window if exists
                if currentWindowIndex > 0 {
                    windows.append(BrowserWindow(
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
                // Parse tab info
                let parts = line.replacingOccurrences(of: "TAB:", with: "").components(separatedBy: "|")
                if parts.count >= 4 {
                    let tabIndex = Int(parts[0]) ?? 0
                    let tabTitle = parts[1]
                    let tabURL = parts[2]
                    let isActive = parts[3].lowercased() == "true"
                    
                    let tab = BrowserTab(
                        id: "\(browser.rawValue)-\(currentWindowIndex)-\(tabIndex)",
                        browser: browser,
                        windowIndex: currentWindowIndex,
                        tabIndex: tabIndex,
                        title: tabTitle,
                        url: tabURL,
                        isActive: isActive
                    )
                    currentTabs.append(tab)
                }
            }
        }
        
        // Don't forget the last window
        if currentWindowIndex > 0 {
            windows.append(BrowserWindow(
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
}

// MARK: - Helper Extension

extension BrowserAutomationService {
    
    /// Get tab statistics summary
    func getTabStatistics() -> (total: Int, byBrowser: [SupportedBrowser: Int], byDomain: [String: Int]) {
        let total = totalTabCount
        
        var byBrowser: [SupportedBrowser: Int] = [:]
        for (browser, windows) in browserTabs {
            byBrowser[browser] = windows.reduce(0) { $0 + $1.tabs.count }
        }
        
        var byDomain: [String: Int] = [:]
        for tab in allTabs {
            byDomain[tab.domain, default: 0] += 1
        }
        
        return (total, byBrowser, byDomain)
    }
    
    /// Get top domains by tab count
    func getTopDomains(limit: Int = 5) -> [(domain: String, count: Int)] {
        tabsByDomain
            .map { (domain: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
}
