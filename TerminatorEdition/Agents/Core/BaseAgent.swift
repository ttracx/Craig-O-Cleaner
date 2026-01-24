import Foundation

// MARK: - Base Agent
/// Abstract base class for all specialized agents
/// Provides common functionality and lifecycle management

@MainActor
open class BaseAgent: Agent, ObservableObject {

    // MARK: - Properties

    public let id: UUID
    public let name: String
    public let description: String

    @Published public private(set) var status: AgentStatus = .idle
    @Published public private(set) var currentTask: AgentTask?
    @Published public private(set) var executionLogs: [AgentResult.LogEntry] = []

    public var tools: [AgentTool] { _tools }
    public var skills: [AgentSkill] { _skills }

    private var _tools: [AgentTool] = []
    private var _skills: [AgentSkill] = []

    public let executor: CommandExecutor

    // MARK: - Initialization

    public init(
        name: String,
        description: String,
        executor: CommandExecutor = .shared
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.executor = executor
    }

    // MARK: - Lifecycle

    open func initialize() async throws {
        status = .initializing
        await registerTools()
        await registerSkills()
        status = .ready
        log(.info, "Agent \(name) initialized")
    }

    open func shutdown() async {
        status = .shutdown
        log(.info, "Agent \(name) shutting down")
    }

    // MARK: - Registration

    /// Override to register tools for this agent
    open func registerTools() async {
        // Subclasses override to add tools
    }

    /// Override to register skills for this agent
    open func registerSkills() async {
        // Subclasses override to add skills
    }

    public func addTool(_ tool: AgentTool) {
        _tools.append(tool)
    }

    public func addSkill(_ skill: AgentSkill) {
        _skills.append(skill)
    }

    // MARK: - Task Execution

    open func execute(task: AgentTask) async throws -> AgentResult {
        guard status == .ready || status == .idle else {
            throw AgentError.notReady
        }

        status = .executing
        currentTask = task
        let startTime = Date()

        log(.info, "Starting task: \(task.description)")

        do {
            // Find a skill that can handle this task
            if let skill = skills.first(where: { $0.canHandle(task: task) }) {
                let result = try await skill.execute(task: task, using: tools)
                status = .ready
                currentTask = nil
                return result
            }

            // Default execution
            let output = try await performTask(task)

            let endTime = Date()
            status = .ready
            currentTask = nil

            return AgentResult(
                taskId: task.id,
                agentId: id,
                status: .success,
                output: output,
                metrics: .init(startTime: startTime, endTime: endTime),
                logs: executionLogs
            )

        } catch {
            let endTime = Date()
            status = .error
            currentTask = nil

            log(.error, "Task failed: \(error.localizedDescription)")

            return AgentResult(
                taskId: task.id,
                agentId: id,
                status: .failure,
                output: nil,
                metrics: .init(startTime: startTime, endTime: endTime),
                logs: executionLogs,
                error: error.localizedDescription
            )
        }
    }

    /// Override to implement task execution logic
    open func performTask(_ task: AgentTask) async throws -> AnySendable? {
        throw AgentError.notImplemented
    }

    // MARK: - Messaging

    open func handleMessage(_ message: AgentMessage) async throws -> AgentResponse {
        log(.info, "Received message: \(message.type.rawValue) - \(message.content)")

        switch message.type {
        case .query:
            return try await handleQuery(message)
        case .command:
            return try await handleCommand(message)
        case .notification:
            return handleNotification(message)
        case .statusUpdate:
            return handleStatusUpdate(message)
        case .taskAssignment:
            return try await handleTaskAssignment(message)
        case .collaboration:
            return try await handleCollaboration(message)
        case .error:
            return handleErrorMessage(message)
        }
    }

    // Override these for custom message handling
    open func handleQuery(_ message: AgentMessage) async throws -> AgentResponse {
        AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Query received",
            status: .success
        )
    }

    open func handleCommand(_ message: AgentMessage) async throws -> AgentResponse {
        AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Command received",
            status: .success
        )
    }

    open func handleNotification(_ message: AgentMessage) -> AgentResponse {
        log(.info, "Notification: \(message.content)")
        return AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Notification acknowledged",
            status: .success
        )
    }

    open func handleStatusUpdate(_ message: AgentMessage) -> AgentResponse {
        AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Status update received",
            status: .success
        )
    }

    open func handleTaskAssignment(_ message: AgentMessage) async throws -> AgentResponse {
        if let taskData = message.data["task"]?.get() as? AgentTask {
            _ = try await execute(task: taskData)
            return AgentResponse(
                messageId: message.id,
                agentId: id,
                content: "Task completed",
                status: .success
            )
        }

        return AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Invalid task data",
            status: .error
        )
    }

    open func handleCollaboration(_ message: AgentMessage) async throws -> AgentResponse {
        AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Collaboration request received",
            status: .pending
        )
    }

    open func handleErrorMessage(_ message: AgentMessage) -> AgentResponse {
        log(.error, "Error from \(message.fromAgent?.uuidString ?? "unknown"): \(message.content)")
        return AgentResponse(
            messageId: message.id,
            agentId: id,
            content: "Error acknowledged",
            status: .success
        )
    }

    // MARK: - Logging

    public func log(_ level: AgentResult.LogEntry.LogLevel, _ message: String) {
        let entry = AgentResult.LogEntry(
            timestamp: Date(),
            level: level,
            message: "[\(name)] \(message)"
        )
        executionLogs.append(entry)

        // Keep only last 1000 logs
        if executionLogs.count > 1000 {
            executionLogs.removeFirst()
        }
    }

    public func clearLogs() {
        executionLogs.removeAll()
    }

    // MARK: - Utility

    public func canExecute(task: AgentTask) -> Bool {
        // Check if any skill can handle the task
        if skills.contains(where: { $0.canHandle(task: task) }) {
            return true
        }

        // Check required capabilities
        let agentCapabilities = skills.map { $0.category.rawValue }
        return task.requiredCapabilities.allSatisfy { agentCapabilities.contains($0) }
    }
}

// MARK: - Agent Errors

public enum AgentError: Error, LocalizedError {
    case notReady
    case notImplemented
    case taskFailed(String)
    case timeout
    case invalidParameters
    case toolNotFound(String)
    case skillNotFound(String)
    case communicationError(String)

    public var errorDescription: String? {
        switch self {
        case .notReady: return "Agent is not ready to execute tasks"
        case .notImplemented: return "This functionality is not implemented"
        case .taskFailed(let msg): return "Task failed: \(msg)"
        case .timeout: return "Task execution timed out"
        case .invalidParameters: return "Invalid task parameters"
        case .toolNotFound(let name): return "Tool not found: \(name)"
        case .skillNotFound(let name): return "Skill not found: \(name)"
        case .communicationError(let msg): return "Communication error: \(msg)"
        }
    }
}
