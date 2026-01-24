import Foundation

// MARK: - Agent Orchestrator
/// Central orchestration hub for managing agent teams
/// Coordinates task distribution, messaging, and collaboration

@MainActor
public final class AgentOrchestrator: ObservableObject, AgentOrchestrator {

    // MARK: - Singleton

    public static let shared = AgentOrchestrator()

    // MARK: - Properties

    @Published public private(set) var agents: [any Agent] = []
    @Published public private(set) var taskQueue: [AgentTask] = []
    @Published public private(set) var activeExecutions: [UUID: (agent: UUID, task: AgentTask)] = [:]
    @Published public private(set) var completedTasks: [AgentResult] = []
    @Published public private(set) var isRunning = false

    private var taskExecutionTasks: [UUID: Task<AgentResult, Error>] = [:]
    private let maxConcurrentTasks = 5
    private let maxCompletedTasksHistory = 100

    private var aiProvider: AIProvider?

    // MARK: - Initialization

    private init() {}

    // MARK: - Agent Management

    /// Register an agent with the orchestrator
    public func registerAgent(_ agent: any Agent) async {
        guard !agents.contains(where: { $0.id == agent.id }) else { return }

        do {
            try await agent.initialize()
            agents.append(agent)
            print("🤖 Agent registered: \(agent.name)")
        } catch {
            print("❌ Failed to initialize agent \(agent.name): \(error)")
        }
    }

    /// Unregister an agent
    public func unregisterAgent(id: UUID) async {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }

        let agent = agents[index]
        await agent.shutdown()
        agents.remove(at: index)
        print("🤖 Agent unregistered: \(agent.name)")
    }

    /// Get agent by ID
    public func getAgent(id: UUID) -> (any Agent)? {
        agents.first { $0.id == id }
    }

    /// Get agents by capability
    public func getAgents(withCapability capability: String) -> [any Agent] {
        agents.filter { agent in
            agent.skills.contains { $0.category.rawValue == capability }
        }
    }

    // MARK: - Task Management

    /// Submit a task for execution
    public func submitTask(_ task: AgentTask) async -> UUID {
        taskQueue.append(task)
        print("📋 Task submitted: \(task.description) (Priority: \(task.priority))")

        // Try to execute immediately if possible
        await processTaskQueue()

        return task.id
    }

    /// Cancel a task
    public func cancelTask(id: UUID) async {
        // Remove from queue
        taskQueue.removeAll { $0.id == id }

        // Cancel if executing
        if let executionTask = taskExecutionTasks[id] {
            executionTask.cancel()
            taskExecutionTasks.removeValue(forKey: id)
            activeExecutions.removeValue(forKey: id)
        }

        print("❌ Task cancelled: \(id)")
    }

    /// Get task status
    public func getTaskStatus(id: UUID) async -> AgentTask? {
        // Check queue
        if let task = taskQueue.first(where: { $0.id == id }) {
            return task
        }

        // Check active
        if let (_, task) = activeExecutions[id] {
            return task
        }

        return nil
    }

    // MARK: - Task Processing

    /// Process the task queue
    private func processTaskQueue() async {
        guard !taskQueue.isEmpty else { return }
        guard activeExecutions.count < maxConcurrentTasks else { return }

        // Sort by priority
        taskQueue.sort { $0.priority > $1.priority }

        // Find available tasks and agents
        var tasksToExecute: [(task: AgentTask, agent: any Agent)] = []

        for task in taskQueue {
            // Find suitable agent
            if let agent = findBestAgent(for: task) {
                tasksToExecute.append((task, agent))

                if tasksToExecute.count + activeExecutions.count >= maxConcurrentTasks {
                    break
                }
            }
        }

        // Execute tasks
        for (task, agent) in tasksToExecute {
            await executeTask(task, with: agent)
        }
    }

    /// Find the best agent for a task
    private func findBestAgent(for task: AgentTask) -> (any Agent)? {
        // Filter agents that can handle the task
        let capableAgents = agents.filter { agent in
            // Check status
            guard agent.status == .ready || agent.status == .idle else { return false }

            // Check if already executing
            guard !activeExecutions.values.contains(where: { $0.agent == agent.id }) else { return false }

            // Check capabilities
            if !task.requiredCapabilities.isEmpty {
                let agentCapabilities = Set(agent.skills.map { $0.category.rawValue })
                guard Set(task.requiredCapabilities).isSubset(of: agentCapabilities) else { return false }
            }

            // Check if any skill can handle
            return agent.skills.contains { $0.canHandle(task: task) }
        }

        // Select best based on skill proficiency
        return capableAgents.max { a, b in
            let aMax = a.skills.filter { $0.canHandle(task: task) }.map { $0.proficiency.rawValue }.max() ?? 0
            let bMax = b.skills.filter { $0.canHandle(task: task) }.map { $0.proficiency.rawValue }.max() ?? 0
            return aMax < bMax
        }
    }

    /// Execute a task with an agent
    private func executeTask(_ task: AgentTask, with agent: any Agent) async {
        // Remove from queue
        taskQueue.removeAll { $0.id == task.id }

        // Track active execution
        activeExecutions[task.id] = (agent.id, task)

        print("⚡ Executing task '\(task.description)' with agent '\(agent.name)'")

        // Create execution task
        let executionTask = Task<AgentResult, Error> {
            try await agent.execute(task: task)
        }

        taskExecutionTasks[task.id] = executionTask

        // Handle completion
        Task {
            do {
                let result = try await executionTask.value
                await handleTaskCompletion(task: task, result: result)
            } catch {
                let result = AgentResult(
                    taskId: task.id,
                    agentId: agent.id,
                    status: .failure,
                    output: nil,
                    metrics: .init(startTime: Date(), endTime: Date()),
                    error: error.localizedDescription
                )
                await handleTaskCompletion(task: task, result: result)
            }
        }
    }

    /// Handle task completion
    private func handleTaskCompletion(task: AgentTask, result: AgentResult) async {
        // Remove from active
        activeExecutions.removeValue(forKey: task.id)
        taskExecutionTasks.removeValue(forKey: task.id)

        // Store result
        completedTasks.insert(result, at: 0)
        if completedTasks.count > maxCompletedTasksHistory {
            completedTasks.removeLast()
        }

        let emoji = result.status == .success ? "✅" : "❌"
        print("\(emoji) Task completed: \(task.description) - \(result.status.rawValue)")

        // Process more tasks
        await processTaskQueue()
    }

    // MARK: - Messaging

    /// Broadcast a message to all agents
    public func broadcastMessage(_ message: AgentMessage) async {
        for agent in agents {
            let agentMessage = AgentMessage(
                id: UUID(),
                fromAgent: message.fromAgent,
                toAgent: agent.id,
                type: message.type,
                content: message.content,
                data: message.data,
                requiresResponse: false
            )

            Task {
                _ = try? await agent.handleMessage(agentMessage)
            }
        }
    }

    /// Route a message to a specific agent
    public func routeMessage(_ message: AgentMessage) async throws -> AgentResponse {
        guard let agent = getAgent(id: message.toAgent) else {
            throw AgentError.communicationError("Agent not found: \(message.toAgent)")
        }

        return try await agent.handleMessage(message)
    }

    /// Send message between agents
    public func sendMessage(from: UUID, to: UUID, type: AgentMessage.MessageType, content: String, data: [String: AnySendable] = []) async throws -> AgentResponse {
        let message = AgentMessage(
            fromAgent: from,
            toAgent: to,
            type: type,
            content: content,
            data: data,
            requiresResponse: true
        )

        return try await routeMessage(message)
    }

    // MARK: - AI Integration

    /// Set the AI provider for intelligent orchestration
    public func setAIProvider(_ provider: AIProvider) {
        self.aiProvider = provider
    }

    /// Use AI to determine best task assignment
    public func intelligentTaskAssignment(_ task: AgentTask) async -> (any Agent)? {
        guard let ai = aiProvider else {
            return findBestAgent(for: task)
        }

        // Build context for AI
        let agentDescriptions = agents.map { agent in
            """
            Agent: \(agent.name)
            Description: \(agent.description)
            Skills: \(agent.skills.map { $0.name }.joined(separator: ", "))
            Status: \(agent.status.rawValue)
            """
        }.joined(separator: "\n\n")

        let prompt = """
        Given the following task and available agents, which agent should handle this task?

        Task: \(task.description)
        Type: \(task.type.rawValue)
        Priority: \(task.priority)
        Required Capabilities: \(task.requiredCapabilities.joined(separator: ", "))

        Available Agents:
        \(agentDescriptions)

        Respond with just the agent name that should handle this task.
        """

        if let response = try? await ai.complete(prompt: prompt),
           let agentName = response.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces),
           let agent = agents.first(where: { $0.name.lowercased() == agentName.lowercased() }) {
            return agent
        }

        return findBestAgent(for: task)
    }

    // MARK: - Team Operations

    /// Execute a complex task with multiple agents
    public func executeWithTeam(task: AgentTask, teamAgentIds: [UUID]) async -> [AgentResult] {
        var results: [AgentResult] = []

        // Create subtasks for each agent
        for agentId in teamAgentIds {
            guard let agent = getAgent(id: agentId) else { continue }

            let subtask = AgentTask(
                type: task.type,
                priority: task.priority,
                description: "\(task.description) (Team member: \(agent.name))",
                parameters: task.parameters,
                timeout: task.timeout,
                requiredCapabilities: []
            )

            do {
                let result = try await agent.execute(task: subtask)
                results.append(result)
            } catch {
                results.append(AgentResult(
                    taskId: subtask.id,
                    agentId: agentId,
                    status: .failure,
                    metrics: .init(startTime: Date(), endTime: Date()),
                    error: error.localizedDescription
                ))
            }
        }

        return results
    }

    // MARK: - Status

    /// Get orchestrator status summary
    public func getStatusSummary() -> String {
        """
        🤖 Agent Orchestrator Status
        ===========================
        Registered Agents: \(agents.count)
        Queued Tasks: \(taskQueue.count)
        Active Executions: \(activeExecutions.count)
        Completed Tasks: \(completedTasks.count)

        Agents:
        \(agents.map { "  - \($0.name): \($0.status.rawValue)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - AI Provider Protocol

public protocol AIProvider: Sendable {
    func complete(prompt: String) async throws -> String
    func chat(messages: [AIMessage]) async throws -> String
}

public struct AIMessage: Sendable {
    public let role: Role
    public let content: String

    public enum Role: String, Sendable {
        case system, user, assistant
    }

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
