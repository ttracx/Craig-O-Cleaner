// MARK: - AutoCleanupService.swift
// Craig-O-Clean - Automatic Resource Monitoring and Cleanup Service
// Monitors system resources and automatically triggers cleanup when thresholds are exceeded

import Foundation
import Combine
import UserNotifications
import os.log

// MARK: - Resource Thresholds

struct ResourceThresholds {
    var memoryWarning: Double = 75.0      // Memory % to show warning
    var memoryCritical: Double = 85.0     // Memory % to trigger auto-cleanup
    var cpuWarning: Double = 80.0         // CPU % to show warning
    var cpuCritical: Double = 90.0        // CPU % to trigger process termination
    var processMemoryLimit: UInt64 = 2_147_483_648  // 2GB - terminate processes using more
    var processCPULimit: Double = 50.0    // 50% CPU sustained usage

    static let `default` = ResourceThresholds()
}

// MARK: - Cleanup Action

enum CleanupAction: String, Identifiable {
    case memoryPurge = "Memory Purge"
    case processTermination = "Process Termination"
    case browserTabCleanup = "Browser Tab Cleanup"
    case cacheClearing = "Cache Clearing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .memoryPurge: return "arrow.clockwise.circle.fill"
        case .processTermination: return "xmark.app.fill"
        case .browserTabCleanup: return "safari"
        case .cacheClearing: return "trash.circle.fill"
        }
    }
}

// MARK: - Cleanup Event

struct CleanupEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let action: CleanupAction
    let reason: String
    let memoryFreed: UInt64?
    let processesTerminated: Int?

    var description: String {
        var desc = "\(action.rawValue): \(reason)"
        if let freed = memoryFreed {
            desc += " (Freed: \(ByteCountFormatter.string(fromByteCount: Int64(freed), countStyle: .memory)))"
        }
        if let terminated = processesTerminated {
            desc += " (Terminated: \(terminated) processes)"
        }
        return desc
    }
}

// MARK: - Auto Cleanup Service

@MainActor
final class AutoCleanupService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var lastCleanupTime: Date?
    @Published private(set) var recentEvents: [CleanupEvent] = []
    @Published var thresholds: ResourceThresholds = .default

    // Statistics
    @Published private(set) var totalCleanups: Int = 0
    @Published private(set) var totalMemoryFreed: UInt64 = 0
    @Published private(set) var totalProcessesTerminated: Int = 0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.craigoclean.app", category: "AutoCleanup")
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let systemMetrics: SystemMetricsService
    private let memoryOptimizer: MemoryOptimizerService
    private let processManager: ProcessManager

    private var consecutiveHighMemoryCount = 0
    private var consecutiveHighCPUCount = 0

    // Settings keys
    private let isEnabledKey = "autoCleanupEnabled"
    private let memoryWarningKey = "autoCleanupMemoryWarning"
    private let memoryCriticalKey = "autoCleanupMemoryCritical"
    private let cpuWarningKey = "autoCleanupCPUWarning"
    private let cpuCriticalKey = "autoCleanupCPUCritical"

    // MARK: - Initialization

    init(systemMetrics: SystemMetricsService, memoryOptimizer: MemoryOptimizerService, processManager: ProcessManager) {
        self.systemMetrics = systemMetrics
        self.memoryOptimizer = memoryOptimizer
        self.processManager = processManager

        loadSettings()

        logger.info("AutoCleanupService initialized - monitoring will NOT auto-start to prevent crashes")

        // CRITICAL FIX: Do NOT auto-start monitoring on init
        // Previously, this would automatically run purge command which can crash macOS
        // User must explicitly enable monitoring via the UI
        // if isEnabled {
        //     startMonitoring()
        // }
    }

    deinit {
        // Timer.invalidate() is thread-safe and can be called from any thread
        monitoringTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Enable automatic cleanup
    func enable() {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: isEnabledKey)
        startMonitoring()
        logger.info("Auto-cleanup enabled")
    }

    /// Disable automatic cleanup
    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: isEnabledKey)
        stopMonitoring()
        logger.info("Auto-cleanup disabled")
    }

    /// Update thresholds and save to UserDefaults
    func updateThresholds(_ newThresholds: ResourceThresholds) {
        thresholds = newThresholds
        saveThresholds()
        logger.info("Thresholds updated")
    }

    /// Manually trigger an immediate cleanup check
    func triggerImmediateCleanup() async {
        logger.info("Manual cleanup triggered")
        await performCleanupCheck(forced: true)
    }

    /// Clear event history
    func clearHistory() {
        recentEvents.removeAll()
        logger.info("Event history cleared")
    }

    // MARK: - Private Methods - Monitoring

    private func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        logger.info("Starting resource monitoring")

        // Check every 30 seconds (increased from 5 to reduce system load)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanupCheck(forced: false)
            }
        }

        // CRITICAL FIX: Do NOT trigger immediate check on startup
        // This was causing crashes by running purge command immediately
        // Timer will handle checks on its schedule
        // Task {
        //     await performCleanupCheck(forced: false)
        // }
    }

    private func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        consecutiveHighMemoryCount = 0
        consecutiveHighCPUCount = 0

        logger.info("Stopped resource monitoring")
    }

    // MARK: - Private Methods - Cleanup Logic

    private func performCleanupCheck(forced: Bool) async {
        let memoryUsage = systemMetrics.memoryMetrics?.usedPercentage ?? 0
        let cpuUsage = systemMetrics.cpuMetrics?.totalUsage ?? 0

        // Check memory pressure
        if forced || memoryUsage >= thresholds.memoryCritical {
            consecutiveHighMemoryCount += 1

            // Require 2 consecutive high readings to avoid false positives (unless forced)
            if forced || consecutiveHighMemoryCount >= 2 {
                logger.warning("Critical memory usage detected: \(memoryUsage, format: .fixed(precision: 1))%")
                await performMemoryCleanup(memoryUsage: memoryUsage)
                consecutiveHighMemoryCount = 0
            }
        } else if memoryUsage >= thresholds.memoryWarning {
            logger.info("Memory warning threshold reached: \(memoryUsage, format: .fixed(precision: 1))%")
            consecutiveHighMemoryCount = 0
        } else {
            consecutiveHighMemoryCount = 0
        }

        // Check CPU pressure
        if forced || cpuUsage >= thresholds.cpuCritical {
            consecutiveHighCPUCount += 1

            if forced || consecutiveHighCPUCount >= 3 {
                logger.warning("Critical CPU usage detected: \(cpuUsage, format: .fixed(precision: 1))%")
                await performCPUCleanup(cpuUsage: cpuUsage)
                consecutiveHighCPUCount = 0
            }
        } else if cpuUsage >= thresholds.cpuWarning {
            logger.info("CPU warning threshold reached: \(cpuUsage, format: .fixed(precision: 1))%")
            consecutiveHighCPUCount = 0
        } else {
            consecutiveHighCPUCount = 0
        }
    }

    private func performMemoryCleanup(memoryUsage: Double) async {
        logger.info("Performing automatic memory cleanup")

        var memoryFreed: UInt64 = 0
        var terminatedCount = 0

        // CRITICAL FIX: NEVER run purge command automatically
        // The purge command is extremely aggressive and can crash macOS
        // It should ONLY be run manually by user with explicit confirmation
        //
        // Step 1: Purge system memory - DISABLED FOR SAFETY
        // let (success, message) = await memoryOptimizer.runPurgeCommand()
        // if success {
        //     logger.info("Memory purge successful: \(message)")
        //     let inactiveBytes = systemMetrics.memoryMetrics?.inactiveRAM ?? 0
        //     memoryFreed += UInt64(Double(inactiveBytes) * 0.3)
        //     recordEvent(.memoryPurge, reason: "Memory usage \(String(format: "%.1f", memoryUsage))%", memoryFreed: memoryFreed, processesTerminated: nil)
        // }

        logger.warning("Auto-cleanup SKIPPING dangerous purge command for safety - only terminating processes")

        // Step 2: Identify and terminate memory-heavy processes
        let processes = processManager.processes
            .filter { !isSystemCriticalProcess($0) }
            .filter { $0.memoryUsage > thresholds.processMemoryLimit }
            .sorted { $0.memoryUsage > $1.memoryUsage }

        // Terminate top 3 memory hogs if they exceed threshold
        for process in processes.prefix(3) {
            logger.info("Terminating high-memory process: \(process.name) (\(ByteCountFormatter.string(fromByteCount: Int64(process.memoryUsage), countStyle: .memory)))")

            let terminated = await processManager.terminateProcess(process)
            if terminated {
                memoryFreed += UInt64(max(0, process.memoryUsage))
                terminatedCount += 1
            }
        }

        if terminatedCount > 0 {
            recordEvent(.processTermination, reason: "High memory usage", memoryFreed: memoryFreed, processesTerminated: terminatedCount)
        }

        // Update statistics
        totalCleanups += 1
        totalMemoryFreed += memoryFreed
        totalProcessesTerminated += terminatedCount
        lastCleanupTime = Date()

        // Send notification
        await sendCleanupNotification(action: .memoryPurge, memoryFreed: memoryFreed, processesTerminated: terminatedCount)
    }

    private func performCPUCleanup(cpuUsage: Double) async {
        logger.info("Performing automatic CPU cleanup")

        var terminatedCount = 0

        // Identify CPU-heavy processes
        let processes = processManager.processes
            .filter { !isSystemCriticalProcess($0) }
            .filter { $0.cpuUsage > thresholds.processCPULimit }
            .sorted { $0.cpuUsage > $1.cpuUsage }

        // Terminate top 2 CPU hogs
        for process in processes.prefix(2) {
            logger.info("Terminating high-CPU process: \(process.name) (\(String(format: "%.1f", process.cpuUsage))% CPU)")

            let terminated = await processManager.terminateProcess(process)
            if terminated {
                terminatedCount += 1
            }
        }

        if terminatedCount > 0 {
            recordEvent(.processTermination, reason: "High CPU usage", memoryFreed: nil, processesTerminated: terminatedCount)
            totalProcessesTerminated += terminatedCount
            lastCleanupTime = Date()

            await sendCleanupNotification(action: .processTermination, memoryFreed: nil, processesTerminated: terminatedCount)
        }
    }

    // MARK: - Private Methods - Safety

    private func isSystemCriticalProcess(_ process: ProcessInfo) -> Bool {
        // Never terminate critical system processes
        // Note: Browsers are NOT included here - they should be terminable during cleanup
        // if they're consuming excessive memory. Only true system-critical processes are protected.
        let criticalProcesses = [
            "WindowServer",
            "loginwindow",
            "systemd",
            "launchd",
            "kernel_task",
            "Finder",
            "Dock",
            "Craig-O-Clean"
        ]

        return criticalProcesses.contains { process.name.contains($0) }
    }

    // MARK: - Private Methods - Events

    private func recordEvent(_ action: CleanupAction, reason: String, memoryFreed: UInt64?, processesTerminated: Int?) {
        let event = CleanupEvent(
            timestamp: Date(),
            action: action,
            reason: reason,
            memoryFreed: memoryFreed,
            processesTerminated: processesTerminated
        )

        recentEvents.insert(event, at: 0)

        // Keep only last 50 events
        if recentEvents.count > 50 {
            recentEvents = Array(recentEvents.prefix(50))
        }

        logger.info("Cleanup event recorded: \(event.description)")
    }

    // MARK: - Private Methods - Notifications

    private func sendCleanupNotification(action: CleanupAction, memoryFreed: UInt64?, processesTerminated: Int?) async {
        let content = UNMutableNotificationContent()
        content.title = "Craig-O-Clean: Auto-Cleanup Performed"

        var body = "\(action.rawValue) completed"
        if let freed = memoryFreed, freed > 0 {
            body += "\nMemory freed: \(ByteCountFormatter.string(fromByteCount: Int64(freed), countStyle: .memory))"
        }
        if let terminated = processesTerminated, terminated > 0 {
            body += "\nProcesses terminated: \(terminated)"
        }

        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Cleanup notification sent")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods - Settings

    private func loadSettings() {
        // CRITICAL FIX: Force auto-cleanup to be disabled by default for safety
        // Even if it was previously enabled, reset it to prevent automatic crashes
        isEnabled = false
        UserDefaults.standard.set(false, forKey: isEnabledKey)

        logger.warning("Auto-cleanup forced to DISABLED state for safety - user must manually enable")

        thresholds.memoryWarning = UserDefaults.standard.double(forKey: memoryWarningKey)
        if thresholds.memoryWarning == 0 { thresholds.memoryWarning = 75.0 }

        thresholds.memoryCritical = UserDefaults.standard.double(forKey: memoryCriticalKey)
        if thresholds.memoryCritical == 0 { thresholds.memoryCritical = 85.0 }

        thresholds.cpuWarning = UserDefaults.standard.double(forKey: cpuWarningKey)
        if thresholds.cpuWarning == 0 { thresholds.cpuWarning = 80.0 }

        thresholds.cpuCritical = UserDefaults.standard.double(forKey: cpuCriticalKey)
        if thresholds.cpuCritical == 0 { thresholds.cpuCritical = 90.0 }
    }

    private func saveThresholds() {
        UserDefaults.standard.set(thresholds.memoryWarning, forKey: memoryWarningKey)
        UserDefaults.standard.set(thresholds.memoryCritical, forKey: memoryCriticalKey)
        UserDefaults.standard.set(thresholds.cpuWarning, forKey: cpuWarningKey)
        UserDefaults.standard.set(thresholds.cpuCritical, forKey: cpuCriticalKey)
    }

    // MARK: - Helper Methods

    /// Get summary of auto-cleanup status
    func getStatusSummary() -> String {
        if !isEnabled {
            return "Auto-cleanup disabled"
        }

        if let lastCleanup = lastCleanupTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last cleanup: \(formatter.localizedString(for: lastCleanup, relativeTo: Date()))"
        }

        return "Monitoring active, no cleanups yet"
    }
}
