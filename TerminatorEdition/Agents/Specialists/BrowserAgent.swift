import Foundation

// MARK: - Browser Agent
/// Specialized agent for browser management
/// Handles tab management, resource monitoring, and cache cleaning for all browsers

@MainActor
public final class BrowserAgent: BaseAgent {

    // MARK: - Properties

    private let browserManager = BrowserManager()

    // MARK: - Initialization

    public init() {
        super.init(
            name: "BrowserAgent",
            description: "Specialized agent for browser tab and resource management"
        )
    }

    // MARK: - Registration

    public override func registerTools() async {
        addTool(ListBrowsersTool(browserManager: browserManager))
        addTool(GetTabsTool(browserManager: browserManager))
        addTool(CloseTabTool(browserManager: browserManager))
        addTool(CloseTabsByDomainTool(browserManager: browserManager))
        addTool(CloseResourceHeavyTabsTool(browserManager: browserManager))
        addTool(QuitBrowserTool(browserManager: browserManager))
        addTool(ClearBrowserCacheTool(browserManager: browserManager))
    }

    public override func registerSkills() async {
        addSkill(TabManagementSkill())
        addSkill(BrowserResourceOptimizationSkill())
        addSkill(BrowserCleanupSkill())
    }

    // MARK: - Task Execution

    public override func performTask(_ task: AgentTask) async throws -> AnySendable? {
        log(.info, "Performing browser task: \(task.type.rawValue)")

        switch task.type {
        case .browserManagement:
            return try await performBrowserManagement(task)
        case .cleanup:
            return try await performBrowserCleanup(task)
        case .optimization:
            return try await performBrowserOptimization(task)
        default:
            throw AgentError.taskFailed("Unsupported task type: \(task.type)")
        }
    }

    private func performBrowserManagement(_ task: AgentTask) async throws -> AnySendable {
        let action = task.parameters["action"]?.get() as? String ?? "list"

        switch action {
        case "list":
            let browsers = await browserManager.getRunningBrowsers()
            return AnySendable(browsers.map { $0.rawValue })

        case "getTabs":
            let tabs = await browserManager.getAllTabs()
            return AnySendable(tabs.map { [
                "browser": $0.browser.rawValue,
                "title": $0.title,
                "url": $0.url,
                "domain": $0.domain
            ]})

        case "closeTabs":
            if let domain = task.parameters["domain"]?.get() as? String,
               let browserName = task.parameters["browser"]?.get() as? String,
               let browser = BrowserManager.Browser(rawValue: browserName) {
                let count = try await browserManager.closeTabsByDomain(domain, in: browser)
                return AnySendable(["closedCount": count])
            }

        case "quit":
            if let browserName = task.parameters["browser"]?.get() as? String,
               let browser = BrowserManager.Browser(rawValue: browserName) {
                let force = task.parameters["force"]?.get() as? Bool ?? false
                if force {
                    try await browserManager.forceQuitBrowser(browser)
                } else {
                    try await browserManager.quitBrowser(browser)
                }
                return AnySendable("Browser quit: \(browserName)")
            }

        default:
            break
        }

        throw AgentError.invalidParameters
    }

    private func performBrowserCleanup(_ task: AgentTask) async throws -> AnySendable {
        log(.info, "Cleaning browser caches...")

        try await browserManager.clearAllBrowserCaches()

        return AnySendable("Browser caches cleared")
    }

    private func performBrowserOptimization(_ task: AgentTask) async throws -> AnySendable {
        let memoryThreshold = task.parameters["memoryThreshold"]?.get() as? Double ?? 500

        log(.info, "Optimizing browsers - closing tabs using more than \(memoryThreshold)MB...")

        let result = try await browserManager.closeAllResourceHeavyTabs(memoryThresholdMB: memoryThreshold)

        return AnySendable([
            "tabsClosed": result.tabsClosed,
            "memorySaved": result.memorySaved,
            "browsersAffected": result.browsersAffected.map { $0.rawValue }
        ])
    }

    // MARK: - Public API

    /// Get tab count for all browsers
    public func getTotalTabCount() async -> Int {
        await browserManager.getTotalTabCount()
    }

    /// Close all resource-heavy tabs
    public func optimizeBrowserMemory(threshold: Double = 500) async throws -> BrowserManager.BrowserCleanupResult {
        try await browserManager.closeAllResourceHeavyTabs(memoryThresholdMB: threshold)
    }

    /// Get resource-heavy browser processes
    public func getResourceHeavyProcesses() async -> [BrowserManager.BrowserProcess] {
        await browserManager.getResourceHeavyProcesses()
    }
}

// MARK: - Browser Tools

public struct ListBrowsersTool: AgentTool {
    public let name = "list_browsers"
    public let description = "List all running browsers"
    public let parameters: [ToolParameter] = []

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let browsers = await browserManager.getRunningBrowsers()

        return ToolResult(
            success: true,
            output: AnySendable(browsers.map { $0.rawValue }),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct GetTabsTool: AgentTool {
    public let name = "get_tabs"
    public let description = "Get all tabs from running browsers"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "browser", type: .string, description: "Specific browser (optional)", required: false)
    ]

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        let tabs: [BrowserManager.BrowserTab]
        if let browserName = parameters["browser"]?.get() as? String,
           let browser = BrowserManager.Browser(rawValue: browserName) {
            tabs = try await browserManager.getTabs(from: browser)
        } else {
            tabs = await browserManager.getAllTabs()
        }

        let output = tabs.map { [
            "browser": $0.browser.rawValue,
            "title": $0.title,
            "url": $0.url,
            "domain": $0.domain,
            "windowIndex": $0.windowIndex,
            "tabIndex": $0.tabIndex
        ]}

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct CloseTabTool: AgentTool {
    public let name = "close_tab"
    public let description = "Close a specific browser tab"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "browser", type: .string, description: "Browser name", required: true),
        ToolParameter(name: "windowIndex", type: .int, description: "Window index", required: true),
        ToolParameter(name: "tabIndex", type: .int, description: "Tab index", required: true)
    ]

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let browserName = parameters["browser"]?.get() as? String,
              let browser = BrowserManager.Browser(rawValue: browserName),
              let windowIndex = parameters["windowIndex"]?.get() as? Int,
              let tabIndex = parameters["tabIndex"]?.get() as? Int else {
            return ToolResult(success: false, error: "Missing required parameters")
        }

        let tab = BrowserManager.BrowserTab(
            browser: browser,
            windowIndex: windowIndex,
            tabIndex: tabIndex,
            title: "",
            url: "",
            estimatedMemoryMB: nil
        )

        try await browserManager.closeTab(tab)

        return ToolResult(
            success: true,
            output: AnySendable("Tab closed"),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct CloseTabsByDomainTool: AgentTool {
    public let name = "close_tabs_by_domain"
    public let description = "Close all tabs matching a domain"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "domain", type: .string, description: "Domain to match", required: true),
        ToolParameter(name: "browser", type: .string, description: "Browser name", required: true)
    ]

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let domain = parameters["domain"]?.get() as? String,
              let browserName = parameters["browser"]?.get() as? String,
              let browser = BrowserManager.Browser(rawValue: browserName) else {
            return ToolResult(success: false, error: "Missing required parameters")
        }

        let count = try await browserManager.closeTabsByDomain(domain, in: browser)

        return ToolResult(
            success: true,
            output: AnySendable(["closedCount": count]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct CloseResourceHeavyTabsTool: AgentTool {
    public let name = "close_heavy_tabs"
    public let description = "Close tabs using excessive memory"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "memoryThresholdMB", type: .double, description: "Memory threshold in MB", required: false, defaultValue: AnySendable(500.0))
    ]

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let threshold = parameters["memoryThresholdMB"]?.get() as? Double ?? 500.0

        let result = try await browserManager.closeAllResourceHeavyTabs(memoryThresholdMB: threshold)

        return ToolResult(
            success: true,
            output: AnySendable([
                "tabsClosed": result.tabsClosed,
                "memorySaved": result.memorySaved
            ]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct QuitBrowserTool: AgentTool {
    public let name = "quit_browser"
    public let description = "Quit a browser (gracefully or forcefully)"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "browser", type: .string, description: "Browser name", required: true),
        ToolParameter(name: "force", type: .bool, description: "Force quit", required: false, defaultValue: AnySendable(false))
    ]

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let browserName = parameters["browser"]?.get() as? String,
              let browser = BrowserManager.Browser(rawValue: browserName) else {
            return ToolResult(success: false, error: "Invalid browser name")
        }

        let force = parameters["force"]?.get() as? Bool ?? false

        if force {
            try await browserManager.forceQuitBrowser(browser)
        } else {
            try await browserManager.quitBrowser(browser)
        }

        return ToolResult(
            success: true,
            output: AnySendable("Browser quit: \(browserName)"),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct ClearBrowserCacheTool: AgentTool {
    public let name = "clear_browser_cache"
    public let description = "Clear browser cache"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "browser", type: .string, description: "Browser name (optional, clears all if not specified)", required: false)
    ]

    private let browserManager: BrowserManager

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        if let browserName = parameters["browser"]?.get() as? String,
           let browser = BrowserManager.Browser(rawValue: browserName) {
            try await browserManager.clearCache(for: browser)
        } else {
            try await browserManager.clearAllBrowserCaches()
        }

        return ToolResult(
            success: true,
            output: AnySendable("Browser cache cleared"),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

// MARK: - Browser Skills

public struct TabManagementSkill: AgentSkill {
    public let name = "Tab Management"
    public let description = "Manage browser tabs across all browsers"
    public let category = SkillCategory.browserManagement
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .browserManagement &&
        (task.description.lowercased().contains("tab") ||
         task.parameters["action"]?.get() as? String == "getTabs" ||
         task.parameters["action"]?.get() as? String == "closeTabs")
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        let action = task.parameters["action"]?.get() as? String ?? "getTabs"

        let tool: AgentTool?
        switch action {
        case "getTabs":
            tool = tools.first { $0.name == "get_tabs" }
        case "closeTabs":
            tool = tools.first { $0.name == "close_tabs_by_domain" }
        default:
            tool = tools.first { $0.name == "get_tabs" }
        }

        guard let selectedTool = tool else {
            throw AgentError.toolNotFound(action)
        }

        let result = try await selectedTool.execute(with: task.parameters)

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}

public struct BrowserResourceOptimizationSkill: AgentSkill {
    public let name = "Browser Resource Optimization"
    public let description = "Optimize browser memory usage by closing heavy tabs"
    public let category = SkillCategory.optimization
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .optimization &&
        (task.description.lowercased().contains("browser") ||
         task.description.lowercased().contains("tab"))
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "close_heavy_tabs" }) else {
            throw AgentError.toolNotFound("close_heavy_tabs")
        }

        let result = try await tool.execute(with: task.parameters)

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}

public struct BrowserCleanupSkill: AgentSkill {
    public let name = "Browser Cleanup"
    public let description = "Clean browser caches and data"
    public let category = SkillCategory.cleanup
    public let proficiency = SkillProficiency.advanced

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .cleanup &&
        task.description.lowercased().contains("browser")
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "clear_browser_cache" }) else {
            throw AgentError.toolNotFound("clear_browser_cache")
        }

        let result = try await tool.execute(with: task.parameters)

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}
