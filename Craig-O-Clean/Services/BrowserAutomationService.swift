// BrowserAutomationService.swift
// ClearMind Control Center
//
// Service for managing browser tabs across Safari, Chrome, Edge, and other browsers
// Uses AppleScript for browser automation with proper error handling

import Foundation
import AppKit
import Combine

// MARK: - Browser Tab Models

/// Represents a single browser tab
struct BrowserTab: Identifiable, Hashable {
    let id: String
    let browser: BrowserType
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    
    var domain: String {
        guard let url = URL(string: url), let host = url.host else {
            return ""
        }
        return host
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a browser window containing multiple tabs
struct BrowserWindow: Identifiable {
    let id: String
    let browser: BrowserType
    let windowIndex: Int
    let title: String
    let tabs: [BrowserTab]
    
    var tabCount: Int { tabs.count }
}

/// Supported browser types
enum BrowserType: String, CaseIterable, Identifiable {
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
    
    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return app.icon
        }
        return NSWorkspace.shared.icon(forFile: "/Applications/\(rawValue).app")
    }
    
    var isChromiumBased: Bool {
        switch self {
        case .chrome, .edge, .brave, .arc:
            return true
        case .safari, .firefox:
            return false
        }
    }
    
    var supportsTabManagement: Bool {
        switch self {
        case .safari, .chrome, .edge, .brave:
            return true
        case .arc, .firefox:
            return false // Limited scripting support
        }
    }
}

/// Result of a browser operation
enum BrowserOperationResult {
    case success
    case permissionDenied
    case browserNotRunning
    case scriptError(String)
    case timeout
    case unsupported
}

// MARK: - Browser Automation Service

/// Service for automating browser tab management using AppleScript
@MainActor
class BrowserAutomationService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var installedBrowsers: [BrowserType] = []
    @Published var runningBrowsers: [BrowserType] = []
    @Published var browserWindows: [BrowserWindow] = []
    @Published var allTabs: [BrowserTab] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var permissionStatus: [BrowserType: Bool] = [:]
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let scriptTimeout: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    init() {
        detectInstalledBrowsers()
        updateRunningBrowsers()
        
        // Monitor for app launches/terminations
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateRunningBrowsers()
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateRunningBrowsers()
            }
        }
    }
    
    // MARK: - Browser Detection
    
    /// Detect installed browsers on the system
    func detectInstalledBrowsers() {
        installedBrowsers = BrowserType.allCases.filter { browser in
            let appPath = "/Applications/\(browser.rawValue).app"
            return FileManager.default.fileExists(atPath: appPath)
        }
    }
    
    /// Update list of currently running browsers
    func updateRunningBrowsers() {
        let runningApps = NSWorkspace.shared.runningApplications
        runningBrowsers = BrowserType.allCases.filter { browser in
            runningApps.contains { $0.bundleIdentifier == browser.bundleIdentifier }
        }
    }
    
    // MARK: - Tab Fetching
    
    /// Fetch all tabs from all running browsers
    func fetchAllTabs() async {
        isLoading = true
        lastError = nil
        
        var allWindows: [BrowserWindow] = []
        var allTabsList: [BrowserTab] = []
        
        for browser in runningBrowsers {
            guard browser.supportsTabManagement else { continue }
            
            do {
                let windows = try await fetchTabs(for: browser)
                allWindows.append(contentsOf: windows)
                
                for window in windows {
                    allTabsList.append(contentsOf: window.tabs)
                }
                
                permissionStatus[browser] = true
            } catch {
                permissionStatus[browser] = false
                lastError = "Failed to access \(browser.rawValue): \(error.localizedDescription)"
            }
        }
        
        browserWindows = allWindows
        allTabs = allTabsList
        isLoading = false
    }
    
    /// Fetch tabs from a specific browser
    func fetchTabs(for browser: BrowserType) async throws -> [BrowserWindow] {
        let script: String
        
        switch browser {
        case .safari:
            script = generateSafariTabsScript()
        case .chrome, .edge, .brave:
            script = generateChromiumTabsScript(browser: browser)
        case .arc, .firefox:
            throw NSError(domain: "BrowserAutomation", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Browser not supported for tab management"])
        }
        
        let result = try await executeAppleScript(script)
        return parseTabsResult(result, browser: browser)
    }
    
    // MARK: - Tab Actions
    
    /// Close a specific tab
    func closeTab(_ tab: BrowserTab) async -> BrowserOperationResult {
        let script: String
        
        switch tab.browser {
        case .safari:
            script = generateSafariCloseTabScript(windowIndex: tab.windowIndex, tabIndex: tab.tabIndex)
        case .chrome, .edge, .brave:
            script = generateChromiumCloseTabScript(browser: tab.browser, windowIndex: tab.windowIndex, tabIndex: tab.tabIndex)
        case .arc, .firefox:
            return .unsupported
        }
        
        do {
            _ = try await executeAppleScript(script)
            
            // Remove from local list
            allTabs.removeAll { $0.id == tab.id }
            
            // Update windows
            if let windowIndex = browserWindows.firstIndex(where: { $0.id == "\(tab.browser.rawValue)-\(tab.windowIndex)" }) {
                var window = browserWindows[windowIndex]
                var tabs = window.tabs
                tabs.removeAll { $0.id == tab.id }
                browserWindows[windowIndex] = BrowserWindow(
                    id: window.id,
                    browser: window.browser,
                    windowIndex: window.windowIndex,
                    title: window.title,
                    tabs: tabs
                )
            }
            
            return .success
        } catch let error as NSError {
            if error.code == -1743 {
                return .permissionDenied
            }
            return .scriptError(error.localizedDescription)
        }
    }
    
    /// Close all tabs in a window
    func closeAllTabsInWindow(_ window: BrowserWindow) async -> BrowserOperationResult {
        let script: String
        
        switch window.browser {
        case .safari:
            script = """
            tell application "Safari"
                close window \(window.windowIndex)
            end tell
            """
        case .chrome, .edge, .brave:
            script = """
            tell application "\(window.browser.rawValue)"
                close window \(window.windowIndex)
            end tell
            """
        case .arc, .firefox:
            return .unsupported
        }
        
        do {
            _ = try await executeAppleScript(script)
            
            // Remove from local lists
            for tab in window.tabs {
                allTabs.removeAll { $0.id == tab.id }
            }
            browserWindows.removeAll { $0.id == window.id }
            
            return .success
        } catch let error as NSError {
            if error.code == -1743 {
                return .permissionDenied
            }
            return .scriptError(error.localizedDescription)
        }
    }
    
    /// Close all tabs matching a domain
    func closeTabsByDomain(_ domain: String, in browser: BrowserType? = nil) async -> BrowserOperationResult {
        let tabsToClose = allTabs.filter { tab in
            let matchesDomain = tab.domain.contains(domain)
            let matchesBrowser = browser == nil || tab.browser == browser
            return matchesDomain && matchesBrowser
        }
        
        var hasError = false
        
        // Close tabs in reverse order to avoid index shifting issues
        for tab in tabsToClose.reversed() {
            let result = await closeTab(tab)
            if case .permissionDenied = result {
                return .permissionDenied
            }
            if case .scriptError(_) = result {
                hasError = true
            }
            
            // Small delay between operations
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return hasError ? .scriptError("Some tabs could not be closed") : .success
    }
    
    /// Close all tabs except the active one in a browser
    func closeOtherTabs(in browser: BrowserType) async -> BrowserOperationResult {
        let script: String
        
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                set activeTab to current tab of front window
                set tabsToClose to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        if t is not activeTab then
                            set end of tabsToClose to t
                        end if
                    end repeat
                end repeat
                repeat with t in tabsToClose
                    close t
                end repeat
            end tell
            """
        case .chrome, .edge, .brave:
            script = """
            tell application "\(browser.rawValue)"
                set activeTab to active tab of front window
                set activeTabId to id of activeTab
                repeat with w in windows
                    set tabList to tabs of w
                    repeat with i from (count of tabList) to 1 by -1
                        set t to item i of tabList
                        if id of t is not activeTabId then
                            close t
                        end if
                    end repeat
                end repeat
            end tell
            """
        case .arc, .firefox:
            return .unsupported
        }
        
        do {
            _ = try await executeAppleScript(script)
            await fetchAllTabs() // Refresh
            return .success
        } catch let error as NSError {
            if error.code == -1743 {
                return .permissionDenied
            }
            return .scriptError(error.localizedDescription)
        }
    }
    
    /// Close tabs that are memory-heavy (estimated by number of tabs)
    func closeHeavyTabs(limit: Int = 5) async -> BrowserOperationResult {
        // Sort tabs by URL (domains with more tabs = heavier)
        let domainCounts = Dictionary(grouping: allTabs, by: { $0.domain })
        let heavyDomains = domainCounts.sorted { $0.value.count > $1.value.count }
        
        var closedCount = 0
        
        for (_, tabs) in heavyDomains {
            if closedCount >= limit { break }
            
            // Keep at least one tab per domain
            for tab in tabs.dropFirst() {
                if closedCount >= limit { break }
                
                let result = await closeTab(tab)
                if case .success = result {
                    closedCount += 1
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        return .success
    }
    
    // MARK: - AppleScript Generation
    
    private func generateSafariTabsScript() -> String {
        return """
        tell application "Safari"
            set output to ""
            set windowIndex to 1
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    set tabTitle to name of t
                    set tabURL to URL of t
                    set output to output & windowIndex & "|||" & tabIndex & "|||" & tabTitle & "|||" & tabURL & "\\n"
                    set tabIndex to tabIndex + 1
                end repeat
                set windowIndex to windowIndex + 1
            end repeat
            return output
        end tell
        """
    }
    
    private func generateChromiumTabsScript(browser: BrowserType) -> String {
        return """
        tell application "\(browser.rawValue)"
            set output to ""
            set windowIndex to 1
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    set tabTitle to title of t
                    set tabURL to URL of t
                    set output to output & windowIndex & "|||" & tabIndex & "|||" & tabTitle & "|||" & tabURL & "\\n"
                    set tabIndex to tabIndex + 1
                end repeat
                set windowIndex to windowIndex + 1
            end repeat
            return output
        end tell
        """
    }
    
    private func generateSafariCloseTabScript(windowIndex: Int, tabIndex: Int) -> String {
        return """
        tell application "Safari"
            close tab \(tabIndex) of window \(windowIndex)
        end tell
        """
    }
    
    private func generateChromiumCloseTabScript(browser: BrowserType, windowIndex: Int, tabIndex: Int) -> String {
        return """
        tell application "\(browser.rawValue)"
            close tab \(tabIndex) of window \(windowIndex)
        end tell
        """
    }
    
    // MARK: - AppleScript Execution
    
    private func executeAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                
                let result = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                    continuation.resume(throwing: NSError(
                        domain: "AppleScript",
                        code: errorNumber,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    ))
                    return
                }
                
                continuation.resume(returning: result?.stringValue ?? "")
            }
        }
    }
    
    // MARK: - Result Parsing
    
    private func parseTabsResult(_ result: String, browser: BrowserType) -> [BrowserWindow] {
        var windowsDict: [Int: [BrowserTab]] = [:]
        
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 4,
                  let windowIndex = Int(parts[0]),
                  let tabIndex = Int(parts[1]) else { continue }
            
            let title = parts[2]
            let url = parts[3]
            
            let tab = BrowserTab(
                id: "\(browser.rawValue)-\(windowIndex)-\(tabIndex)",
                browser: browser,
                windowIndex: windowIndex,
                tabIndex: tabIndex,
                title: title,
                url: url
            )
            
            if windowsDict[windowIndex] == nil {
                windowsDict[windowIndex] = []
            }
            windowsDict[windowIndex]?.append(tab)
        }
        
        return windowsDict.map { (windowIndex, tabs) in
            BrowserWindow(
                id: "\(browser.rawValue)-\(windowIndex)",
                browser: browser,
                windowIndex: windowIndex,
                title: tabs.first?.title ?? "Window \(windowIndex)",
                tabs: tabs.sorted { $0.tabIndex < $1.tabIndex }
            )
        }.sorted { $0.windowIndex < $1.windowIndex }
    }
    
    // MARK: - Statistics
    
    var totalTabCount: Int {
        allTabs.count
    }
    
    var tabsPerBrowser: [BrowserType: Int] {
        Dictionary(grouping: allTabs, by: { $0.browser })
            .mapValues { $0.count }
    }
    
    var uniqueDomains: Set<String> {
        Set(allTabs.map { $0.domain }.filter { !$0.isEmpty })
    }
    
    func tabsForDomain(_ domain: String) -> [BrowserTab] {
        allTabs.filter { $0.domain.contains(domain) }
    }
}

// MARK: - Permission Checking

extension BrowserAutomationService {
    /// Check if the app has automation permission for a browser
    func checkAutomationPermission(for browser: BrowserType) async -> Bool {
        let testScript = """
        tell application "\(browser.rawValue)"
            return "test"
        end tell
        """
        
        do {
            _ = try await executeAppleScript(testScript)
            return true
        } catch {
            return false
        }
    }
    
    /// Open System Settings to the Automation pane
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
