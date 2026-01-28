// MARK: - SandboxProcessManager.swift
// Craig-O-Clean - Sandbox-Compliant Process Manager
// Replaces shell commands with native APIs for MAS compliance

import Foundation
import AppKit
import os.log

// MARK: - App Info (Native API-based)

/// Information about a running application using only native APIs
struct AppInfo: Identifiable, Hashable {
    let id: String
    let pid: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let isActive: Bool
    let activationPolicy: NSApplication.ActivationPolicy
    let launchDate: Date?

    var isUserApplication: Bool {
        activationPolicy == .regular
    }

    var isAccessoryApp: Bool {
        activationPolicy == .accessory
    }

    // Resource usage (populated separately)
    var cpuUsage: Double = 0
    var memoryUsage: UInt64 = 0
    var threads: Int32 = 0

    var formattedMemoryUsage: String {
        let mb = Double(memoryUsage) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.1f MB", mb)
        }
    }

    var formattedCPUUsage: String {
        String(format: "%.1f%%", cpuUsage)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.pid == rhs.pid
    }

    init(from app: NSRunningApplication) {
        self.id = app.bundleIdentifier ?? "\(app.processIdentifier)"
        self.pid = app.processIdentifier
        self.name = app.localizedName ?? "Unknown"
        self.bundleIdentifier = app.bundleIdentifier
        self.icon = app.icon
        self.isActive = app.isActive
        self.activationPolicy = app.activationPolicy
        self.launchDate = app.launchDate
    }
}

// MARK: - Sandbox Process Manager

/// MAS-compliant process manager using only native APIs
@MainActor
final class SandboxProcessManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var runningApps: [AppInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: CraigOCleanError?
    @Published private(set) var totalMemoryUsage: UInt64 = 0

    // MARK: - Dependencies

    private let actionsService: ActionsService
    private let auditLog: AuditLogService
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "SandboxProcessManager")

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var previousCPUTicks: [pid_t: (user: UInt64, system: UInt64, time: Date)] = [:]

    // MARK: - Initialization

    init(actionsService: ActionsService, auditLog: AuditLogService) {
        self.actionsService = actionsService
        self.auditLog = auditLog

        // Initialize CPU tracking
        initializeCPUTracking()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Start automatic updates
    func startAutoUpdate(interval: TimeInterval = 2.0) {
        stopAutoUpdate()
        refreshApps()

        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshApps()
            }
        }

        logger.info("Started auto-update with \(interval)s interval")
    }

    /// Stop automatic updates
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Refresh the list of running apps
    func refreshApps() {
        isLoading = true

        // Get running applications using NSWorkspace (native API)
        let apps = NSWorkspace.shared.runningApplications

        var appInfos: [AppInfo] = []
        var totalMem: UInt64 = 0

        for app in apps {
            // Skip ourselves and background-only apps without names
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
            guard app.localizedName != nil else { continue }

            var info = AppInfo(from: app)

            // Get resource usage via native APIs
            if let usage = getResourceUsage(for: app.processIdentifier) {
                info.cpuUsage = usage.cpu
                info.memoryUsage = usage.memory
                info.threads = usage.threads
                totalMem += usage.memory
            }

            appInfos.append(info)
        }

        // Sort by name
        appInfos.sort { $0.name.lowercased() < $1.name.lowercased() }

        runningApps = appInfos
        totalMemoryUsage = totalMem
        isLoading = false
    }

    /// Get high memory apps
    func getHighMemoryApps(threshold: UInt64 = 100 * 1024 * 1024) -> [AppInfo] {
        runningApps.filter { $0.memoryUsage > threshold }
            .sorted { $0.memoryUsage > $1.memoryUsage }
    }

    /// Get user applications only
    func getUserApps() -> [AppInfo] {
        runningApps.filter { $0.isUserApplication }
    }

    /// Get accessory (menu bar) apps
    func getAccessoryApps() -> [AppInfo] {
        runningApps.filter { $0.isAccessoryApp }
    }

    // MARK: - Process Termination

    /// Quit an app gracefully
    func quitApp(_ app: AppInfo) async -> ActionResult<Void> {
        guard let runningApp = findRunningApplication(for: app) else {
            return .failure(.processNotFound(identifier: app.name))
        }

        let result = await actionsService.quitApp(runningApp)

        if result.success {
            // Wait briefly and refresh
            try? await Task.sleep(nanoseconds: 500_000_000)
            refreshApps()
        }

        return result
    }

    /// Force quit an app
    func forceQuitApp(_ app: AppInfo) async -> ActionResult<Void> {
        guard let runningApp = findRunningApplication(for: app) else {
            return .failure(.processNotFound(identifier: app.name))
        }

        // Check if this is a sensitive process
        if actionsService.isSensitiveProcess(runningApp) {
            logger.warning("Force quitting sensitive process: \(app.name)")
        }

        let result = await actionsService.forceQuitApp(runningApp)

        if result.success {
            // Wait briefly and refresh
            try? await Task.sleep(nanoseconds: 500_000_000)
            refreshApps()
        }

        return result
    }

    /// Quit all heavy apps
    func quitHeavyApps(threshold: UInt64 = 100 * 1024 * 1024) async -> [String] {
        let heavyApps = getHighMemoryApps(threshold: threshold)
        var quitApps: [String] = []

        for app in heavyApps {
            // Skip protected processes
            if let runningApp = findRunningApplication(for: app),
               actionsService.isProtectedProcess(runningApp) {
                continue
            }

            let result = await quitApp(app)
            if result.success {
                quitApps.append(app.name)
            }
        }

        auditLog.log(.cleanupCompleted, target: "heavy_apps", metadata: [
            "count": "\(quitApps.count)",
            "apps": quitApps.joined(separator: ", ")
        ])

        return quitApps
    }

    // MARK: - System Actions

    /// Restart Finder (via AppleScript if permitted)
    func restartFinder() async -> ActionResult<Void> {
        if let finderApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }),
           let runningApp = findRunningApplication(for: finderApp) {

            let result = await actionsService.forceQuitApp(runningApp)

            if result.success {
                // Finder auto-restarts
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                refreshApps()
            }

            return result
        }

        return .failure(.processNotFound(identifier: "Finder"))
    }

    /// Open Activity Monitor
    func openActivityMonitor() {
        actionsService.openActivityMonitor()
    }

    // MARK: - Private Methods

    private func findRunningApplication(for app: AppInfo) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.processIdentifier == app.pid }
    }

    private func initializeCPUTracking() {
        let apps = NSWorkspace.shared.runningApplications
        let now = Date()

        for app in apps {
            let pid = app.processIdentifier
            if let ticks = getCPUTicks(for: pid) {
                previousCPUTicks[pid] = (user: ticks.user, system: ticks.system, time: now)
            }
        }
    }

    private func getResourceUsage(for pid: pid_t) -> (cpu: Double, memory: UInt64, threads: Int32)? {
        // Get task info for memory and threads
        var taskInfo = proc_taskinfo()
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskSize)

        guard taskResult == taskSize else { return nil }

        let memory = UInt64(taskInfo.pti_resident_size)
        let threads = taskInfo.pti_threadnum

        // Calculate CPU usage
        let cpu = calculateCPUUsage(for: pid, userTicks: taskInfo.pti_total_user, systemTicks: taskInfo.pti_total_system)

        return (cpu: cpu, memory: memory, threads: threads)
    }

    private func getCPUTicks(for pid: pid_t) -> (user: UInt64, system: UInt64)? {
        var taskInfo = proc_taskinfo()
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskSize)

        guard result == taskSize else { return nil }
        return (user: taskInfo.pti_total_user, system: taskInfo.pti_total_system)
    }

    private func calculateCPUUsage(for pid: pid_t, userTicks: UInt64, systemTicks: UInt64) -> Double {
        let now = Date()

        defer {
            previousCPUTicks[pid] = (user: userTicks, system: systemTicks, time: now)
        }

        guard let previous = previousCPUTicks[pid] else { return 0 }

        let timeDelta = now.timeIntervalSince(previous.time)
        guard timeDelta > 0 else { return 0 }

        let userDelta = userTicks - previous.user
        let systemDelta = systemTicks - previous.system
        let totalDelta = userDelta + systemDelta

        // Convert from nanoseconds to seconds
        let cpuTime = Double(totalDelta) / 1_000_000_000.0
        let cpuUsage = (cpuTime / timeDelta) * 100.0

        return min(cpuUsage, 100.0)
    }
}

// MARK: - Process Details (Limited - No Shell Commands)

struct SandboxProcessDetails {
    let app: AppInfo
    let executablePath: String?
    let parentPID: pid_t?
    let creationTime: Date?
    let uid: uid_t?

    // NOTE: Open files and network connections are NOT available in sandbox
    // These would require lsof which is a shell command
    // Users should use Activity Monitor for detailed info
}

extension SandboxProcessManager {

    /// Get limited process details using only native APIs
    func getProcessDetails(for app: AppInfo) -> SandboxProcessDetails? {
        let pid = app.pid

        // Get BSD info
        var bsdInfo = proc_bsdinfo()
        let bsdSize = MemoryLayout<proc_bsdinfo>.size
        let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(bsdSize))

        guard bsdResult == Int32(bsdSize) else { return nil }

        // Get executable path
        var pathBuffer = [Int8](repeating: 0, count: 4096)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        let executablePath = pathLength > 0 ? String(cString: pathBuffer) : nil

        // Get creation time
        let creationTime = Date(
            timeIntervalSince1970: TimeInterval(bsdInfo.pbi_start_tvsec) +
            TimeInterval(bsdInfo.pbi_start_tvusec) / 1_000_000
        )

        return SandboxProcessDetails(
            app: app,
            executablePath: executablePath,
            parentPID: Int32(bsdInfo.pbi_ppid),
            creationTime: creationTime,
            uid: bsdInfo.pbi_uid
        )
    }
}

// MARK: - Filtering and Sorting

extension SandboxProcessManager {

    enum SortOption {
        case name
        case memory
        case cpu
        case pid
    }

    enum FilterOption {
        case all
        case userApps
        case accessoryApps
        case highMemory(threshold: UInt64)
    }

    func filteredApps(filter: FilterOption, sortBy: SortOption, ascending: Bool = false) -> [AppInfo] {
        var apps: [AppInfo]

        switch filter {
        case .all:
            apps = runningApps
        case .userApps:
            apps = getUserApps()
        case .accessoryApps:
            apps = getAccessoryApps()
        case .highMemory(let threshold):
            apps = getHighMemoryApps(threshold: threshold)
        }

        switch sortBy {
        case .name:
            apps.sort { ascending ? $0.name < $1.name : $0.name > $1.name }
        case .memory:
            apps.sort { ascending ? $0.memoryUsage < $1.memoryUsage : $0.memoryUsage > $1.memoryUsage }
        case .cpu:
            apps.sort { ascending ? $0.cpuUsage < $1.cpuUsage : $0.cpuUsage > $1.cpuUsage }
        case .pid:
            apps.sort { ascending ? $0.pid < $1.pid : $0.pid > $1.pid }
        }

        return apps
    }
}
