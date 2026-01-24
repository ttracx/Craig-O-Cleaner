import Foundation

// MARK: - Browser Manager
/// Comprehensive browser tab and process management for macOS
/// Supports Safari, Chrome, Firefox, Edge, Brave, Arc, Opera

@MainActor
public final class BrowserManager: ObservableObject {

    // MARK: - Types

    public enum Browser: String, CaseIterable, Sendable {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case firefox = "Firefox"
        case edge = "Microsoft Edge"
        case brave = "Brave Browser"
        case arc = "Arc"
        case opera = "Opera"

        public var processName: String {
            switch self {
            case .safari: return "Safari"
            case .chrome: return "Google Chrome"
            case .firefox: return "firefox"
            case .edge: return "Microsoft Edge"
            case .brave: return "Brave Browser"
            case .arc: return "Arc"
            case .opera: return "Opera"
            }
        }

        public var helperProcessName: String? {
            switch self {
            case .chrome: return "Google Chrome Helper"
            case .edge: return "Microsoft Edge Helper"
            case .brave: return "Brave Browser Helper"
            case .arc: return "Arc Helper"
            case .safari, .firefox, .opera: return nil
            }
        }

        public var cachePath: String {
            switch self {
            case .safari: return "~/Library/Caches/com.apple.Safari"
            case .chrome: return "~/Library/Caches/Google/Chrome"
            case .firefox: return "~/Library/Caches/Firefox"
            case .edge: return "~/Library/Caches/Microsoft Edge"
            case .brave: return "~/Library/Caches/BraveSoftware"
            case .arc: return "~/Library/Caches/company.thebrowser.Browser"
            case .opera: return "~/Library/Caches/com.operasoftware.Opera"
            }
        }

        public var supportsAppleScript: Bool {
            switch self {
            case .firefox: return false // Limited support
            default: return true
            }
        }
    }

    public struct BrowserTab: Identifiable, Sendable {
        public let id = UUID()
        public let browser: Browser
        public let windowIndex: Int
        public let tabIndex: Int
        public let title: String
        public let url: String
        public let estimatedMemoryMB: Double?

        public var domain: String {
            guard let url = URL(string: url) else { return "" }
            return url.host ?? ""
        }
    }

    public struct BrowserProcess: Sendable {
        public let browser: Browser
        public let pid: Int
        public let memoryMB: Double
        public let cpuPercent: Double
        public let isHelper: Bool
        public let processType: String
    }

    public struct TabCleanupResult {
        public let browser: Browser
        public let tabsClosed: Int
        public let error: String?
    }

    public struct BrowserCleanupResult {
        public let tabsClosed: Int
        public let memorySaved: UInt64
        public let browsersAffected: [Browser]
        public let results: [TabCleanupResult]
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var runningBrowsers: [Browser] = []
    @Published public private(set) var tabs: [BrowserTab] = []
    @Published public private(set) var browserProcesses: [BrowserProcess] = []

    // MARK: - Browser Detection

    /// Get list of running browsers
    public func getRunningBrowsers() async -> [Browser] {
        var running: [Browser] = []

        for browser in Browser.allCases {
            let result = try? await executor.execute("pgrep -x \"\(browser.processName)\" 2>/dev/null")
            if result?.isSuccess == true && !result!.output.isEmpty {
                running.append(browser)
            }
        }

        runningBrowsers = running
        return running
    }

    /// Check if a specific browser is running
    public func isRunning(_ browser: Browser) async -> Bool {
        let result = try? await executor.execute("pgrep -x \"\(browser.processName)\" 2>/dev/null")
        return result?.isSuccess == true && !result!.output.isEmpty
    }

    // MARK: - Tab Management

    /// Get all tabs from a browser
    public func getTabs(from browser: Browser) async throws -> [BrowserTab] {
        guard browser.supportsAppleScript else {
            return [] // Firefox has limited AppleScript support
        }

        let script = tabListScript(for: browser)
        let result = try await executor.executeAppleScriptBlock(script)

        guard result.isSuccess else {
            throw CommandExecutor.CommandError.executionFailed(result.error)
        }

        return parseTabOutput(result.output, browser: browser)
    }

    /// Get all tabs from all running browsers
    public func getAllTabs() async -> [BrowserTab] {
        let browsers = await getRunningBrowsers()
        var allTabs: [BrowserTab] = []

        for browser in browsers {
            if let tabs = try? await getTabs(from: browser) {
                allTabs.append(contentsOf: tabs)
            }
        }

        self.tabs = allTabs
        return allTabs
    }

    /// Get total tab count across all browsers
    public func getTotalTabCount() async -> Int {
        let browsers = await getRunningBrowsers()
        var total = 0

        for browser in browsers {
            if let count = try? await getTabCount(for: browser) {
                total += count
            }
        }

        return total
    }

    /// Get tab count for a specific browser
    public func getTabCount(for browser: Browser) async throws -> Int {
        guard browser.supportsAppleScript else { return 0 }

        let script: String
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                set tabCount to 0
                repeat with w in windows
                    set tabCount to tabCount + (count of tabs of w)
                end repeat
                return tabCount
            end tell
            """
        default:
            script = """
            tell application "\(browser.rawValue)"
                set tabCount to 0
                repeat with w in windows
                    set tabCount to tabCount + (count of tabs of w)
                end repeat
                return tabCount
            end tell
            """
        }

        let result = try await executor.executeAppleScriptBlock(script)
        return Int(result.output) ?? 0
    }

    /// Close a specific tab
    public func closeTab(_ tab: BrowserTab) async throws {
        let script = """
        tell application "\(tab.browser.rawValue)"
            close tab \(tab.tabIndex) of window \(tab.windowIndex)
        end tell
        """
        _ = try await executor.executeAppleScriptBlock(script)
    }

    /// Close all tabs matching a domain
    public func closeTabsByDomain(_ domain: String, in browser: Browser) async throws -> Int {
        let script = """
        tell application "\(browser.rawValue)"
            set closedCount to 0
            repeat with w in windows
                set tabList to tabs of w
                repeat with t in tabList
                    if URL of t contains "\(domain)" then
                        close t
                        set closedCount to closedCount + 1
                    end if
                end repeat
            end repeat
            return closedCount
        end tell
        """

        let result = try await executor.executeAppleScriptBlock(script)
        return Int(result.output) ?? 0
    }

    /// Close all tabs in a browser
    public func closeAllTabs(in browser: Browser) async throws {
        let script = """
        tell application "\(browser.rawValue)"
            close every tab of every window
        end tell
        """
        _ = try await executor.executeAppleScriptBlock(script)
    }

    /// Close all windows for a browser
    public func closeAllWindows(in browser: Browser) async throws {
        let script = """
        tell application "\(browser.rawValue)"
            close every window
        end tell
        """
        _ = try await executor.executeAppleScriptBlock(script)
    }

    // MARK: - Resource Management

    /// Get browser processes with memory info
    public func getBrowserProcesses() async -> [BrowserProcess] {
        var processes: [BrowserProcess] = []

        for browser in Browser.allCases {
            // Main process
            let mainResult = try? await executor.execute(
                "ps aux | grep -i \"\(browser.processName)\" | grep -v grep | grep -v Helper"
            )

            if let output = mainResult?.output, !output.isEmpty {
                for line in output.components(separatedBy: .newlines) {
                    if let process = parseBrowserProcess(line, browser: browser, isHelper: false) {
                        processes.append(process)
                    }
                }
            }

            // Helper processes
            if let helperName = browser.helperProcessName {
                let helperResult = try? await executor.execute(
                    "ps aux | grep \"\(helperName)\" | grep -v grep"
                )

                if let output = helperResult?.output, !output.isEmpty {
                    for line in output.components(separatedBy: .newlines) {
                        if let process = parseBrowserProcess(line, browser: browser, isHelper: true) {
                            processes.append(process)
                        }
                    }
                }
            }
        }

        browserProcesses = processes
        return processes
    }

    /// Get resource-heavy browser processes
    public func getResourceHeavyProcesses(memoryThresholdMB: Double = 500) async -> [BrowserProcess] {
        let processes = await getBrowserProcesses()
        return processes.filter { $0.memoryMB >= memoryThresholdMB }
    }

    /// Close all resource-heavy tabs
    public func closeAllResourceHeavyTabs(memoryThresholdMB: Double = 500) async throws -> BrowserCleanupResult {
        let heavyProcesses = await getResourceHeavyProcesses(memoryThresholdMB: memoryThresholdMB)
        var totalClosed = 0
        var memorySaved: UInt64 = 0
        var results: [TabCleanupResult] = []
        var affectedBrowsers: Set<Browser> = []

        // Kill heavy helper processes (these are individual tabs in Chromium browsers)
        for process in heavyProcesses where process.isHelper {
            _ = try? await executor.execute("kill -9 \(process.pid)")
            totalClosed += 1
            memorySaved += UInt64(process.memoryMB * 1024 * 1024)
            affectedBrowsers.insert(process.browser)
        }

        for browser in affectedBrowsers {
            results.append(TabCleanupResult(
                browser: browser,
                tabsClosed: heavyProcesses.filter { $0.browser == browser && $0.isHelper }.count,
                error: nil
            ))
        }

        return BrowserCleanupResult(
            tabsClosed: totalClosed,
            memorySaved: memorySaved,
            browsersAffected: Array(affectedBrowsers),
            results: results
        )
    }

    // MARK: - Browser Control

    /// Quit browser gracefully
    public func quitBrowser(_ browser: Browser) async throws {
        let script = "tell application \"\(browser.rawValue)\" to quit"
        _ = try await executor.executeAppleScript(script)
    }

    /// Force quit browser
    public func forceQuitBrowser(_ browser: Browser) async throws {
        _ = try await executor.execute("killall -9 \"\(browser.processName)\"")
    }

    /// Quit all browsers
    public func quitAllBrowsers(force: Bool = false) async {
        let browsers = await getRunningBrowsers()

        for browser in browsers {
            if force {
                _ = try? await forceQuitBrowser(browser)
            } else {
                _ = try? await quitBrowser(browser)
            }
        }
    }

    /// Open browser
    public func openBrowser(_ browser: Browser) async throws {
        _ = try await executor.execute("open -a \"\(browser.rawValue)\"")
    }

    /// Open URL in browser
    public func openURL(_ urlString: String, in browser: Browser) async throws {
        let script = """
        tell application "\(browser.rawValue)"
            activate
            open location "\(urlString)"
        end tell
        """
        _ = try await executor.executeAppleScriptBlock(script)
    }

    // MARK: - Cache Management

    /// Clear browser cache
    public func clearCache(for browser: Browser) async throws {
        let path = (browser.cachePath as NSString).expandingTildeInPath
        _ = try await executor.execute("rm -rf \"\(path)\"/*")
    }

    /// Clear all browser caches
    public func clearAllBrowserCaches() async throws {
        for browser in Browser.allCases {
            _ = try? await clearCache(for: browser)
        }
    }

    /// Get cache size for browser
    public func getCacheSize(for browser: Browser) async -> UInt64 {
        let path = (browser.cachePath as NSString).expandingTildeInPath
        let result = try? await executor.execute("du -sk \"\(path)\" 2>/dev/null | cut -f1")

        guard let output = result?.output, let kb = UInt64(output.trimmingCharacters(in: .whitespaces)) else {
            return 0
        }

        return kb * 1024 // Return bytes
    }

    // MARK: - Private Helpers

    private func tabListScript(for browser: Browser) -> String {
        switch browser {
        case .safari:
            return """
            tell application "Safari"
                set output to ""
                set windowIndex to 1
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        set output to output & windowIndex & "|||" & tabIndex & "|||" & (name of t) & "|||" & (URL of t) & "\\n"
                        set tabIndex to tabIndex + 1
                    end repeat
                    set windowIndex to windowIndex + 1
                end repeat
                return output
            end tell
            """
        case .chrome, .edge, .brave:
            return """
            tell application "\(browser.rawValue)"
                set output to ""
                set windowIndex to 1
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        set output to output & windowIndex & "|||" & tabIndex & "|||" & (title of t) & "|||" & (URL of t) & "\\n"
                        set tabIndex to tabIndex + 1
                    end repeat
                    set windowIndex to windowIndex + 1
                end repeat
                return output
            end tell
            """
        case .arc:
            return """
            tell application "Arc"
                set output to ""
                set windowIndex to 1
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        set output to output & windowIndex & "|||" & tabIndex & "|||" & (title of t) & "|||" & (URL of t) & "\\n"
                        set tabIndex to tabIndex + 1
                    end repeat
                    set windowIndex to windowIndex + 1
                end repeat
                return output
            end tell
            """
        case .opera:
            return """
            tell application "Opera"
                set output to ""
                set windowIndex to 1
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        set output to output & windowIndex & "|||" & tabIndex & "|||" & (title of t) & "|||" & (URL of t) & "\\n"
                        set tabIndex to tabIndex + 1
                    end repeat
                    set windowIndex to windowIndex + 1
                end repeat
                return output
            end tell
            """
        case .firefox:
            return "" // Firefox doesn't support this level of AppleScript
        }
    }

    private func parseTabOutput(_ output: String, browser: Browser) -> [BrowserTab] {
        var tabs: [BrowserTab] = []

        for line in output.components(separatedBy: "\\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|||")
            guard parts.count >= 4 else { continue }

            let windowIndex = Int(parts[0]) ?? 1
            let tabIndex = Int(parts[1]) ?? 1
            let title = parts[2]
            let url = parts[3]

            tabs.append(BrowserTab(
                browser: browser,
                windowIndex: windowIndex,
                tabIndex: tabIndex,
                title: title,
                url: url,
                estimatedMemoryMB: nil
            ))
        }

        return tabs
    }

    private func parseBrowserProcess(_ line: String, browser: Browser, isHelper: Bool) -> BrowserProcess? {
        let components = line.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard components.count >= 11 else { return nil }

        guard let pid = Int(components[1]) else { return nil }
        let cpu = Double(components[2]) ?? 0
        let rss = Double(components[5]) ?? 0
        let memoryMB = rss / 1024.0

        var processType = "Main"
        if isHelper {
            if line.contains("Renderer") { processType = "Renderer/Tab" }
            else if line.contains("GPU") { processType = "GPU" }
            else if line.contains("Network") { processType = "Network" }
            else { processType = "Helper" }
        }

        return BrowserProcess(
            browser: browser,
            pid: pid,
            memoryMB: memoryMB,
            cpuPercent: cpu,
            isHelper: isHelper,
            processType: processType
        )
    }
}

// MARK: - Browser Commands Reference

public enum BrowserCommands {

    // Force quit
    public static func forceQuit(_ browser: BrowserManager.Browser) -> String {
        "killall -9 \"\(browser.processName)\""
    }

    public static let forceQuitAll = """
        killall Safari "Google Chrome" Firefox "Microsoft Edge" "Brave Browser" Arc Opera 2>/dev/null
        """

    // Cache clearing
    public static func clearCache(_ browser: BrowserManager.Browser) -> String {
        "rm -rf \(browser.cachePath)/*"
    }

    // Process info
    public static func getProcesses(_ browser: BrowserManager.Browser) -> String {
        "ps aux | grep -i \"\(browser.processName)\" | sort -k4 -rn"
    }

    // Kill helpers by memory threshold
    public static func killHeavyHelpers(browser: BrowserManager.Browser, memoryThresholdPercent: Double) -> String {
        guard let helper = browser.helperProcessName else { return "" }
        return "ps aux | grep \"\(helper)\" | awk '$4 > \(memoryThresholdPercent) {print $2}' | xargs kill -9 2>/dev/null"
    }
}
