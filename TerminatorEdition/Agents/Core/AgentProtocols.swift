import Foundation

// MARK: - Agent Protocols
/// Core protocols for the AI Agent Orchestration System
/// Defines the contract for agents, tools, skills, and orchestration

// MARK: - Agent Protocol

/// Base protocol for all autonomous agents
public protocol Agent: AnyObject, Sendable {
    /// Unique identifier for the agent
    var id: UUID { get }

    /// Human-readable name
    var name: String { get }

    /// Agent description and capabilities
    var description: String { get }

    /// Agent's current status
    var status: AgentStatus { get }

    /// Tools available to this agent
    var tools: [AgentTool] { get }

    /// Skills this agent possesses
    var skills: [AgentSkill] { get }

    /// Initialize the agent
    func initialize() async throws

    /// Execute a task
    func execute(task: AgentTask) async throws -> AgentResult

    /// Handle a message from another agent or orchestrator
    func handleMessage(_ message: AgentMessage) async throws -> AgentResponse

    /// Shutdown the agent gracefully
    func shutdown() async
}

// MARK: - Agent Status

public enum AgentStatus: String, Sendable {
    case idle = "Idle"
    case initializing = "Initializing"
    case ready = "Ready"
    case executing = "Executing"
    case waiting = "Waiting"
    case error = "Error"
    case shutdown = "Shutdown"
}

// MARK: - Agent Task

public struct AgentTask: Identifiable, Sendable {
    public let id: UUID
    public let type: TaskType
    public let priority: TaskPriority
    public let description: String
    public let parameters: [String: AnySendable]
    public let timeout: TimeInterval?
    public let requiredCapabilities: [String]
    public let createdAt: Date
    public var deadline: Date?

    public enum TaskType: String, Sendable {
        case cleanup = "cleanup"
        case diagnostic = "diagnostic"
        case maintenance = "maintenance"
        case monitoring = "monitoring"
        case analysis = "analysis"
        case optimization = "optimization"
        case browserManagement = "browser_management"
        case processManagement = "process_management"
        case custom = "custom"
    }

    public enum TaskPriority: Int, Comparable, Sendable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public init(
        id: UUID = UUID(),
        type: TaskType,
        priority: TaskPriority = .normal,
        description: String,
        parameters: [String: AnySendable] = [:],
        timeout: TimeInterval? = nil,
        requiredCapabilities: [String] = [],
        deadline: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.description = description
        self.parameters = parameters
        self.timeout = timeout
        self.requiredCapabilities = requiredCapabilities
        self.createdAt = Date()
        self.deadline = deadline
    }
}

// MARK: - Agent Result

public struct AgentResult: Sendable {
    public let taskId: UUID
    public let agentId: UUID
    public let status: ResultStatus
    public let output: AnySendable?
    public let metrics: ExecutionMetrics
    public let logs: [LogEntry]
    public let error: String?

    public enum ResultStatus: String, Sendable {
        case success = "success"
        case partialSuccess = "partial_success"
        case failure = "failure"
        case timeout = "timeout"
        case cancelled = "cancelled"
    }

    public struct ExecutionMetrics: Sendable {
        public let startTime: Date
        public let endTime: Date
        public let duration: TimeInterval
        public let memoryUsed: UInt64?
        public let cpuTime: TimeInterval?

        public init(startTime: Date, endTime: Date, memoryUsed: UInt64? = nil, cpuTime: TimeInterval? = nil) {
            self.startTime = startTime
            self.endTime = endTime
            self.duration = endTime.timeIntervalSince(startTime)
            self.memoryUsed = memoryUsed
            self.cpuTime = cpuTime
        }
    }

    public struct LogEntry: Sendable {
        public let timestamp: Date
        public let level: LogLevel
        public let message: String

        public enum LogLevel: String, Sendable {
            case debug, info, warning, error
        }
    }

    public init(
        taskId: UUID,
        agentId: UUID,
        status: ResultStatus,
        output: AnySendable? = nil,
        metrics: ExecutionMetrics,
        logs: [LogEntry] = [],
        error: String? = nil
    ) {
        self.taskId = taskId
        self.agentId = agentId
        self.status = status
        self.output = output
        self.metrics = metrics
        self.logs = logs
        self.error = error
    }
}

// MARK: - Agent Message

public struct AgentMessage: Identifiable, Sendable {
    public let id: UUID
    public let fromAgent: UUID?
    public let toAgent: UUID
    public let type: MessageType
    public let content: String
    public let data: [String: AnySendable]
    public let timestamp: Date
    public let requiresResponse: Bool

    public enum MessageType: String, Sendable {
        case query = "query"
        case command = "command"
        case notification = "notification"
        case statusUpdate = "status_update"
        case taskAssignment = "task_assignment"
        case collaboration = "collaboration"
        case error = "error"
    }

    public init(
        id: UUID = UUID(),
        fromAgent: UUID? = nil,
        toAgent: UUID,
        type: MessageType,
        content: String,
        data: [String: AnySendable] = [:],
        requiresResponse: Bool = false
    ) {
        self.id = id
        self.fromAgent = fromAgent
        self.toAgent = toAgent
        self.type = type
        self.content = content
        self.data = data
        self.timestamp = Date()
        self.requiresResponse = requiresResponse
    }
}

// MARK: - Agent Response

public struct AgentResponse: Sendable {
    public let messageId: UUID
    public let agentId: UUID
    public let content: String
    public let data: [String: AnySendable]
    public let status: ResponseStatus
    public let timestamp: Date

    public enum ResponseStatus: String, Sendable {
        case success = "success"
        case error = "error"
        case pending = "pending"
        case declined = "declined"
    }

    public init(
        messageId: UUID,
        agentId: UUID,
        content: String,
        data: [String: AnySendable] = [:],
        status: ResponseStatus
    ) {
        self.messageId = messageId
        self.agentId = agentId
        self.content = content
        self.data = data
        self.status = status
        self.timestamp = Date()
    }
}

// MARK: - Agent Tool

public protocol AgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }

    func execute(with parameters: [String: AnySendable]) async throws -> ToolResult
}

public struct ToolParameter: Sendable {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let required: Bool
    public let defaultValue: AnySendable?

    public enum ParameterType: String, Sendable {
        case string, int, double, bool, array, dictionary
    }

    public init(
        name: String,
        type: ParameterType,
        description: String,
        required: Bool = true,
        defaultValue: AnySendable? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.defaultValue = defaultValue
    }
}

public struct ToolResult: Sendable {
    public let success: Bool
    public let output: AnySendable?
    public let error: String?
    public let executionTime: TimeInterval

    public init(success: Bool, output: AnySendable? = nil, error: String? = nil, executionTime: TimeInterval = 0) {
        self.success = success
        self.output = output
        self.error = error
        self.executionTime = executionTime
    }
}

// MARK: - Agent Skill

public protocol AgentSkill: Sendable {
    var name: String { get }
    var description: String { get }
    var category: SkillCategory { get }
    var proficiency: SkillProficiency { get }

    func canHandle(task: AgentTask) -> Bool
    func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult
}

public enum SkillCategory: String, Sendable {
    case cleanup = "Cleanup"
    case diagnostics = "Diagnostics"
    case optimization = "Optimization"
    case monitoring = "Monitoring"
    case automation = "Automation"
    case analysis = "Analysis"
    case security = "Security"
    case browserManagement = "Browser Management"
    case processManagement = "Process Management"
}

public enum SkillProficiency: Int, Sendable {
    case novice = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4
    case master = 5
}

// MARK: - Orchestrator Protocol

public protocol AgentOrchestrator: AnyObject {
    var agents: [any Agent] { get }
    var taskQueue: [AgentTask] { get }

    func registerAgent(_ agent: any Agent) async
    func unregisterAgent(id: UUID) async
    func submitTask(_ task: AgentTask) async -> UUID
    func cancelTask(id: UUID) async
    func getTaskStatus(id: UUID) async -> AgentTask?
    func broadcastMessage(_ message: AgentMessage) async
    func routeMessage(_ message: AgentMessage) async throws -> AgentResponse
}

// MARK: - Type Erasure for Sendable Any

public struct AnySendable: @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public func get<T>() -> T? {
        value as? T
    }
}

extension AnySendable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value
    }
}

extension AnySendable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.value = value
    }
}

extension AnySendable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.value = value
    }
}

extension AnySendable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.value = value
    }
}
