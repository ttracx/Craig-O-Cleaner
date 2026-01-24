import Foundation

// MARK: - Cleanup Agent
/// Specialized agent for system cleanup operations
/// Handles memory purging, cache cleaning, and disk cleanup

@MainActor
public final class CleanupAgent: BaseAgent {

    // MARK: - Properties

    private let memoryManager = MemoryManager()
    private let cacheManager = CacheManager()
    private let diskManager = DiskManager()

    // MARK: - Initialization

    public init() {
        super.init(
            name: "CleanupAgent",
            description: "Specialized agent for memory, cache, and disk cleanup operations"
        )
    }

    // MARK: - Registration

    public override func registerTools() async {
        addTool(PurgeMemoryTool(memoryManager: memoryManager))
        addTool(ClearCachesTool(cacheManager: cacheManager))
        addTool(CleanTemporaryFilesTool(diskManager: diskManager))
        addTool(EmptyTrashTool(diskManager: diskManager))
        addTool(FlushDNSTool(executor: executor))
    }

    public override func registerSkills() async {
        addSkill(MemoryCleanupSkill())
        addSkill(CacheCleanupSkill())
        addSkill(DiskCleanupSkill())
        addSkill(ComprehensiveCleanupSkill())
    }

    // MARK: - Task Execution

    public override func performTask(_ task: AgentTask) async throws -> AnySendable? {
        log(.info, "Performing cleanup task: \(task.type.rawValue)")

        switch task.type {
        case .cleanup:
            return try await performCleanup(task)
        case .maintenance:
            return try await performMaintenance(task)
        default:
            throw AgentError.taskFailed("Unsupported task type: \(task.type)")
        }
    }

    private func performCleanup(_ task: AgentTask) async throws -> AnySendable {
        var results: [String: Any] = [:]

        // Check what to clean
        let cleanMemory = task.parameters["cleanMemory"]?.get() as? Bool ?? true
        let cleanCaches = task.parameters["cleanCaches"]?.get() as? Bool ?? true
        let cleanTemp = task.parameters["cleanTemp"]?.get() as? Bool ?? true
        let emptyTrash = task.parameters["emptyTrash"]?.get() as? Bool ?? false

        if cleanMemory {
            log(.info, "Purging memory...")
            let memResult = try await memoryManager.purgeInactiveMemory()
            results["memoryFreed"] = memResult.memoryFreed
        }

        if cleanCaches {
            log(.info, "Clearing caches...")
            let cacheResult = try await cacheManager.clearUserCaches()
            results["cacheSpaceFreed"] = cacheResult.spaceFreed
        }

        if cleanTemp {
            log(.info, "Cleaning temporary files...")
            let tempResult = try await diskManager.cleanTemporaryFiles()
            results["tempSpaceFreed"] = tempResult.spaceFreed
        }

        if emptyTrash {
            log(.info, "Emptying trash...")
            let trashResult = try await diskManager.emptyTrash()
            results["trashSpaceFreed"] = trashResult.spaceFreed
        }

        log(.info, "Cleanup completed successfully")
        return AnySendable(results)
    }

    private func performMaintenance(_ task: AgentTask) async throws -> AnySendable {
        log(.info, "Performing system maintenance...")

        // Run full cleanup
        let cleanupResult = try await performCleanup(task)

        // Flush DNS
        log(.info, "Flushing DNS cache...")
        _ = try await executor.executePrivileged(
            "dscacheutil -flushcache && killall -HUP mDNSResponder"
        )

        return cleanupResult
    }

    // MARK: - Custom Commands

    /// Perform quick cleanup
    public func quickCleanup() async throws -> [String: UInt64] {
        log(.info, "Starting quick cleanup...")

        let memResult = try await memoryManager.purgeInactiveMemory()
        let tempResult = try await diskManager.cleanTemporaryFiles()

        return [
            "memoryFreed": memResult.memoryFreed,
            "diskSpaceFreed": tempResult.spaceFreed
        ]
    }

    /// Perform deep cleanup
    public func deepCleanup() async throws -> [String: UInt64] {
        log(.info, "Starting deep cleanup...")

        let memResult = try await memoryManager.purgeInactiveMemory()
        let cacheResult = try await cacheManager.clearAllCaches(
            includeSystem: false,
            includeBrowsers: true,
            includeDeveloper: true
        )
        let tempResult = try await diskManager.cleanTemporaryFiles()
        let trashResult = try await diskManager.emptyTrash()

        return [
            "memoryFreed": memResult.memoryFreed,
            "cacheSpaceFreed": cacheResult.spaceFreed,
            "tempSpaceFreed": tempResult.spaceFreed,
            "trashSpaceFreed": trashResult.spaceFreed
        ]
    }
}

// MARK: - Cleanup Tools

public struct PurgeMemoryTool: AgentTool {
    public let name = "purge_memory"
    public let description = "Purge inactive memory and disk caches"
    public let parameters: [ToolParameter] = []

    private let memoryManager: MemoryManager

    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let result = try await memoryManager.purgeInactiveMemory()
        return ToolResult(
            success: true,
            output: AnySendable(["memoryFreed": result.memoryFreed]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct ClearCachesTool: AgentTool {
    public let name = "clear_caches"
    public let description = "Clear user and application caches"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "includeBrowsers", type: .bool, description: "Include browser caches", required: false, defaultValue: AnySendable(true)),
        ToolParameter(name: "includeDeveloper", type: .bool, description: "Include developer caches", required: false, defaultValue: AnySendable(false))
    ]

    private let cacheManager: CacheManager

    init(cacheManager: CacheManager) {
        self.cacheManager = cacheManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let includeBrowsers = parameters["includeBrowsers"]?.get() as? Bool ?? true
        let includeDeveloper = parameters["includeDeveloper"]?.get() as? Bool ?? false

        let result = try await cacheManager.clearAllCaches(
            includeSystem: false,
            includeBrowsers: includeBrowsers,
            includeDeveloper: includeDeveloper
        )

        return ToolResult(
            success: true,
            output: AnySendable(["spaceFreed": result.spaceFreed, "cacheCount": result.cacheCount]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct CleanTemporaryFilesTool: AgentTool {
    public let name = "clean_temp_files"
    public let description = "Clean temporary files and system temp directories"
    public let parameters: [ToolParameter] = []

    private let diskManager: DiskManager

    init(diskManager: DiskManager) {
        self.diskManager = diskManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let result = try await diskManager.cleanTemporaryFiles()

        return ToolResult(
            success: true,
            output: AnySendable(["spaceFreed": result.spaceFreed]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct EmptyTrashTool: AgentTool {
    public let name = "empty_trash"
    public let description = "Empty the user's trash"
    public let parameters: [ToolParameter] = []

    private let diskManager: DiskManager

    init(diskManager: DiskManager) {
        self.diskManager = diskManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let result = try await diskManager.emptyTrash()

        return ToolResult(
            success: true,
            output: AnySendable(["spaceFreed": result.spaceFreed]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct FlushDNSTool: AgentTool {
    public let name = "flush_dns"
    public let description = "Flush DNS cache"
    public let parameters: [ToolParameter] = []

    private let executor: CommandExecutor

    init(executor: CommandExecutor) {
        self.executor = executor
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        _ = try await executor.executePrivileged(
            "dscacheutil -flushcache && killall -HUP mDNSResponder"
        )

        return ToolResult(
            success: true,
            output: AnySendable("DNS cache flushed"),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

// MARK: - Cleanup Skills

public struct MemoryCleanupSkill: AgentSkill {
    public let name = "Memory Cleanup"
    public let description = "Purge inactive memory and optimize memory usage"
    public let category = SkillCategory.cleanup
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .cleanup &&
        (task.description.lowercased().contains("memory") ||
         task.parameters["cleanMemory"]?.get() as? Bool == true)
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "purge_memory" }) else {
            throw AgentError.toolNotFound("purge_memory")
        }

        let result = try await tool.execute(with: [:])

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}

public struct CacheCleanupSkill: AgentSkill {
    public let name = "Cache Cleanup"
    public let description = "Clear various system and application caches"
    public let category = SkillCategory.cleanup
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .cleanup &&
        (task.description.lowercased().contains("cache") ||
         task.parameters["cleanCaches"]?.get() as? Bool == true)
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "clear_caches" }) else {
            throw AgentError.toolNotFound("clear_caches")
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

public struct DiskCleanupSkill: AgentSkill {
    public let name = "Disk Cleanup"
    public let description = "Clean temporary files and free disk space"
    public let category = SkillCategory.cleanup
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .cleanup &&
        (task.description.lowercased().contains("disk") ||
         task.description.lowercased().contains("temp") ||
         task.parameters["cleanTemp"]?.get() as? Bool == true)
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "clean_temp_files" }) else {
            throw AgentError.toolNotFound("clean_temp_files")
        }

        let result = try await tool.execute(with: [:])

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}

public struct ComprehensiveCleanupSkill: AgentSkill {
    public let name = "Comprehensive Cleanup"
    public let description = "Perform full system cleanup including memory, caches, and disk"
    public let category = SkillCategory.cleanup
    public let proficiency = SkillProficiency.master

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .cleanup &&
        (task.description.lowercased().contains("full") ||
         task.description.lowercased().contains("comprehensive") ||
         task.description.lowercased().contains("all"))
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()
        var combinedOutput: [String: Any] = [:]

        for tool in tools {
            let result = try await tool.execute(with: task.parameters)
            if let output = result.output?.get() as? [String: Any] {
                combinedOutput.merge(output) { _, new in new }
            }
        }

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: .success,
            output: AnySendable(combinedOutput),
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}
