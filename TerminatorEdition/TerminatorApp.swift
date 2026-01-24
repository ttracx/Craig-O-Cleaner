import Foundation

// MARK: - Terminator App
/// Main entry point for Craig-O-Clean Terminator Edition
/// Autonomous system management for macOS Silicon with AI orchestration

@MainActor
public final class TerminatorApp: ObservableObject {

    // MARK: - Singleton

    public static let shared = TerminatorApp()

    // MARK: - Properties

    /// Core engine for system management
    public let engine = TerminatorEngine.shared

    /// Agent orchestrator
    public let orchestrator = AgentOrchestrator.shared

    /// AI provider (Ollama)
    public private(set) var aiProvider: OllamaProvider?

    /// Registered agent teams
    @Published public private(set) var teams: [AgentTeam] = []

    /// Application state
    @Published public private(set) var isInitialized = false
    @Published public private(set) var isAIEnabled = false

    // MARK: - Initialization

    private init() {}

    /// Initialize the Terminator Edition with all components
    public func initialize() async {
        print("🤖 Initializing Craig-O-Clean Terminator Edition...")

        // Initialize agent teams
        teams = await PredefinedTeams.initializeAllTeams()
        print("✅ Agent teams initialized: \(teams.count) teams")

        // Try to initialize Ollama AI
        await initializeAI()

        // Set up default automation
        engine.scheduler.setupDefaultAutomation()
        print("✅ Automation scheduler configured")

        isInitialized = true
        print("🚀 Terminator Edition ready!")
    }

    /// Initialize Ollama AI provider
    public func initializeAI(
        host: String = "localhost",
        port: Int = 11434,
        model: String = "llama3.2"
    ) async {
        let config = OllamaProvider.Configuration(
            host: host,
            port: port,
            model: model
        )

        let provider = OllamaProvider(configuration: config)

        if await provider.isAvailable() {
            aiProvider = provider
            orchestrator.setAIProvider(provider)

            for team in teams {
                team.setAIProvider(provider)
            }

            isAIEnabled = true
            print("✅ Ollama AI initialized with model: \(model)")
        } else {
            print("⚠️ Ollama not available. Running without AI assistance.")
            isAIEnabled = false
        }
    }

    // MARK: - Quick Actions

    /// Perform quick system cleanup
    public func quickCleanup() async -> TerminatorEngine.CleanupResult {
        print("🧹 Starting quick cleanup...")
        return await engine.performQuickCleanup()
    }

    /// Perform full system cleanup
    public func fullCleanup() async -> TerminatorEngine.CleanupResult {
        print("🧹 Starting full cleanup...")
        return await engine.performFullCleanup()
    }

    /// Perform emergency cleanup
    public func emergencyCleanup() async -> TerminatorEngine.CleanupResult {
        print("🚨 Starting emergency cleanup...")
        return await engine.performEmergencyCleanup()
    }

    /// Get system health report
    public func getHealthReport() async -> TerminatorEngine.SystemHealthReport {
        return await engine.performHealthCheck()
    }

    /// Force quit an application
    public func forceQuit(_ appName: String) async throws {
        try await engine.forceQuitApp(appName)
    }

    // MARK: - Team Operations

    /// Get team by type
    public func getTeam(_ type: AgentTeam.TeamType) -> AgentTeam? {
        teams.first { $0.type == type }
    }

    /// Execute a team mission
    public func executeTeamMission(
        teamType: AgentTeam.TeamType,
        missionType: TeamMissionType
    ) async -> AgentTeam.TeamMission? {

        guard let team = getTeam(teamType) else {
            print("❌ Team not found: \(teamType.rawValue)")
            return nil
        }

        switch missionType {
        case .quickCleanup:
            return await team.quickCleanupMission()
        case .deepCleanup:
            return await team.deepCleanupMission()
        case .diagnostics:
            return await team.diagnosticsMission()
        case .emergencyResponse:
            return await team.emergencyResponseMission()
        }
    }

    public enum TeamMissionType {
        case quickCleanup
        case deepCleanup
        case diagnostics
        case emergencyResponse
    }

    // MARK: - AI Operations

    /// Get AI-powered optimization recommendations
    public func getAIRecommendations() async -> String? {
        guard let ai = aiProvider else {
            return nil
        }

        let health = await getHealthReport()

        // Get top processes
        let processAgent = ProcessAgent()
        try? await processAgent.initialize()
        let topProcesses = (try? await processAgent.getTopProcesses(by: "memory", limit: 5)) ?? []

        let processInfo = topProcesses.map { ($0.name, $0.cpuPercent, $0.memoryMB) }

        return try? await ai.getOptimizationRecommendation(
            cpuUsage: health.cpuUsagePercent,
            memoryUsage: health.memoryUsagePercent,
            diskUsage: health.diskUsagePercent,
            topProcesses: processInfo
        )
    }

    /// Generate AI cleanup plan
    public func generateCleanupPlan() async -> String? {
        guard let ai = aiProvider else {
            return nil
        }

        let health = await getHealthReport()
        let memoryPressure = await MemoryManager().getMemoryPressure()

        return try? await ai.generateCleanupPlan(
            memoryPressure: memoryPressure.rawValue,
            diskFreePercent: 100 - health.diskUsagePercent,
            browserTabCount: health.browserTabCount,
            runningProcessCount: health.runningProcessCount
        )
    }

    // MARK: - Autonomous Mode

    /// Enable autonomous management
    public func enableAutonomousMode(
        memoryThreshold: Double = 85,
        diskThreshold: Double = 90,
        checkInterval: TimeInterval = 300
    ) {
        engine.enableAutonomousMode(
            memoryThreshold: memoryThreshold,
            diskThreshold: diskThreshold,
            checkInterval: checkInterval
        )
        print("✅ Autonomous mode enabled")
    }

    /// Disable autonomous mode
    public func disableAutonomousMode() {
        engine.disableAutonomousMode()
        print("✅ Autonomous mode disabled")
    }

    // MARK: - Status

    /// Get application status summary
    public func getStatusSummary() -> String {
        let health = engine.lastHealthReport

        return """
        ╔══════════════════════════════════════════════════════════════╗
        ║     Craig-O-Clean Terminator Edition - Status                ║
        ╚══════════════════════════════════════════════════════════════╝

        Initialized: \(isInitialized ? "✅ Yes" : "❌ No")
        AI Enabled:  \(isAIEnabled ? "✅ Yes (\(aiProvider?.configuration.model ?? ""))" : "❌ No")
        Teams:       \(teams.count) registered

        Agent Teams:
        \(teams.map { "  • \($0.name): \($0.members.count) agents" }.joined(separator: "\n"))

        Last Health Check:
          Health Score: \(health?.healthScore ?? 0)/100
          Memory:       \(String(format: "%.1f", health?.memoryUsagePercent ?? 0))%
          Disk:         \(String(format: "%.1f", health?.diskUsagePercent ?? 0))%
          CPU:          \(String(format: "%.1f", health?.cpuUsagePercent ?? 0))%
          Processes:    \(health?.runningProcessCount ?? 0)
          Browser Tabs: \(health?.browserTabCount ?? 0)

        \(orchestrator.getStatusSummary())
        """
    }

    /// Print status to console
    public func printStatus() {
        print(getStatusSummary())
    }
}

// MARK: - CLI Entry Point

/// Command-line interface for Terminator Edition
@main
struct TerminatorCLI {
    static func main() async {
        let app = TerminatorApp.shared

        print("🤖 Craig-O-Clean Terminator Edition")
        print("====================================")
        print("")

        await app.initialize()

        print("")
        app.printStatus()
    }
}
