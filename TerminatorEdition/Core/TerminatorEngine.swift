import Foundation

// MARK: - Terminator Engine
/// Main orchestration engine for autonomous macOS management
/// Coordinates all modules and provides high-level operations

@MainActor
public final class TerminatorEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = TerminatorEngine()

    // MARK: - Module References

    public let executor = CommandExecutor.shared
    public let processManager = ProcessManager()
    public let browserManager = BrowserManager()
    public let memoryManager = MemoryManager()
    public let cacheManager = CacheManager()
    public let diskManager = DiskManager()
    public let diagnostics = DiagnosticsManager()
    public let utilities = SystemUtilities()
    public let scheduler = AutomationScheduler()

    // MARK: - State

    @Published public private(set) var isRunning = false
    @Published public private(set) var currentOperation: String = ""
    @Published public private(set) var operationProgress: Double = 0
    @Published public private(set) var lastHealthReport: SystemHealthReport?
    @Published public private(set) var alertMessages: [AlertMessage] = []

    // MARK: - Types

    public struct AlertMessage: Identifiable {
        public let id = UUID()
        public let level: AlertLevel
        public let message: String
        public let timestamp: Date

        public enum AlertLevel {
            case info, warning, critical
        }
    }

    public struct SystemHealthReport: Sendable {
        public let timestamp: Date
        public let memoryUsagePercent: Double
        public let diskUsagePercent: Double
        public let cpuUsagePercent: Double
        public let runningProcessCount: Int
        public let browserTabCount: Int
        public let healthScore: Int // 0-100

        public var summary: String {
            """
            System Health Report - \(timestamp.formatted())
            Health Score: \(healthScore)/100
            Memory: \(String(format: "%.1f", memoryUsagePercent))%
            Disk: \(String(format: "%.1f", diskUsagePercent))%
            CPU: \(String(format: "%.1f", cpuUsagePercent))%
            Processes: \(runningProcessCount)
            Browser Tabs: \(browserTabCount)
            """
        }
    }

    public struct CleanupResult {
        public let memoryFreed: UInt64
        public let diskSpaceFreed: UInt64
        public let processesTerminated: Int
        public let tabsClosed: Int
        public let cachesCleared: Int
        public let errors: [String]
        public let duration: TimeInterval

        public var summary: String {
            """
            Cleanup Complete
            ================
            Memory Freed: \(ByteCountFormatter.string(fromByteCount: Int64(memoryFreed), countStyle: .memory))
            Disk Freed: \(ByteCountFormatter.string(fromByteCount: Int64(diskSpaceFreed), countStyle: .file))
            Processes Terminated: \(processesTerminated)
            Browser Tabs Closed: \(tabsClosed)
            Caches Cleared: \(cachesCleared)
            Duration: \(String(format: "%.2f", duration))s
            Errors: \(errors.count)
            """
        }
    }

    // MARK: - Initialization

    private init() {
        setupMonitoring()
    }

    private func setupMonitoring() {
        // Set up periodic health checks
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await performHealthCheck()
            }
        }
    }

    // MARK: - High-Level Operations

    /// Perform comprehensive system cleanup
    public func performFullCleanup(
        includeMemory: Bool = true,
        includeCaches: Bool = true,
        includeBrowsers: Bool = true,
        includeTemporaryFiles: Bool = true,
        aggressive: Bool = false
    ) async -> CleanupResult {

        let startTime = Date()
        var memoryFreed: UInt64 = 0
        var diskSpaceFreed: UInt64 = 0
        var processesTerminated = 0
        var tabsClosed = 0
        var cachesCleared = 0
        var errors: [String] = []

        isRunning = true
        defer { isRunning = false }

        // 1. Memory cleanup
        if includeMemory {
            currentOperation = "Cleaning memory..."
            operationProgress = 0.1

            do {
                let memResult = try await memoryManager.purgeInactiveMemory()
                memoryFreed = memResult.memoryFreed

                if aggressive {
                    let heavyProcesses = try await processManager.getProcessesByMemory(limit: 10, minimumMB: 500)
                    for process in heavyProcesses where !process.isSystemCritical {
                        if try await processManager.terminateProcess(pid: process.pid, force: false) {
                            processesTerminated += 1
                        }
                    }
                }
            } catch {
                errors.append("Memory cleanup: \(error.localizedDescription)")
            }
        }

        // 2. Browser cleanup
        if includeBrowsers {
            currentOperation = "Cleaning browsers..."
            operationProgress = 0.3

            do {
                let browserResult = try await browserManager.closeAllResourceHeavyTabs(memoryThresholdMB: 500)
                tabsClosed = browserResult.tabsClosed
            } catch {
                errors.append("Browser cleanup: \(error.localizedDescription)")
            }
        }

        // 3. Cache cleanup
        if includeCaches {
            currentOperation = "Clearing caches..."
            operationProgress = 0.5

            do {
                let cacheResult = try await cacheManager.clearAllCaches(
                    includeSystem: aggressive,
                    includeBrowsers: true,
                    includeDeveloper: true
                )
                diskSpaceFreed += cacheResult.spaceFreed
                cachesCleared = cacheResult.cacheCount
            } catch {
                errors.append("Cache cleanup: \(error.localizedDescription)")
            }
        }

        // 4. Temporary files
        if includeTemporaryFiles {
            currentOperation = "Cleaning temporary files..."
            operationProgress = 0.7

            do {
                let tempResult = try await diskManager.cleanTemporaryFiles()
                diskSpaceFreed += tempResult.spaceFreed
            } catch {
                errors.append("Temp cleanup: \(error.localizedDescription)")
            }
        }

        // 5. DNS flush
        currentOperation = "Flushing DNS..."
        operationProgress = 0.9

        do {
            try await utilities.flushDNSCache()
        } catch {
            errors.append("DNS flush: \(error.localizedDescription)")
        }

        currentOperation = "Complete"
        operationProgress = 1.0

        let duration = Date().timeIntervalSince(startTime)

        return CleanupResult(
            memoryFreed: memoryFreed,
            diskSpaceFreed: diskSpaceFreed,
            processesTerminated: processesTerminated,
            tabsClosed: tabsClosed,
            cachesCleared: cachesCleared,
            errors: errors,
            duration: duration
        )
    }

    /// Quick cleanup - minimal resource usage
    public func performQuickCleanup() async -> CleanupResult {
        return await performFullCleanup(
            includeMemory: true,
            includeCaches: false,
            includeBrowsers: false,
            includeTemporaryFiles: true,
            aggressive: false
        )
    }

    /// Emergency cleanup - aggressive mode
    public func performEmergencyCleanup() async -> CleanupResult {
        // First kill resource-heavy non-essential processes
        let _ = try? await processManager.terminateResourceHogs(cpuThreshold: 80, memoryThresholdMB: 2000)

        return await performFullCleanup(
            includeMemory: true,
            includeCaches: true,
            includeBrowsers: true,
            includeTemporaryFiles: true,
            aggressive: true
        )
    }

    /// Perform system health check
    public func performHealthCheck() async -> SystemHealthReport {
        let memory = await diagnostics.getMemoryUsage()
        let disk = await diagnostics.getDiskUsage()
        let cpu = await diagnostics.getCPUUsage()
        let processes = await diagnostics.getProcessCount()
        let tabs = await browserManager.getTotalTabCount()

        // Calculate health score
        var score = 100

        // Memory impact (40 points max)
        if memory > 90 { score -= 40 }
        else if memory > 80 { score -= 30 }
        else if memory > 70 { score -= 20 }
        else if memory > 60 { score -= 10 }

        // Disk impact (30 points max)
        if disk > 95 { score -= 30 }
        else if disk > 90 { score -= 20 }
        else if disk > 80 { score -= 10 }

        // CPU impact (20 points max)
        if cpu > 90 { score -= 20 }
        else if cpu > 80 { score -= 15 }
        else if cpu > 70 { score -= 10 }

        // Process/tab impact (10 points max)
        if processes > 500 || tabs > 100 { score -= 10 }
        else if processes > 300 || tabs > 50 { score -= 5 }

        let report = SystemHealthReport(
            timestamp: Date(),
            memoryUsagePercent: memory,
            diskUsagePercent: disk,
            cpuUsagePercent: cpu,
            runningProcessCount: processes,
            browserTabCount: tabs,
            healthScore: max(0, score)
        )

        lastHealthReport = report

        // Generate alerts
        if memory > 90 {
            addAlert(.critical, "Critical memory pressure: \(String(format: "%.1f", memory))% used")
        }
        if disk > 95 {
            addAlert(.critical, "Critical disk space: only \(String(format: "%.1f", 100 - disk))% free")
        }
        if score < 50 {
            addAlert(.warning, "System health degraded: score \(score)/100")
        }

        return report
    }

    /// Force quit unresponsive application
    public func forceQuitApp(_ appName: String) async throws {
        currentOperation = "Force quitting \(appName)..."
        try await processManager.forceQuitApplication(appName)
        currentOperation = ""
    }

    /// Restart system services
    public func restartSystemServices() async throws {
        currentOperation = "Restarting system services..."

        let services = ["Finder", "Dock", "SystemUIServer", "ControlCenter"]
        for service in services {
            _ = try? await executor.execute("killall \(service)")
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }

        currentOperation = ""
    }

    // MARK: - Alert Management

    private func addAlert(_ level: AlertMessage.AlertLevel, _ message: String) {
        let alert = AlertMessage(level: level, message: message, timestamp: Date())
        alertMessages.insert(alert, at: 0)

        // Keep only last 50 alerts
        if alertMessages.count > 50 {
            alertMessages.removeLast()
        }
    }

    public func clearAlerts() {
        alertMessages.removeAll()
    }

    // MARK: - Autonomous Mode

    /// Enable autonomous management mode
    public func enableAutonomousMode(
        memoryThreshold: Double = 85,
        diskThreshold: Double = 90,
        checkInterval: TimeInterval = 300
    ) {
        scheduler.scheduleRecurring(
            name: "autonomous_cleanup",
            interval: checkInterval
        ) { [weak self] in
            guard let self = self else { return }

            let health = await self.performHealthCheck()

            if health.memoryUsagePercent > memoryThreshold {
                _ = await self.performQuickCleanup()
            }

            if health.diskUsagePercent > diskThreshold {
                _ = try? await self.diskManager.cleanTemporaryFiles()
                _ = try? await self.cacheManager.clearUserCaches()
            }
        }
    }

    /// Disable autonomous mode
    public func disableAutonomousMode() {
        scheduler.cancelTask(name: "autonomous_cleanup")
    }
}
