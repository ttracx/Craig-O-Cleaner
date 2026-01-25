import Foundation

/// Represents a browser tab with its metadata
struct BrowserTab: Identifiable, Hashable {
    let id = UUID()
    let browser: BrowserType
    let title: String
    let url: String
    let windowIndex: Int
    let tabIndex: Int

    enum BrowserType: String, CaseIterable {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case firefox = "Firefox"
        case edge = "Microsoft Edge"
        case brave = "Brave"
        case arc = "Arc"

        var icon: String {
            switch self {
            case .safari: return "safari"
            case .chrome: return "globe"
            case .firefox: return "flame"
            case .edge: return "e.circle"
            case .brave: return "shield"
            case .arc: return "arc.forward"
            }
        }

        var color: String {
            switch self {
            case .safari: return "blue"
            case .chrome: return "green"
            case .firefox: return "orange"
            case .edge: return "blue"
            case .brave: return "orange"
            case .arc: return "purple"
            }
        }
    }

    var isHeavy: Bool {
        // Consider tabs with certain domains as "heavy"
        let heavyDomains = ["youtube.com", "netflix.com", "twitch.tv", "meet.google.com", "zoom.us"]
        return heavyDomains.contains { url.lowercased().contains($0) }
    }

    var memoryEstimate: Int {
        // Rough memory estimate based on tab type
        if isHeavy {
            return 500 // MB
        }
        return 100 // MB
    }
}

/// Browser tab fetcher service
@MainActor
class BrowserTabService: ObservableObject {

    static let shared = BrowserTabService()

    @Published var isLoading = false
    @Published var tabs: [BrowserTab] = []
    @Published var error: String?

    private init() {}

    // MARK: - Fetch Tabs

    func fetchAllTabs() async {
        await Task.yield() // Defer to avoid view update conflicts

        isLoading = true
        error = nil

        var allTabs: [BrowserTab] = []

        // Fetch from each browser in parallel
        await withTaskGroup(of: [BrowserTab].self) { group in
            for browserType in BrowserTab.BrowserType.allCases {
                group.addTask {
                    await self.fetchTabs(for: browserType)
                }
            }

            for await browserTabs in group {
                allTabs.append(contentsOf: browserTabs)
            }
        }

        await Task.yield() // Defer before updating

        tabs = allTabs
        isLoading = false

        print("BrowserTabService: Fetched \(tabs.count) total tabs from all browsers")
        if tabs.isEmpty {
            print("BrowserTabService: ⚠️ No tabs found. Check Automation permissions in System Settings → Privacy & Security → Automation")
        }
    }

    private func fetchTabs(for browser: BrowserTab.BrowserType) async -> [BrowserTab] {
        await Task.detached {
            var tabs: [BrowserTab] = []

            let script: String
            switch browser {
            case .safari:
                script = """
                tell application "Safari"
                    if it is running then
                        set tabList to {}
                        repeat with w from 1 to count of windows
                            repeat with t from 1 to count of tabs of window w
                                set tabTitle to name of tab t of window w
                                set tabURL to URL of tab t of window w
                                set end of tabList to {w, t, tabTitle, tabURL}
                            end repeat
                        end repeat
                        return tabList
                    end if
                end tell
                """

            case .chrome:
                script = """
                tell application "Google Chrome"
                    if it is running then
                        set tabList to {}
                        repeat with w from 1 to count of windows
                            repeat with t from 1 to count of tabs of window w
                                set tabTitle to title of tab t of window w
                                set tabURL to URL of tab t of window w
                                set end of tabList to {w, t, tabTitle, tabURL}
                            end repeat
                        end repeat
                        return tabList
                    end if
                end tell
                """

            default:
                // Other browsers not yet supported
                return []
            }

            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        print("BrowserTabService: \(browser.rawValue) raw output: \(output.prefix(200))")
                        tabs = self.parseTabs(output: output, browser: browser)
                        print("BrowserTabService: Fetched \(tabs.count) tabs from \(browser.rawValue)")
                    }
                } else {
                    let errorData = (task.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile()
                    if let errorOutput = String(data: errorData, encoding: .utf8) {
                        print("BrowserTabService: \(browser.rawValue) error: \(errorOutput)")
                    }
                    print("BrowserTabService: \(browser.rawValue) failed with status \(task.terminationStatus)")
                }
            } catch {
                print("BrowserTabService: Failed to fetch \(browser.rawValue) tabs: \(error)")
            }

            return tabs
        }.value
    }

    nonisolated private func parseTabs(output: String, browser: BrowserTab.BrowserType) -> [BrowserTab] {
        var tabs: [BrowserTab] = []

        // Parse AppleScript list output
        // Format: {windowIndex, tabIndex, "title", "url"}
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Simple parsing - split by commas but respect quoted strings
        var currentTab: [String] = []
        var inQuotes = false
        var current = ""

        for char in cleaned {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                currentTab.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else if char != "{" && char != "}" {
                current.append(char)
            }

            if currentTab.count == 4 {
                if let windowIdx = Int(currentTab[0]),
                   let tabIdx = Int(currentTab[1]) {
                    let title = currentTab[2].replacingOccurrences(of: "\"", with: "")
                    let url = currentTab[3].replacingOccurrences(of: "\"", with: "")

                    tabs.append(BrowserTab(
                        browser: browser,
                        title: title,
                        url: url,
                        windowIndex: windowIdx,
                        tabIndex: tabIdx
                    ))
                }
                currentTab = []
            }
        }

        // Process last item if any
        if !current.isEmpty && !current.trimmingCharacters(in: .whitespaces).isEmpty {
            currentTab.append(current.trimmingCharacters(in: .whitespaces))
        }

        // Process final tab if complete
        if currentTab.count == 4 {
            if let windowIdx = Int(currentTab[0]),
               let tabIdx = Int(currentTab[1]) {
                let title = currentTab[2].replacingOccurrences(of: "\"", with: "")
                let url = currentTab[3].replacingOccurrences(of: "\"", with: "")

                tabs.append(BrowserTab(
                    browser: browser,
                    title: title,
                    url: url,
                    windowIndex: windowIdx,
                    tabIndex: tabIdx
                ))
            }
        }

        return tabs
    }

    // MARK: - Close Tabs

    func closeTabs(_ tabsToClose: [BrowserTab]) async -> Result<Int, Error> {
        await Task.detached {
            var closedCount = 0

            // Group tabs by browser
            let groupedTabs = Dictionary(grouping: tabsToClose) { $0.browser }

            for (browser, tabs) in groupedTabs {
                let script = self.generateCloseScript(for: browser, tabs: tabs)

                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments = ["-e", script]
                task.standardOutput = Pipe()
                task.standardError = Pipe()

                do {
                    try task.run()
                    task.waitUntilExit()

                    if task.terminationStatus == 0 {
                        closedCount += tabs.count
                    }
                } catch {
                    print("BrowserTabService: Failed to close tabs: \(error)")
                }
            }

            return Result.success(closedCount)
        }.value
    }

    nonisolated private func generateCloseScript(for browser: BrowserTab.BrowserType, tabs: [BrowserTab]) -> String {
        // Sort tabs by window and tab index in reverse order
        // This prevents index shifting when closing tabs
        let sortedTabs = tabs.sorted {
            if $0.windowIndex == $1.windowIndex {
                return $0.tabIndex > $1.tabIndex
            }
            return $0.windowIndex > $1.windowIndex
        }

        var script = "tell application \"\(browser.rawValue)\"\n"

        for tab in sortedTabs {
            switch browser {
            case .safari:
                script += "    close tab \(tab.tabIndex) of window \(tab.windowIndex)\n"
            case .chrome:
                script += "    close tab \(tab.tabIndex) of window \(tab.windowIndex)\n"
            default:
                break
            }
        }

        script += "end tell"
        return script
    }

    // MARK: - Helpers

    func filterHeavyTabs() -> [BrowserTab] {
        tabs.filter { $0.isHeavy }
    }

    func totalMemoryEstimate() -> Int {
        tabs.reduce(0) { $0 + $1.memoryEstimate }
    }
}
