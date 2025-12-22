// MARK: - MemoryOptimizerService.swift
// CraigOClean Control Center - Memory Optimization Service
// Provides safe memory cleanup workflows and optimization suggestions

import Foundation
import Combine
import AppKit
import os.log

// MARK: - Cleanup Candidate

struct CleanupCandidate: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let memoryUsage: Int64
    let cpuUsage: Double
    let lastActiveTime: Date?
    let processId: Int32
    let isBackgroundApp: Bool
    let icon: NSImage?
    let category: CleanupCategory
    
    var formattedMemoryUsage: String {
        let mb = Double(memoryUsage) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
    
    var potentialSavings: String {
        formattedMemoryUsage
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CleanupCandidate, rhs: CleanupCandidate) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Cleanup Category

enum CleanupCategory: String, CaseIterable {
    case heavyMemory = "Heavy Memory Users"
    case backgroundApps = "Background Apps"
    case inactiveApps = "Inactive Apps"
    case browserTabs = "Browser Tabs"
    
    var description: String {
        switch self {
        case .heavyMemory:
            return "Apps consuming significant memory"
        case .backgroundApps:
            return "Apps running in the background"
        case .inactiveApps:
            return "Apps not used recently"
        case .browserTabs:
            return "Browser tabs consuming resources"
        }
    }
    
    var icon: String {
        switch self {
        case .heavyMemory: return "memorychip"
        case .backgroundApps: return "moon.fill"
        case .inactiveApps: return "clock.arrow.circlepath"
        case .browserTabs: return "safari"
        }
    }
}

// MARK: - Cleanup Result

struct CleanupResult {
    let appsTerminated: Int
    let memoryFreed: Int64
    let success: Bool
    let errors: [String]
    let timestamp: Date
    
    var formattedMemoryFreed: String {
        let mb = Double(memoryFreed) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Memory Optimizer Service

@MainActor
final class MemoryOptimizerService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var cleanupCandidates: [CleanupCandidate] = []
    @Published private(set) var selectedCandidates: Set<CleanupCandidate> = []
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isOptimizing = false
    @Published private(set) var lastCleanupResult: CleanupResult?
    @Published private(set) var potentialMemorySavings: Int64 = 0
    @Published var showPurgeWarning = false
    
    // MARK: - Configuration
    
    /// Minimum memory threshold (MB) for cleanup candidates
    var minimumMemoryThreshold: Int64 = 100 * 1024 * 1024 // 100 MB
    
    /// Apps to exclude from cleanup suggestions
    var excludedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systempreferences",
        "com.apple.loginwindow",
        "com.CraigOClean.controlcenter",
        "com.craigoclean.app"
    ]
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "MemoryOptimizer")
    private var processManager: ProcessManager?
    
    // MARK: - Protected Processes

    private let criticalProcessNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow",
        "SystemUIServer", "Dock", "Finder", "mds", "mds_stores",
        "coreauthd", "securityd", "cfprefsd", "UserEventAgent",
        "Craig-O-Clean"  // Never terminate ourselves
    ]

    /// The PID of this app - we must never terminate ourselves
    private let ownProcessId = Foundation.ProcessInfo.processInfo.processIdentifier

    /// Our own bundle identifier - additional safety check
    private let ownBundleId = Bundle.main.bundleIdentifier

    /// Our running application reference for additional checks
    private let ownRunningApp = NSRunningApplication.current
    
    // MARK: - Initialization
    
    init(processManager: ProcessManager? = nil) {
        self.processManager = processManager
        logger.info("MemoryOptimizerService initialized")
    }
    
    /// Set the process manager for CPU usage tracking
    func setProcessManager(_ pm: ProcessManager) {
        self.processManager = pm
    }
    
    // MARK: - Public Methods
    
    /// Analyze running apps and suggest cleanup candidates
    func analyzeMemoryUsage() async {
        isAnalyzing = true
        cleanupCandidates = []
        potentialMemorySavings = 0
        
        logger.info("Analyzing memory usage...")
        
        // Build a map of PID to CPU usage from ProcessManager if available
        var cpuUsageMap: [Int32: Double] = [:]
        if let pm = processManager {
            pm.updateProcessList()
            // Give a moment for the process list to update
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            for process in pm.processes {
                cpuUsageMap[process.pid] = process.cpuUsage
            }
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        var candidates: [CleanupCandidate] = []
        
        for app in runningApps {
            // CRITICAL: Never include ourselves in cleanup candidates - multiple checks
            // Check 1: PID comparison
            if app.processIdentifier == ownProcessId {
                logger.debug("Excluding self by PID: \(app.localizedName ?? "unknown")")
                continue
            }

            // Check 2: Direct app reference comparison
            if app == ownRunningApp {
                logger.debug("Excluding self by app reference: \(app.localizedName ?? "unknown")")
                continue
            }

            // Check 3: Bundle ID must exist
            guard let bundleId = app.bundleIdentifier else { continue }

            // Check 4: Exclude by bundle ID list
            if excludedBundleIdentifiers.contains(bundleId) {
                logger.debug("Excluding by bundle ID list: \(app.localizedName ?? "unknown") (\(bundleId))")
                continue
            }

            // Check 5: Exclude by our own bundle ID
            if bundleId == ownBundleId {
                logger.debug("Excluding self by bundle ID: \(app.localizedName ?? "unknown")")
                continue
            }

            // Check 6: Exclude critical process names
            if criticalProcessNames.contains(app.localizedName ?? "") {
                logger.debug("Excluding critical process: \(app.localizedName ?? "unknown")")
                continue
            }
            
            // Get memory info for this process
            let memoryInfo = getProcessMemoryInfo(pid: app.processIdentifier)
            
            guard memoryInfo > minimumMemoryThreshold else { continue }
            
            // Determine category
            let category = determineCategory(for: app, memoryUsage: memoryInfo)
            
            // Get CPU usage from ProcessManager if available
            let cpuUsage = cpuUsageMap[app.processIdentifier] ?? 0.0
            
            let candidate = CleanupCandidate(
                id: "\(app.processIdentifier)",
                name: app.localizedName ?? "Unknown App",
                bundleIdentifier: bundleId,
                memoryUsage: memoryInfo,
                cpuUsage: cpuUsage,
                lastActiveTime: nil,
                processId: app.processIdentifier,
                isBackgroundApp: app.activationPolicy != .regular,
                icon: app.icon,
                category: category
            )
            
            candidates.append(candidate)
        }
        
        // Sort by memory usage (descending)
        candidates.sort { $0.memoryUsage > $1.memoryUsage }
        
        cleanupCandidates = candidates
        potentialMemorySavings = candidates.reduce(0) { $0 + $1.memoryUsage }
        isAnalyzing = false
        
        logger.info("Found \(candidates.count) cleanup candidates with potential savings of \(self.formatBytes(self.potentialMemorySavings))")
    }
    
    /// Get cleanup suggestions grouped by category
    func getSuggestionsByCategory() -> [CleanupCategory: [CleanupCandidate]] {
        Dictionary(grouping: cleanupCandidates, by: { $0.category })
    }
    
    /// Get top memory consumers
    func getTopMemoryConsumers(limit: Int = 5) -> [CleanupCandidate] {
        Array(cleanupCandidates
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(limit))
    }
    
    /// Get background apps
    func getBackgroundApps() -> [CleanupCandidate] {
        cleanupCandidates.filter { $0.isBackgroundApp }
    }
    
    /// Select/deselect candidate for cleanup
    func toggleSelection(_ candidate: CleanupCandidate) {
        if selectedCandidates.contains(candidate) {
            selectedCandidates.remove(candidate)
        } else {
            selectedCandidates.insert(candidate)
        }
    }
    
    /// Select all candidates
    func selectAll() {
        selectedCandidates = Set(cleanupCandidates)
    }
    
    /// Deselect all candidates
    func deselectAll() {
        selectedCandidates.removeAll()
    }
    
    /// Select candidates by category
    func selectByCategory(_ category: CleanupCategory) {
        let categoryItems = cleanupCandidates.filter { $0.category == category }
        selectedCandidates.formUnion(categoryItems)
    }
    
    /// Execute cleanup on selected candidates
    func executeCleanup() async -> CleanupResult {
        isOptimizing = true
        var terminatedCount = 0
        var freedMemory: Int64 = 0
        var errors: [String] = []
        
        logger.info("Starting cleanup of \(self.selectedCandidates.count) apps...")

        // Extra safety: filter out our own process from selected candidates
        let safeCandidates = selectedCandidates.filter { $0.processId != ownProcessId }

        for candidate in safeCandidates {
            // Double-check it's not a critical process
            guard !criticalProcessNames.contains(candidate.name) else {
                logger.warning("Skipping critical process: \(candidate.name)")
                errors.append("Skipped protected process: \(candidate.name)")
                continue
            }
            
            let success = await terminateApp(candidate)
            
            if success {
                terminatedCount += 1
                freedMemory += candidate.memoryUsage
                logger.info("Terminated: \(candidate.name) - freed \(candidate.formattedMemoryUsage)")
            } else {
                errors.append("Failed to terminate: \(candidate.name)")
                logger.error("Failed to terminate: \(candidate.name)")
            }
        }
        
        let result = CleanupResult(
            appsTerminated: terminatedCount,
            memoryFreed: freedMemory,
            success: errors.isEmpty,
            errors: errors,
            timestamp: Date()
        )
        
        lastCleanupResult = result
        selectedCandidates.removeAll()
        isOptimizing = false
        
        // Refresh the analysis
        await analyzeMemoryUsage()
        
        return result
    }
    
    /// Terminate a single app gracefully
    func terminateApp(_ candidate: CleanupCandidate) async -> Bool {
        // CRITICAL: Never terminate ourselves - check by PID
        guard candidate.processId != ownProcessId else {
            logger.warning("Prevented self-termination attempt by PID for: \(candidate.name)")
            return false
        }

        // CRITICAL: Check against our running app reference
        guard candidate.processId != ownRunningApp.processIdentifier else {
            logger.warning("Prevented self-termination via NSRunningApplication.current for: \(candidate.name)")
            return false
        }

        // CRITICAL: Also check by bundle identifier as defense in depth
        if let bundleId = candidate.bundleIdentifier {
            if excludedBundleIdentifiers.contains(bundleId) {
                logger.warning("Prevented termination of excluded app by bundle ID: \(candidate.name) (\(bundleId))")
                return false
            }
            // Check against our own bundle ID
            if bundleId == ownBundleId {
                logger.warning("Prevented self-termination via own bundle ID: \(candidate.name)")
                return false
            }
        }

        // Re-fetch the app from NSWorkspace to ensure we have a valid reference
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == candidate.processId }) else {
            logger.warning("App not found: \(candidate.name)")
            return false
        }

        // Final safety check: verify we're not about to terminate ourselves
        if app == ownRunningApp {
            logger.warning("Prevented self-termination via app reference match: \(candidate.name)")
            return false
        }

        if app.bundleIdentifier == ownBundleId {
            logger.warning("Prevented self-termination via bundle ID match: \(candidate.name)")
            return false
        }

        // Check if app is still running before attempting termination
        guard !app.isTerminated else {
            logger.info("App already terminated: \(candidate.name)")
            return true
        }

        // Try graceful termination first
        let terminateResult = app.terminate()

        if terminateResult {
            // Wait a bit for the app to close
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Re-check if app exists and is terminated
            // The app reference may become invalid, so check NSWorkspace again
            let stillRunning = NSWorkspace.shared.runningApplications.contains(where: { $0.processIdentifier == candidate.processId })
            return !stillRunning
        }

        return false
    }
    
    /// Force quit an app (use with caution)
    func forceQuitApp(_ candidate: CleanupCandidate) async -> Bool {
        // CRITICAL: Never force quit ourselves - check by PID
        guard candidate.processId != ownProcessId else {
            logger.warning("Prevented self force-quit attempt by PID for: \(candidate.name)")
            return false
        }

        // CRITICAL: Check against our running app reference
        guard candidate.processId != ownRunningApp.processIdentifier else {
            logger.warning("Prevented self force-quit via NSRunningApplication.current for: \(candidate.name)")
            return false
        }

        // CRITICAL: Also check by bundle identifier as defense in depth
        if let bundleId = candidate.bundleIdentifier {
            if excludedBundleIdentifiers.contains(bundleId) {
                logger.warning("Prevented force-quit of excluded app by bundle ID: \(candidate.name) (\(bundleId))")
                return false
            }
            if bundleId == ownBundleId {
                logger.warning("Prevented self force-quit via own bundle ID: \(candidate.name)")
                return false
            }
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == candidate.processId }) else {
            return false
        }

        // Final safety check: verify we're not about to force quit ourselves
        if app == ownRunningApp {
            logger.warning("Prevented self force-quit via app reference match: \(candidate.name)")
            return false
        }

        if app.bundleIdentifier == ownBundleId {
            logger.warning("Prevented self force-quit via bundle ID match: \(candidate.name)")
            return false
        }
        
        if app.forceTerminate() {
            logger.info("Force quit: \(candidate.name)")
            return true
        }
        
        // Fall back to kill signal
        let result = kill(candidate.processId, SIGKILL)
        return result == 0
    }
    
    /// Run the purge command (requires admin privileges)
    nonisolated func runPurgeCommand() async -> (success: Bool, message: String) {
        logger.info("Running purge command...")

        let script = """
        do shell script "purge" with administrator privileges
        """

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Failed to run purge command"
                    continuation.resume(returning: (false, message))
                } else {
                    continuation.resume(returning: (true, "Memory purge completed successfully"))
                }
            }
        }
    }
    
    /// Check if purge is available
    func isPurgeAvailable() -> Bool {
        FileManager.default.fileExists(atPath: "/usr/sbin/purge")
    }
    
    // MARK: - Private Methods
    
    private func getProcessMemoryInfo(pid: Int32) -> Int64 {
        var taskInfo = proc_taskinfo()
        let taskSize = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(taskSize))
        
        guard result == Int32(taskSize) else { return 0 }
        
        return Int64(taskInfo.pti_resident_size)
    }
    
    private func determineCategory(for app: NSRunningApplication, memoryUsage: Int64) -> CleanupCategory {
        // Heavy memory users (> 500 MB)
        if memoryUsage > 500 * 1024 * 1024 {
            return .heavyMemory
        }
        
        // Background apps
        if app.activationPolicy != .regular || app.isHidden {
            return .backgroundApps
        }
        
        // Browser-related
        let browserBundleIds = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser"]
        if let bundleId = app.bundleIdentifier, browserBundleIds.contains(bundleId) {
            return .browserTabs
        }
        
        // Default to inactive
        return .inactiveApps
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Quick Cleanup Actions

extension MemoryOptimizerService {
    
    /// Quick cleanup - terminate background apps
    func quickCleanupBackground() async -> CleanupResult {
        deselectAll()

        // Get current running process IDs to validate candidates are still running
        let runningPIDs = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })

        // Get frontmost app PID to exclude from cleanup (don't close what user is actively using)
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Filter background apps to only those still running, not frontmost, and NOT ourselves
        let backgroundApps = getBackgroundApps().filter {
            runningPIDs.contains($0.processId) &&
            $0.processId != frontmostPID &&
            $0.processId != ownProcessId  // CRITICAL: Never include ourselves
        }
        selectedCandidates = Set(backgroundApps)
        return await executeCleanup()
    }

    /// Quick cleanup - terminate top memory consumers
    func quickCleanupHeavy(limit: Int = 3) async -> CleanupResult {
        deselectAll()

        // Get current running process IDs to validate candidates are still running
        let runningPIDs = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })

        // Get frontmost app PID to exclude from cleanup (don't close what user is actively using)
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Filter heavy apps to only those still running, not frontmost, and NOT ourselves
        let heavyApps = getTopMemoryConsumers(limit: limit).filter {
            runningPIDs.contains($0.processId) &&
            $0.processId != frontmostPID &&
            $0.processId != ownProcessId  // CRITICAL: Never include ourselves
        }
        selectedCandidates = Set(heavyApps)
        return await executeCleanup()
    }
    
    /// Smart cleanup - automatically select best candidates
    func smartCleanup() async -> CleanupResult {
        deselectAll()

        // Get current running process IDs to validate candidates are still running
        let runningPIDs = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })

        // Get frontmost app PID to exclude from cleanup (don't close what user is actively using)
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Filter to only candidates that are still running, not frontmost, and NOT ourselves
        let validCandidates = cleanupCandidates.filter {
            runningPIDs.contains($0.processId) &&
            $0.processId != frontmostPID &&
            $0.processId != ownProcessId  // CRITICAL: Never include ourselves
        }

        // If no valid candidates, return early with empty result
        guard !validCandidates.isEmpty else {
            logger.info("No valid cleanup candidates found")
            return CleanupResult(
                appsTerminated: 0,
                memoryFreed: 0,
                success: true,
                errors: [],
                timestamp: Date()
            )
        }

        // Select background apps using more than 200MB
        let heavyBackground = validCandidates.filter {
            $0.isBackgroundApp && $0.memoryUsage > 200 * 1024 * 1024
        }

        // Select top 3 non-critical heavy apps (excluding frontmost)
        let heavyApps = validCandidates
            .filter { !$0.isBackgroundApp }
            .prefix(3)

        selectedCandidates = Set(heavyBackground)
        selectedCandidates.formUnion(heavyApps)

        return await executeCleanup()
    }
}
