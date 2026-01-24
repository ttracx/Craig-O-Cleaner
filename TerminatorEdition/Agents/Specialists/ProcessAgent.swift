import Foundation

// MARK: - Process Agent
/// Specialized agent for process management
/// Handles process monitoring, termination, and launch agent management

@MainActor
public final class ProcessAgent: BaseAgent {

    // MARK: - Properties

    private let processManager = ProcessManager()

    // MARK: - Initialization

    public init() {
        super.init(
            name: "ProcessAgent",
            description: "Specialized agent for process monitoring and management"
        )
    }

    // MARK: - Registration

    public override func registerTools() async {
        addTool(ListProcessesTool(processManager: processManager))
        addTool(FindProcessTool(processManager: processManager))
        addTool(KillProcessTool(processManager: processManager))
        addTool(KillAllByNameTool(processManager: processManager))
        addTool(ForceQuitAppTool(processManager: processManager))
        addTool(ListLaunchAgentsTool(processManager: processManager))
        addTool(ManageLaunchAgentTool(processManager: processManager))
        addTool(GetResourceHogsTool(processManager: processManager))
    }

    public override func registerSkills() async {
        addSkill(ProcessMonitoringSkill())
        addSkill(ProcessTerminationSkill())
        addSkill(LaunchAgentManagementSkill())
        addSkill(ResourceOptimizationSkill())
    }

    // MARK: - Task Execution

    public override func performTask(_ task: AgentTask) async throws -> AnySendable? {
        log(.info, "Performing process task: \(task.type.rawValue)")

        switch task.type {
        case .processManagement:
            return try await performProcessManagement(task)
        case .monitoring:
            return try await performMonitoring(task)
        case .optimization:
            return try await performOptimization(task)
        default:
            throw AgentError.taskFailed("Unsupported task type: \(task.type)")
        }
    }

    private func performProcessManagement(_ task: AgentTask) async throws -> AnySendable {
        let action = task.parameters["action"]?.get() as? String ?? "list"

        switch action {
        case "list":
            let limit = task.parameters["limit"]?.get() as? Int ?? 20
            let sortBy = task.parameters["sortBy"]?.get() as? String ?? "cpu"

            let processes: [ProcessManager.ProcessInfo]
            if sortBy == "memory" {
                processes = try await processManager.getProcessesByMemory(limit: limit)
            } else {
                processes = try await processManager.getProcessesByCPU(limit: limit)
            }

            return AnySendable(processes.map { [
                "pid": $0.pid,
                "name": $0.name,
                "cpu": $0.cpuPercent,
                "memory": $0.memoryMB,
                "user": $0.user
            ]})

        case "find":
            guard let name = task.parameters["name"]?.get() as? String else {
                throw AgentError.invalidParameters
            }
            let processes = try await processManager.findProcess(name: name)
            return AnySendable(processes.map { [
                "pid": $0.pid,
                "name": $0.name,
                "cpu": $0.cpuPercent,
                "memory": $0.memoryMB
            ]})

        case "kill":
            guard let pid = task.parameters["pid"]?.get() as? Int else {
                throw AgentError.invalidParameters
            }
            let force = task.parameters["force"]?.get() as? Bool ?? false
            let success = try await processManager.terminateProcess(pid: pid, force: force)
            return AnySendable(["success": success])

        case "killByName":
            guard let name = task.parameters["name"]?.get() as? String else {
                throw AgentError.invalidParameters
            }
            let force = task.parameters["force"]?.get() as? Bool ?? false
            let count = try await processManager.terminateAllByName(name, force: force)
            return AnySendable(["terminated": count])

        case "forceQuit":
            guard let appName = task.parameters["appName"]?.get() as? String else {
                throw AgentError.invalidParameters
            }
            try await processManager.forceQuitApplication(appName)
            return AnySendable("Application force quit: \(appName)")

        default:
            throw AgentError.invalidParameters
        }
    }

    private func performMonitoring(_ task: AgentTask) async throws -> AnySendable {
        let cpuProcesses = try await processManager.getProcessesByCPU(limit: 10)
        let memProcesses = try await processManager.getProcessesByMemory(limit: 10)

        return AnySendable([
            "topCPU": cpuProcesses.map { ["name": $0.name, "cpu": $0.cpuPercent] },
            "topMemory": memProcesses.map { ["name": $0.name, "memory": $0.memoryMB] }
        ])
    }

    private func performOptimization(_ task: AgentTask) async throws -> AnySendable {
        let cpuThreshold = task.parameters["cpuThreshold"]?.get() as? Double ?? 90
        let memThreshold = task.parameters["memoryThreshold"]?.get() as? Double ?? 1000

        let results = try await processManager.terminateResourceHogs(
            cpuThreshold: cpuThreshold,
            memoryThresholdMB: memThreshold
        )

        return AnySendable([
            "terminated": results.filter { $0.success }.count,
            "failed": results.filter { !$0.success }.count,
            "details": results.map { [
                "pid": $0.pid,
                "name": $0.processName,
                "success": $0.success
            ]}
        ])
    }

    // MARK: - Public API

    /// Get top processes by resource usage
    public func getTopProcesses(by: String = "cpu", limit: Int = 10) async throws -> [ProcessManager.ProcessInfo] {
        if by == "memory" {
            return try await processManager.getProcessesByMemory(limit: limit)
        }
        return try await processManager.getProcessesByCPU(limit: limit)
    }

    /// Force quit an application
    public func forceQuit(_ appName: String) async throws {
        try await processManager.forceQuitApplication(appName)
    }

    /// Kill resource-heavy processes
    public func killResourceHogs(cpuThreshold: Double = 90, memoryThresholdMB: Double = 1000) async throws -> [ProcessManager.TerminationResult] {
        return try await processManager.terminateResourceHogs(
            cpuThreshold: cpuThreshold,
            memoryThresholdMB: memoryThresholdMB
        )
    }
}

// MARK: - Process Tools

public struct ListProcessesTool: AgentTool {
    public let name = "list_processes"
    public let description = "List running processes sorted by resource usage"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "sortBy", type: .string, description: "Sort by 'cpu' or 'memory'", required: false, defaultValue: AnySendable("cpu")),
        ToolParameter(name: "limit", type: .int, description: "Number of processes to return", required: false, defaultValue: AnySendable(20))
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let sortBy = parameters["sortBy"]?.get() as? String ?? "cpu"
        let limit = parameters["limit"]?.get() as? Int ?? 20

        let processes: [ProcessManager.ProcessInfo]
        if sortBy == "memory" {
            processes = try await processManager.getProcessesByMemory(limit: limit)
        } else {
            processes = try await processManager.getProcessesByCPU(limit: limit)
        }

        let output = processes.map { [
            "pid": $0.pid,
            "name": $0.name,
            "cpu": $0.cpuPercent,
            "memoryMB": $0.memoryMB,
            "user": $0.user
        ]}

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct FindProcessTool: AgentTool {
    public let name = "find_process"
    public let description = "Find processes by name"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "name", type: .string, description: "Process name to search for", required: true)
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let name = parameters["name"]?.get() as? String else {
            return ToolResult(success: false, error: "Missing process name")
        }

        let processes = try await processManager.findProcess(name: name)

        let output = processes.map { [
            "pid": $0.pid,
            "name": $0.name,
            "cpu": $0.cpuPercent,
            "memoryMB": $0.memoryMB
        ]}

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct KillProcessTool: AgentTool {
    public let name = "kill_process"
    public let description = "Terminate a process by PID"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "pid", type: .int, description: "Process ID", required: true),
        ToolParameter(name: "force", type: .bool, description: "Force kill (SIGKILL)", required: false, defaultValue: AnySendable(false))
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let pid = parameters["pid"]?.get() as? Int else {
            return ToolResult(success: false, error: "Missing PID")
        }

        let force = parameters["force"]?.get() as? Bool ?? false
        let success = try await processManager.terminateProcess(pid: pid, force: force)

        return ToolResult(
            success: success,
            output: AnySendable(["terminated": success]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct KillAllByNameTool: AgentTool {
    public let name = "kill_all_by_name"
    public let description = "Terminate all processes matching a name"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "name", type: .string, description: "Process name", required: true),
        ToolParameter(name: "force", type: .bool, description: "Force kill (SIGKILL)", required: false, defaultValue: AnySendable(false))
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let name = parameters["name"]?.get() as? String else {
            return ToolResult(success: false, error: "Missing process name")
        }

        let force = parameters["force"]?.get() as? Bool ?? false
        let count = try await processManager.terminateAllByName(name, force: force)

        return ToolResult(
            success: true,
            output: AnySendable(["terminatedCount": count]),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct ForceQuitAppTool: AgentTool {
    public let name = "force_quit_app"
    public let description = "Force quit an application"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "appName", type: .string, description: "Application name", required: true)
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let appName = parameters["appName"]?.get() as? String else {
            return ToolResult(success: false, error: "Missing app name")
        }

        try await processManager.forceQuitApplication(appName)

        return ToolResult(
            success: true,
            output: AnySendable("Application force quit: \(appName)"),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct ListLaunchAgentsTool: AgentTool {
    public let name = "list_launch_agents"
    public let description = "List all launch agents"
    public let parameters: [ToolParameter] = []

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let agents = try await processManager.listLaunchAgents()

        let output = agents.map { [
            "label": $0.label,
            "status": $0.status,
            "isRunning": $0.isRunning,
            "domain": $0.domain.rawValue
        ]}

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct ManageLaunchAgentTool: AgentTool {
    public let name = "manage_launch_agent"
    public let description = "Start, stop, or restart a launch agent"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "label", type: .string, description: "Launch agent label", required: true),
        ToolParameter(name: "action", type: .string, description: "Action: start, stop, restart", required: true)
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()

        guard let label = parameters["label"]?.get() as? String,
              let action = parameters["action"]?.get() as? String else {
            return ToolResult(success: false, error: "Missing parameters")
        }

        switch action {
        case "start":
            try await processManager.startLaunchAgent(label: label)
        case "stop":
            try await processManager.stopLaunchAgent(label: label)
        case "restart":
            try await processManager.restartLaunchAgent(label: label)
        default:
            return ToolResult(success: false, error: "Invalid action")
        }

        return ToolResult(
            success: true,
            output: AnySendable("Launch agent \(action): \(label)"),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct GetResourceHogsTool: AgentTool {
    public let name = "get_resource_hogs"
    public let description = "Get processes consuming excessive resources"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "cpuThreshold", type: .double, description: "CPU threshold %", required: false, defaultValue: AnySendable(50.0)),
        ToolParameter(name: "memoryThresholdMB", type: .double, description: "Memory threshold MB", required: false, defaultValue: AnySendable(500.0))
    ]

    private let processManager: ProcessManager

    init(processManager: ProcessManager) {
        self.processManager = processManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let cpuThreshold = parameters["cpuThreshold"]?.get() as? Double ?? 50.0
        let memThreshold = parameters["memoryThresholdMB"]?.get() as? Double ?? 500.0

        let cpuHogs = try await processManager.getProcessesByCPU(limit: 50)
            .filter { $0.cpuPercent > cpuThreshold }

        let memHogs = try await processManager.getProcessesByMemory(limit: 50, minimumMB: memThreshold)

        let output: [String: Any] = [
            "cpuHogs": cpuHogs.map { ["name": $0.name, "pid": $0.pid, "cpu": $0.cpuPercent] },
            "memoryHogs": memHogs.map { ["name": $0.name, "pid": $0.pid, "memoryMB": $0.memoryMB] }
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

// MARK: - Process Skills

public struct ProcessMonitoringSkill: AgentSkill {
    public let name = "Process Monitoring"
    public let description = "Monitor system processes and resource usage"
    public let category = SkillCategory.monitoring
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .monitoring && task.description.lowercased().contains("process")
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "list_processes" }) else {
            throw AgentError.toolNotFound("list_processes")
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

public struct ProcessTerminationSkill: AgentSkill {
    public let name = "Process Termination"
    public let description = "Terminate processes safely"
    public let category = SkillCategory.processManagement
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .processManagement &&
        (task.description.lowercased().contains("kill") ||
         task.description.lowercased().contains("terminate") ||
         task.description.lowercased().contains("quit"))
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        let toolName = task.parameters["pid"] != nil ? "kill_process" :
                       task.parameters["appName"] != nil ? "force_quit_app" : "kill_all_by_name"

        guard let tool = tools.first(where: { $0.name == toolName }) else {
            throw AgentError.toolNotFound(toolName)
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

public struct LaunchAgentManagementSkill: AgentSkill {
    public let name = "Launch Agent Management"
    public let description = "Manage macOS launch agents and daemons"
    public let category = SkillCategory.processManagement
    public let proficiency = SkillProficiency.advanced

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .processManagement &&
        (task.description.lowercased().contains("launch agent") ||
         task.description.lowercased().contains("daemon") ||
         task.description.lowercased().contains("service"))
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        let toolName = task.parameters["action"] != nil ? "manage_launch_agent" : "list_launch_agents"

        guard let tool = tools.first(where: { $0.name == toolName }) else {
            throw AgentError.toolNotFound(toolName)
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

public struct ResourceOptimizationSkill: AgentSkill {
    public let name = "Resource Optimization"
    public let description = "Optimize system resources by managing processes"
    public let category = SkillCategory.optimization
    public let proficiency = SkillProficiency.master

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .optimization &&
        (task.description.lowercased().contains("process") ||
         task.description.lowercased().contains("resource"))
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let tool = tools.first(where: { $0.name == "get_resource_hogs" }) else {
            throw AgentError.toolNotFound("get_resource_hogs")
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
