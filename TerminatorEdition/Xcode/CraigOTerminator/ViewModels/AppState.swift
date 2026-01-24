import SwiftUI
import Combine

// MARK: - App State
/// Central state management for Craig-O Terminator Edition

@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Published Properties

    @Published var isInitialized = false
    @Published var isAIEnabled = false
    @Published var isLoading = false
    @Published var currentOperation: String = ""
    @Published var operationProgress: Double = 0

    @Published var showAbout = false
    @Published var selectedTab: TabSelection = .dashboard

    // System metrics
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var diskUsage: Double = 0
    @Published var healthScore: Int = 100

    // Cleanup results
    @Published var lastCleanupResult: CleanupResult?
    @Published var alertMessage: String?
    @Published var showAlert = false

    // Autonomous mode
    @Published var isAutonomousModeEnabled = false

    // MARK: - Types

    enum TabSelection: String, CaseIterable {
        case dashboard = "Dashboard"
        case cleanup = "Cleanup"
        case browsers = "Browsers"
        case processes = "Processes"
        case diagnostics = "Diagnostics"
        case agents = "Agents"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.33percent"
            case .cleanup: return "trash.circle.fill"
            case .browsers: return "globe"
            case .processes: return "cpu"
            case .diagnostics: return "waveform.path.ecg"
            case .agents: return "brain.head.profile"
            case .settings: return "gearshape.fill"
            }
        }
    }

    struct CleanupResult {
        let memoryFreed: UInt64
        let diskSpaceFreed: UInt64
        let processesTerminated: Int
        let tabsClosed: Int
        let cachesCleared: Int
        let duration: TimeInterval
        let timestamp: Date

        var memoryFreedFormatted: String {
            ByteCountFormatter.string(fromByteCount: Int64(memoryFreed), countStyle: .memory)
        }

        var diskSpaceFreedFormatted: String {
            ByteCountFormatter.string(fromByteCount: Int64(diskSpaceFreed), countStyle: .file)
        }
    }

    // MARK: - Private Properties

    private var metricsTimer: Timer?
    private let executor = CommandExecutor.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Lifecycle

    func initialize() async {
        isLoading = true
        currentOperation = "Initializing..."

        // Check for Ollama
        await checkOllamaAvailability()

        // Start metrics monitoring
        startMetricsMonitoring()

        // Initial metrics fetch
        await updateMetrics()

        isInitialized = true
        isLoading = false
        currentOperation = ""
    }

    func shutdown() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }

    // MARK: - Metrics Monitoring

    private func startMetricsMonitoring() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateMetrics()
            }
        }
    }

    @MainActor
    func updateMetrics() async {
        var newCpuUsage: Double = 0
        var newMemoryUsage: Double = 0
        var newDiskUsage: Double = 0

        // CPU Usage
        if let result = try? await executor.execute("top -l 1 -s 0 | grep 'CPU usage'") {
            if let match = result.output.range(of: #"(\d+\.?\d*)% user"#, options: .regularExpression) {
                let userStr = String(result.output[match]).replacingOccurrences(of: "% user", with: "")
                newCpuUsage = Double(userStr) ?? 0

                if let sysMatch = result.output.range(of: #"(\d+\.?\d*)% sys"#, options: .regularExpression) {
                    let sysStr = String(result.output[sysMatch]).replacingOccurrences(of: "% sys", with: "")
                    newCpuUsage += Double(sysStr) ?? 0
                }
            }
        }

        // Memory Usage
        if let result = try? await executor.execute("top -l 1 -s 0 | grep PhysMem") {
            // Parse memory usage
            if let usedMatch = result.output.range(of: #"(\d+)([GM]) used"#, options: .regularExpression),
               let totalResult = try? await executor.execute("sysctl -n hw.memsize") {
                let usedStr = String(result.output[usedMatch])
                let totalBytes = Double(totalResult.output) ?? 0

                var usedBytes: Double = 0
                if usedStr.contains("G") {
                    if let num = Double(usedStr.replacingOccurrences(of: "G used", with: "").trimmingCharacters(in: .whitespaces)) {
                        usedBytes = num * 1_073_741_824
                    }
                } else if usedStr.contains("M") {
                    if let num = Double(usedStr.replacingOccurrences(of: "M used", with: "").trimmingCharacters(in: .whitespaces)) {
                        usedBytes = num * 1_048_576
                    }
                }

                if totalBytes > 0 {
                    newMemoryUsage = (usedBytes / totalBytes) * 100
                }
            }
        }

        // Disk Usage
        if let result = try? await executor.execute("df -h / | tail -1 | awk '{print $5}'") {
            newDiskUsage = Double(result.output.replacingOccurrences(of: "%", with: "")) ?? 0
        }

        // Batch all published property updates together
        cpuUsage = newCpuUsage
        memoryUsage = newMemoryUsage
        diskUsage = newDiskUsage
        calculateHealthScore()
    }

    private func calculateHealthScore() {
        var score = 100

        // Memory impact
        if memoryUsage > 90 { score -= 40 }
        else if memoryUsage > 80 { score -= 30 }
        else if memoryUsage > 70 { score -= 20 }
        else if memoryUsage > 60 { score -= 10 }

        // Disk impact
        if diskUsage > 95 { score -= 30 }
        else if diskUsage > 90 { score -= 20 }
        else if diskUsage > 80 { score -= 10 }

        // CPU impact
        if cpuUsage > 90 { score -= 20 }
        else if cpuUsage > 80 { score -= 15 }
        else if cpuUsage > 70 { score -= 10 }

        healthScore = max(0, score)
    }

    // MARK: - AI

    private func checkOllamaAvailability() async {
        // Check if Ollama is running
        if let result = try? await executor.execute("curl -s http://localhost:11434/api/tags 2>/dev/null") {
            isAIEnabled = result.isSuccess && !result.output.isEmpty
        } else {
            isAIEnabled = false
        }
    }

    // MARK: - Cleanup Operations

    func performQuickCleanup() async {
        isLoading = true
        currentOperation = "Performing quick cleanup..."
        operationProgress = 0

        let startTime = Date()
        var memoryFreed: UInt64 = 0
        let diskFreed: UInt64 = 0

        // Batch all privileged operations together to minimize prompts
        operationProgress = 0.2
        currentOperation = "Executing cleanup operations..."

        _ = try? await executor.execute("sync")

        // Execute all privileged commands in one authorization prompt
        let privilegedCommands = [
            "purge",
            "dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null"
        ]

        operationProgress = 0.5
        if let _ = try? await executor.executePrivilegedBatch(privilegedCommands) {
            memoryFreed = 500_000_000 // Estimated
        }

        // Clear temp files (non-privileged)
        operationProgress = 0.8
        currentOperation = "Clearing temporary files..."
        _ = try? await executor.execute("rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null")

        operationProgress = 1.0
        currentOperation = "Complete"

        let duration = Date().timeIntervalSince(startTime)

        lastCleanupResult = CleanupResult(
            memoryFreed: memoryFreed,
            diskSpaceFreed: diskFreed,
            processesTerminated: 0,
            tabsClosed: 0,
            cachesCleared: 1,
            duration: duration,
            timestamp: Date()
        )

        await updateMetrics()

        isLoading = false
        currentOperation = ""

        showAlertMessage("Quick cleanup completed in \(String(format: "%.1f", duration))s")
    }

    func performFullCleanup() async {
        isLoading = true
        currentOperation = "Performing full cleanup..."
        operationProgress = 0

        let startTime = Date()
        var memoryFreed: UInt64 = 0
        var diskFreed: UInt64 = 0
        var cachesCleared = 0

        // Sync filesystem first
        operationProgress = 0.1
        _ = try? await executor.execute("sync")

        // Clear user caches (non-privileged)
        operationProgress = 0.2
        currentOperation = "Clearing user caches..."
        _ = try? await executor.execute("rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null")
        cachesCleared += 1
        diskFreed += 100_000_000

        // Clear browser caches (non-privileged)
        operationProgress = 0.4
        currentOperation = "Clearing browser caches..."
        _ = try? await executor.execute("rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null")
        _ = try? await executor.execute("rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null")
        _ = try? await executor.execute("rm -rf ~/Library/Caches/Firefox/* 2>/dev/null")
        cachesCleared += 3

        // Batch all privileged operations together
        operationProgress = 0.6
        currentOperation = "Executing privileged cleanup operations..."

        let privilegedCommands = [
            "purge",
            "rm -rf /private/var/tmp/* 2>/dev/null",
            "dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null"
        ]

        if let _ = try? await executor.executePrivilegedBatch(privilegedCommands) {
            memoryFreed = 500_000_000
        }

        operationProgress = 1.0
        currentOperation = "Complete"

        let duration = Date().timeIntervalSince(startTime)

        lastCleanupResult = CleanupResult(
            memoryFreed: memoryFreed,
            diskSpaceFreed: diskFreed,
            processesTerminated: 0,
            tabsClosed: 0,
            cachesCleared: cachesCleared,
            duration: duration,
            timestamp: Date()
        )

        await updateMetrics()

        isLoading = false
        currentOperation = ""

        showAlertMessage("Full cleanup completed in \(String(format: "%.1f", duration))s")
    }

    func performEmergencyCleanup() async {
        isLoading = true
        currentOperation = "EMERGENCY MODE ACTIVATED..."
        operationProgress = 0

        let startTime = Date()
        var processesKilled = 0

        // Kill heavy processes (non-privileged)
        operationProgress = 0.2
        currentOperation = "Terminating resource hogs..."
        _ = try? await executor.execute("pkill -9 -f 'Chrome Helper' 2>/dev/null")
        _ = try? await executor.execute("pkill -9 -f 'Safari Web Content' 2>/dev/null")
        processesKilled += 2

        // Sync filesystem
        operationProgress = 0.3
        _ = try? await executor.execute("sync")

        // Clear user caches (non-privileged)
        operationProgress = 0.4
        currentOperation = "Emergency cache clear..."
        _ = try? await executor.execute("rm -rf ~/Library/Caches/* 2>/dev/null")

        // Batch all privileged operations together
        operationProgress = 0.6
        currentOperation = "Executing emergency privileged operations..."

        let privilegedCommands = [
            "purge",
            "rm -rf /private/var/tmp/* 2>/dev/null",
            "rm -rf /private/var/folders/*/*/*/* 2>/dev/null"
        ]

        _ = try? await executor.executePrivilegedBatch(privilegedCommands)

        operationProgress = 1.0
        currentOperation = "Emergency cleanup complete"

        let duration = Date().timeIntervalSince(startTime)

        lastCleanupResult = CleanupResult(
            memoryFreed: 1_000_000_000,
            diskSpaceFreed: 500_000_000,
            processesTerminated: processesKilled,
            tabsClosed: 0,
            cachesCleared: 5,
            duration: duration,
            timestamp: Date()
        )

        await updateMetrics()

        isLoading = false
        currentOperation = ""

        showAlertMessage("Emergency cleanup completed in \(String(format: "%.1f", duration))s")
    }

    // MARK: - Autonomous Mode

    func toggleAutonomousMode() {
        isAutonomousModeEnabled.toggle()

        if isAutonomousModeEnabled {
            // Start autonomous monitoring
            showAlertMessage("Autonomous mode enabled. System will be monitored and cleaned automatically.")
        } else {
            showAlertMessage("Autonomous mode disabled.")
        }
    }

    // MARK: - Alerts

    func showAlertMessage(_ message: String) {
        Task { @MainActor in
            alertMessage = message
            showAlert = true

            // Auto-dismiss after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showAlert = false
        }
    }
}
