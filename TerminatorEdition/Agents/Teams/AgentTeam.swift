import Foundation

// MARK: - Agent Team
/// Team-based agent orchestration for complex multi-agent tasks
/// Coordinates specialists for comprehensive system management

@MainActor
public final class AgentTeam: ObservableObject {

    // MARK: - Types

    public enum TeamType: String, CaseIterable {
        case cleanup = "Cleanup Team"
        case diagnostics = "Diagnostics Team"
        case optimization = "Optimization Team"
        case emergency = "Emergency Response Team"
        case maintenance = "Maintenance Team"

        public var description: String {
            switch self {
            case .cleanup: return "Comprehensive system cleanup specialists"
            case .diagnostics: return "System health monitoring and analysis"
            case .optimization: return "Performance optimization and resource management"
            case .emergency: return "Critical system recovery and emergency response"
            case .maintenance: return "Regular system maintenance and upkeep"
            }
        }
    }

    public struct TeamMission: Identifiable {
        public let id: UUID
        public let name: String
        public let description: String
        public let tasks: [AgentTask]
        public let assignedAgents: [UUID]
        public var status: MissionStatus
        public var results: [AgentResult]
        public let createdAt: Date
        public var completedAt: Date?

        public enum MissionStatus: String {
            case pending = "Pending"
            case inProgress = "In Progress"
            case completed = "Completed"
            case failed = "Failed"
            case cancelled = "Cancelled"
        }
    }

    // MARK: - Properties

    public let name: String
    public let type: TeamType
    public private(set) var members: [any Agent] = []
    public private(set) var leader: (any Agent)?

    @Published public private(set) var currentMission: TeamMission?
    @Published public private(set) var missionHistory: [TeamMission] = []
    @Published public private(set) var isActive = false

    private let orchestrator: AgentOrchestrator
    private var aiProvider: AIProvider?

    // MARK: - Initialization

    public init(name: String, type: TeamType, orchestrator: AgentOrchestrator = .shared) {
        self.name = name
        self.type = type
        self.orchestrator = orchestrator
    }

    // MARK: - Team Management

    /// Add an agent to the team
    public func addMember(_ agent: any Agent) {
        guard !members.contains(where: { $0.id == agent.id }) else { return }
        members.append(agent)

        // First member becomes leader by default
        if leader == nil {
            leader = agent
        }
    }

    /// Remove an agent from the team
    public func removeMember(id: UUID) {
        members.removeAll { $0.id == id }

        // If leader was removed, assign new leader
        if leader?.id == id {
            leader = members.first
        }
    }

    /// Set team leader
    public func setLeader(_ agent: any Agent) {
        guard members.contains(where: { $0.id == agent.id }) else { return }
        leader = agent
    }

    /// Set AI provider for intelligent coordination
    public func setAIProvider(_ provider: AIProvider) {
        self.aiProvider = provider
    }

    // MARK: - Mission Execution

    /// Start a mission with the team
    public func startMission(
        name: String,
        description: String,
        tasks: [AgentTask]
    ) async -> TeamMission {

        let mission = TeamMission(
            id: UUID(),
            name: name,
            description: description,
            tasks: tasks,
            assignedAgents: members.map { $0.id },
            status: .inProgress,
            results: [],
            createdAt: Date(),
            completedAt: nil
        )

        currentMission = mission
        isActive = true

        // Execute mission
        let results = await executeMission(mission)

        // Update mission status
        var completedMission = mission
        completedMission.results = results
        completedMission.status = results.allSatisfy { $0.status == .success } ? .completed : .failed
        completedMission.completedAt = Date()

        currentMission = nil
        missionHistory.insert(completedMission, at: 0)
        isActive = false

        return completedMission
    }

    private func executeMission(_ mission: TeamMission) async -> [AgentResult] {
        var results: [AgentResult] = []

        // Use AI to optimize task assignment if available
        let taskAssignments: [(task: AgentTask, agent: any Agent)]

        if let ai = aiProvider {
            taskAssignments = await intelligentTaskAssignment(tasks: mission.tasks, using: ai)
        } else {
            taskAssignments = defaultTaskAssignment(tasks: mission.tasks)
        }

        // Execute tasks
        for (task, agent) in taskAssignments {
            do {
                let result = try await agent.execute(task: task)
                results.append(result)

                // Notify team of progress
                await notifyTeam(about: "Task completed: \(task.description)")
            } catch {
                results.append(AgentResult(
                    taskId: task.id,
                    agentId: agent.id,
                    status: .failure,
                    metrics: .init(startTime: Date(), endTime: Date()),
                    error: error.localizedDescription
                ))
            }
        }

        return results
    }

    private func intelligentTaskAssignment(
        tasks: [AgentTask],
        using ai: AIProvider
    ) async -> [(task: AgentTask, agent: any Agent)] {

        var assignments: [(AgentTask, any Agent)] = []

        for task in tasks {
            let agentInfo = members.map { agent in
                (name: agent.name, skills: agent.skills.map { $0.name }, status: agent.status.rawValue)
            }

            if let recommendedName = try? await (ai as? OllamaProvider)?.analyzeTaskForAgentAssignment(
                task: task,
                availableAgents: agentInfo
            ),
               let agent = members.first(where: { $0.name.lowercased() == recommendedName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }) {
                assignments.append((task, agent))
            } else if let agent = findBestAgent(for: task) {
                assignments.append((task, agent))
            }
        }

        return assignments
    }

    private func defaultTaskAssignment(tasks: [AgentTask]) -> [(task: AgentTask, agent: any Agent)] {
        var assignments: [(AgentTask, any Agent)] = []

        for task in tasks {
            if let agent = findBestAgent(for: task) {
                assignments.append((task, agent))
            }
        }

        return assignments
    }

    private func findBestAgent(for task: AgentTask) -> (any Agent)? {
        members.first { agent in
            agent.skills.contains { $0.canHandle(task: task) }
        }
    }

    private func notifyTeam(about message: String) async {
        for member in members {
            let notification = AgentMessage(
                fromAgent: leader?.id,
                toAgent: member.id,
                type: .notification,
                content: message
            )
            _ = try? await member.handleMessage(notification)
        }
    }

    // MARK: - Predefined Missions

    /// Quick system cleanup mission
    public func quickCleanupMission() async -> TeamMission {
        let tasks = [
            AgentTask(type: .cleanup, description: "Purge inactive memory", parameters: ["cleanMemory": AnySendable(true)]),
            AgentTask(type: .cleanup, description: "Clear temporary files", parameters: ["cleanTemp": AnySendable(true)])
        ]

        return await startMission(
            name: "Quick Cleanup",
            description: "Fast memory and temp file cleanup",
            tasks: tasks
        )
    }

    /// Deep cleanup mission
    public func deepCleanupMission() async -> TeamMission {
        let tasks = [
            AgentTask(type: .cleanup, priority: .high, description: "Purge memory", parameters: ["cleanMemory": AnySendable(true)]),
            AgentTask(type: .cleanup, description: "Clear all caches", parameters: ["cleanCaches": AnySendable(true)]),
            AgentTask(type: .cleanup, description: "Clean temporary files", parameters: ["cleanTemp": AnySendable(true)]),
            AgentTask(type: .cleanup, description: "Empty trash", parameters: ["emptyTrash": AnySendable(true)]),
            AgentTask(type: .browserManagement, description: "Clear browser caches"),
            AgentTask(type: .browserManagement, description: "Close heavy tabs", parameters: ["memoryThreshold": AnySendable(500.0)])
        ]

        return await startMission(
            name: "Deep Cleanup",
            description: "Comprehensive system cleanup",
            tasks: tasks
        )
    }

    /// System diagnostics mission
    public func diagnosticsMission() async -> TeamMission {
        let tasks = [
            AgentTask(type: .diagnostic, description: "Generate health report"),
            AgentTask(type: .monitoring, description: "Monitor system performance", parameters: ["duration": AnySendable(30.0)]),
            AgentTask(type: .analysis, description: "Analyze system state")
        ]

        return await startMission(
            name: "System Diagnostics",
            description: "Comprehensive system health analysis",
            tasks: tasks
        )
    }

    /// Emergency response mission
    public func emergencyResponseMission() async -> TeamMission {
        let tasks = [
            AgentTask(type: .optimization, priority: .critical, description: "Kill resource hogs", parameters: ["cpuThreshold": AnySendable(90.0), "memoryThreshold": AnySendable(2000.0)]),
            AgentTask(type: .browserManagement, priority: .critical, description: "Close all heavy tabs", parameters: ["memoryThreshold": AnySendable(200.0)]),
            AgentTask(type: .cleanup, priority: .critical, description: "Emergency memory purge", parameters: ["cleanMemory": AnySendable(true)])
        ]

        return await startMission(
            name: "Emergency Response",
            description: "Critical system recovery",
            tasks: tasks
        )
    }
}

// MARK: - Predefined Teams

public enum PredefinedTeams {

    /// Create the Cleanup Team
    @MainActor
    public static func createCleanupTeam() async -> AgentTeam {
        let team = AgentTeam(name: "Cleanup Specialists", type: .cleanup)

        let cleanupAgent = CleanupAgent()
        let browserAgent = BrowserAgent()

        await cleanupAgent.initialize()
        await browserAgent.initialize()

        team.addMember(cleanupAgent)
        team.addMember(browserAgent)
        team.setLeader(cleanupAgent)

        return team
    }

    /// Create the Diagnostics Team
    @MainActor
    public static func createDiagnosticsTeam() async -> AgentTeam {
        let team = AgentTeam(name: "Diagnostics Specialists", type: .diagnostics)

        let diagnosticsAgent = DiagnosticsAgent()
        let processAgent = ProcessAgent()

        await diagnosticsAgent.initialize()
        await processAgent.initialize()

        team.addMember(diagnosticsAgent)
        team.addMember(processAgent)
        team.setLeader(diagnosticsAgent)

        return team
    }

    /// Create the Optimization Team
    @MainActor
    public static func createOptimizationTeam() async -> AgentTeam {
        let team = AgentTeam(name: "Optimization Specialists", type: .optimization)

        let processAgent = ProcessAgent()
        let browserAgent = BrowserAgent()
        let cleanupAgent = CleanupAgent()

        await processAgent.initialize()
        await browserAgent.initialize()
        await cleanupAgent.initialize()

        team.addMember(processAgent)
        team.addMember(browserAgent)
        team.addMember(cleanupAgent)
        team.setLeader(processAgent)

        return team
    }

    /// Create the Emergency Response Team
    @MainActor
    public static func createEmergencyTeam() async -> AgentTeam {
        let team = AgentTeam(name: "Emergency Response", type: .emergency)

        let cleanupAgent = CleanupAgent()
        let processAgent = ProcessAgent()
        let browserAgent = BrowserAgent()
        let diagnosticsAgent = DiagnosticsAgent()

        await cleanupAgent.initialize()
        await processAgent.initialize()
        await browserAgent.initialize()
        await diagnosticsAgent.initialize()

        team.addMember(cleanupAgent)
        team.addMember(processAgent)
        team.addMember(browserAgent)
        team.addMember(diagnosticsAgent)
        team.setLeader(cleanupAgent)

        return team
    }

    /// Create all teams and register with orchestrator
    @MainActor
    public static func initializeAllTeams() async -> [AgentTeam] {
        let cleanup = await createCleanupTeam()
        let diagnostics = await createDiagnosticsTeam()
        let optimization = await createOptimizationTeam()
        let emergency = await createEmergencyTeam()

        // Register all agents with the orchestrator
        let orchestrator = AgentOrchestrator.shared

        for team in [cleanup, diagnostics, optimization, emergency] {
            for member in team.members {
                await orchestrator.registerAgent(member)
            }
        }

        return [cleanup, diagnostics, optimization, emergency]
    }
}
