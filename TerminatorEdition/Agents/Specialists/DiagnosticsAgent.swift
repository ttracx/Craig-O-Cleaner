import Foundation

// MARK: - Diagnostics Agent
/// Specialized agent for system diagnostics and health monitoring
/// Provides CPU, memory, disk, and network analysis

@MainActor
public final class DiagnosticsAgent: BaseAgent {

    // MARK: - Properties

    private let diagnosticsManager = DiagnosticsManager()
    private let memoryManager = MemoryManager()
    private let diskManager = DiskManager()

    // MARK: - Initialization

    public init() {
        super.init(
            name: "DiagnosticsAgent",
            description: "Specialized agent for system health monitoring and diagnostics"
        )
    }

    // MARK: - Registration

    public override func registerTools() async {
        addTool(SystemInfoTool(diagnosticsManager: diagnosticsManager))
        addTool(CPUInfoTool(diagnosticsManager: diagnosticsManager))
        addTool(MemoryInfoTool(memoryManager: memoryManager))
        addTool(DiskInfoTool(diskManager: diskManager))
        addTool(NetworkDiagnosticsTool(diagnosticsManager: diagnosticsManager))
        addTool(HealthReportTool(diagnosticsManager: diagnosticsManager))
    }

    public override func registerSkills() async {
        addSkill(SystemAnalysisSkill())
        addSkill(PerformanceMonitoringSkill())
        addSkill(HealthCheckSkill())
    }

    // MARK: - Task Execution

    public override func performTask(_ task: AgentTask) async throws -> AnySendable? {
        log(.info, "Performing diagnostics task: \(task.type.rawValue)")

        switch task.type {
        case .diagnostic:
            return try await performDiagnostics(task)
        case .monitoring:
            return try await performMonitoring(task)
        case .analysis:
            return try await performAnalysis(task)
        default:
            throw AgentError.taskFailed("Unsupported task type: \(task.type)")
        }
    }

    private func performDiagnostics(_ task: AgentTask) async throws -> AnySendable {
        log(.info, "Running system diagnostics...")

        let report = try await diagnosticsManager.generateHealthReport()

        let summary: [String: Any] = [
            "timestamp": report.timestamp,
            "overallHealth": report.overallHealth.rawValue,
            "cpuUsage": report.cpu.usagePercent,
            "memoryUsage": report.memoryUsagePercent,
            "diskUsage": report.diskUsagePercent,
            "processCount": report.processCount,
            "systemInfo": [
                "hostname": report.system.hostname,
                "osVersion": report.system.osVersion,
                "architecture": report.system.architecture,
                "model": report.system.modelName
            ]
        ]

        log(.info, "Diagnostics complete - Health: \(report.overallHealth.rawValue)")
        return AnySendable(summary)
    }

    private func performMonitoring(_ task: AgentTask) async throws -> AnySendable {
        let duration = task.parameters["duration"]?.get() as? TimeInterval ?? 60
        let interval = task.parameters["interval"]?.get() as? TimeInterval ?? 5

        log(.info, "Starting monitoring for \(duration) seconds...")

        var samples: [[String: Any]] = []
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < duration {
            let cpu = await diagnosticsManager.getCPUUsage()
            let memory = await diagnosticsManager.getMemoryUsage()
            let disk = await diagnosticsManager.getDiskUsage()

            samples.append([
                "timestamp": Date(),
                "cpu": cpu,
                "memory": memory,
                "disk": disk
            ])

            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        log(.info, "Monitoring complete - Collected \(samples.count) samples")
        return AnySendable(samples)
    }

    private func performAnalysis(_ task: AgentTask) async throws -> AnySendable {
        log(.info, "Performing system analysis...")

        let cpu = await diagnosticsManager.getCPUUsage()
        let memory = await diagnosticsManager.getMemoryUsage()
        let disk = await diagnosticsManager.getDiskUsage()
        let processes = await diagnosticsManager.getProcessCount()

        var recommendations: [String] = []

        // Analyze and provide recommendations
        if memory > 85 {
            recommendations.append("High memory usage (\(String(format: "%.1f", memory))%). Consider closing unused applications or running memory cleanup.")
        }

        if disk > 90 {
            recommendations.append("Low disk space (\(String(format: "%.1f", 100 - disk))% free). Consider clearing caches and temporary files.")
        }

        if cpu > 80 {
            recommendations.append("High CPU usage (\(String(format: "%.1f", cpu))%). Check for resource-intensive processes.")
        }

        if processes > 300 {
            recommendations.append("Many processes running (\(processes)). Consider reviewing startup items and background services.")
        }

        if recommendations.isEmpty {
            recommendations.append("System is running optimally. No action required.")
        }

        let analysis: [String: Any] = [
            "metrics": [
                "cpu": cpu,
                "memory": memory,
                "disk": disk,
                "processes": processes
            ],
            "recommendations": recommendations
        ]

        log(.info, "Analysis complete - \(recommendations.count) recommendations")
        return AnySendable(analysis)
    }

    // MARK: - Public API

    /// Get quick system status
    public func getQuickStatus() async -> (cpu: Double, memory: Double, disk: Double) {
        async let cpu = diagnosticsManager.getCPUUsage()
        async let memory = diagnosticsManager.getMemoryUsage()
        async let disk = diagnosticsManager.getDiskUsage()

        return await (cpu, memory, disk)
    }

    /// Check if system needs attention
    public func needsAttention() async -> Bool {
        let (cpu, memory, disk) = await getQuickStatus()
        return cpu > 90 || memory > 90 || disk > 95
    }

    /// Get detailed health report
    public func getHealthReport() async throws -> DiagnosticsManager.HealthReport {
        return try await diagnosticsManager.generateHealthReport()
    }
}

// MARK: - Diagnostics Tools

public struct SystemInfoTool: AgentTool {
    public let name = "system_info"
    public let description = "Get comprehensive system information"
    public let parameters: [ToolParameter] = []

    private let diagnosticsManager: DiagnosticsManager

    init(diagnosticsManager: DiagnosticsManager) {
        self.diagnosticsManager = diagnosticsManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let info = try await diagnosticsManager.getSystemInfo()

        let output: [String: Any] = [
            "hostname": info.hostname,
            "osVersion": info.osVersion,
            "osBuild": info.osBuild,
            "architecture": info.architecture,
            "model": info.modelName,
            "uptime": info.uptime
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct CPUInfoTool: AgentTool {
    public let name = "cpu_info"
    public let description = "Get CPU information and current usage"
    public let parameters: [ToolParameter] = []

    private let diagnosticsManager: DiagnosticsManager

    init(diagnosticsManager: DiagnosticsManager) {
        self.diagnosticsManager = diagnosticsManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let info = try await diagnosticsManager.getCPUInfo()

        let output: [String: Any] = [
            "brand": info.brandString,
            "cores": info.coreCount,
            "physicalCores": info.physicalCores,
            "logicalCores": info.logicalCores,
            "architecture": info.architecture,
            "usage": info.usagePercent,
            "userPercent": info.userPercent,
            "systemPercent": info.systemPercent
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct MemoryInfoTool: AgentTool {
    public let name = "memory_info"
    public let description = "Get memory information and usage"
    public let parameters: [ToolParameter] = []

    private let memoryManager: MemoryManager

    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let info = try await memoryManager.getMemoryInfo()

        let output: [String: Any] = [
            "totalGB": info.totalGB,
            "usedGB": info.usedGB,
            "freeGB": info.freeGB,
            "usedPercent": info.usedPercent,
            "activeBytes": info.activeBytes,
            "wiredBytes": info.wiredBytes,
            "compressedBytes": info.compressedBytes
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct DiskInfoTool: AgentTool {
    public let name = "disk_info"
    public let description = "Get disk information and usage"
    public let parameters: [ToolParameter] = []

    private let diskManager: DiskManager

    init(diskManager: DiskManager) {
        self.diskManager = diskManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let info = try await diskManager.getDiskInfo()

        let output: [String: Any] = [
            "volumeName": info.volumeName,
            "totalGB": info.totalGB,
            "freeGB": info.freeGB,
            "usedPercent": info.usedPercent,
            "fileSystem": info.fileSystem
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct NetworkDiagnosticsTool: AgentTool {
    public let name = "network_diagnostics"
    public let description = "Run network diagnostics"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "testHost", type: .string, description: "Host to test connectivity", required: false, defaultValue: AnySendable("8.8.8.8"))
    ]

    private let diagnosticsManager: DiagnosticsManager

    init(diagnosticsManager: DiagnosticsManager) {
        self.diagnosticsManager = diagnosticsManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let testHost = parameters["testHost"]?.get() as? String ?? "8.8.8.8"

        let interfaces = await diagnosticsManager.getNetworkInterfaces()
        let connectivity = await diagnosticsManager.testConnectivity(host: testHost)
        let externalIP = await diagnosticsManager.getExternalIP()

        let output: [String: Any] = [
            "interfaces": interfaces.map { ["name": $0.interfaceName, "ip": $0.ipAddress ?? "N/A", "active": $0.isActive] },
            "internetConnectivity": connectivity,
            "externalIP": externalIP ?? "N/A"
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

public struct HealthReportTool: AgentTool {
    public let name = "health_report"
    public let description = "Generate comprehensive system health report"
    public let parameters: [ToolParameter] = []

    private let diagnosticsManager: DiagnosticsManager

    init(diagnosticsManager: DiagnosticsManager) {
        self.diagnosticsManager = diagnosticsManager
    }

    public func execute(with parameters: [String: AnySendable]) async throws -> ToolResult {
        let startTime = Date()
        let report = try await diagnosticsManager.generateHealthReport()

        let output: [String: Any] = [
            "overallHealth": report.overallHealth.rawValue,
            "cpuUsage": report.cpu.usagePercent,
            "memoryUsage": report.memoryUsagePercent,
            "diskUsage": report.diskUsagePercent,
            "processCount": report.processCount,
            "timestamp": report.timestamp
        ]

        return ToolResult(
            success: true,
            output: AnySendable(output),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
}

// MARK: - Diagnostics Skills

public struct SystemAnalysisSkill: AgentSkill {
    public let name = "System Analysis"
    public let description = "Analyze system state and provide recommendations"
    public let category = SkillCategory.analysis
    public let proficiency = SkillProficiency.expert

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .analysis || task.type == .diagnostic
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let healthTool = tools.first(where: { $0.name == "health_report" }) else {
            throw AgentError.toolNotFound("health_report")
        }

        let result = try await healthTool.execute(with: [:])

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}

public struct PerformanceMonitoringSkill: AgentSkill {
    public let name = "Performance Monitoring"
    public let description = "Monitor system performance metrics over time"
    public let category = SkillCategory.monitoring
    public let proficiency = SkillProficiency.advanced

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .monitoring
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        // Collect metrics using multiple tools
        var metrics: [String: Any] = [:]

        for tool in tools {
            if let result = try? await tool.execute(with: task.parameters),
               let output = result.output?.get() as? [String: Any] {
                metrics[tool.name] = output
            }
        }

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: .success,
            output: AnySendable(metrics),
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}

public struct HealthCheckSkill: AgentSkill {
    public let name = "Health Check"
    public let description = "Perform quick system health check"
    public let category = SkillCategory.diagnostics
    public let proficiency = SkillProficiency.master

    public func canHandle(task: AgentTask) -> Bool {
        task.type == .diagnostic &&
        (task.description.lowercased().contains("health") ||
         task.description.lowercased().contains("check"))
    }

    public func execute(task: AgentTask, using tools: [AgentTool]) async throws -> AgentResult {
        let startTime = Date()

        guard let healthTool = tools.first(where: { $0.name == "health_report" }) else {
            throw AgentError.toolNotFound("health_report")
        }

        let result = try await healthTool.execute(with: [:])

        return AgentResult(
            taskId: task.id,
            agentId: UUID(),
            status: result.success ? .success : .failure,
            output: result.output,
            metrics: .init(startTime: startTime, endTime: Date())
        )
    }
}
