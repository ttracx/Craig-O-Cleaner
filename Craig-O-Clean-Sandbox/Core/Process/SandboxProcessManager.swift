// MARK: - SandboxProcessManager.swift
// Craig-O-Clean Sandbox Edition - Process Management
// Provides sandbox-compliant process monitoring and termination

import Foundation
import AppKit
import os.log

// MARK: - Process Information

/// Information about a running process (sandbox-compliant)
struct SandboxProcessInfo: Identifiable, Hashable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let isUserApp: Bool
    let cpuUsage: Double
    let memoryUsage: Int64
    let creationTime: Date?
    let parentPID: Int32?
    let executablePath: String?
    let threads: Int32
    let uid: uid_t
    let icon: NSImage?

    var formattedMemoryUsage: String {
        let mb = Double(memoryUsage) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.1f MB", mb)
        }
    }

    var formattedCPUUsage: String {
        return String(format: "%.1f%%", cpuUsage)
    }

    var age: TimeInterval? {
        return creationTime?.timeIntervalSinceNow.magnitude
    }

    var formattedAge: String {
        guard let age = age else { return "Unknown" }

        let hours = Int(age) / 3600
        let minutes = (Int(age) % 3600) / 60
        let seconds = Int(age) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Hashable & Equatable

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }

    static func == (lhs: SandboxProcessInfo, rhs: SandboxProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }
}

// MARK: - Termination Result

enum TerminationResult {
    case success
    case alreadyTerminated
    case accessDenied
    case protectedProcess
    case failed(Error?)

    var message: String {
        switch self {
        case .success: return "Process terminated successfully"
        case .alreadyTerminated: return "Process was already terminated"
        case .accessDenied: return "Access denied - process may require elevated privileges"
        case .protectedProcess: return "This is a protected system process"
        case .failed(let error): return "Failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

// MARK: - Sandbox Process Manager

/// Manages processes using only sandbox-compliant APIs
/// Uses NSRunningApplication and BSD proc APIs
@MainActor
final class SandboxProcessManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var processes: [SandboxProcessInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var totalCPUUsage: Double = 0
    @Published private(set) var totalMemoryUsage: Int64 = 0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.craigoclean.sandbox", category: "ProcessManager")
    private var updateTimer: Timer?
    private var previousCPUTicks: [Int32: (user: UInt64, system: UInt64, time: Date)] = [:]
    private let maxproc: Int = 4096

    /// Our own process info for safety checks
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let ownBundleID = Bundle.main.bundleIdentifier
    private let ownRunningApp = NSRunningApplication.current

    // MARK: - Initialization

    init() {
        logger.info("SandboxProcessManager initialized")
        initializeCPUTicks()
        startAutoUpdate()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Start automatic process list updates
    func startAutoUpdate() {
        updateProcessList()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: SandboxConfiguration.Timing.processRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateProcessList()
            }
        }
    }

    /// Stop automatic updates
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Manually refresh the process list
    func updateProcessList() {
        isLoading = true

        Task {
            let runningProcesses = await fetchRunningProcesses()

            await MainActor.run {
                self.processes = runningProcesses.sorted { $0.memoryUsage > $1.memoryUsage }
                self.totalCPUUsage = runningProcesses.reduce(0) { $0 + $1.cpuUsage }
                self.totalMemoryUsage = runningProcesses.reduce(0) { $0 + $1.memoryUsage }
                self.isLoading = false
            }
        }
    }

    /// Gracefully quit an application
    func quitApp(_ process: SandboxProcessInfo) async -> TerminationResult {
        // Safety check: never terminate ourselves
        guard !isSelfProcess(process) else {
            logger.warning("Prevented self-termination attempt")
            return .protectedProcess
        }

        // Safety check: don't terminate critical processes
        guard !isProtectedProcess(process) else {
            logger.warning("Prevented termination of protected process: \(process.name)")
            return .protectedProcess
        }

        // Find the NSRunningApplication
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == process.pid }) else {
            return .alreadyTerminated
        }

        // Try graceful termination
        if app.terminate() {
            logger.info("Gracefully terminated: \(process.name)")

            // Wait a moment and verify
            try? await Task.sleep(nanoseconds: 500_000_000)

            let stillRunning = NSWorkspace.shared.runningApplications.contains {
                $0.processIdentifier == process.pid
            }

            return stillRunning ? .failed(nil) : .success
        }

        return .failed(nil)
    }

    /// Force quit an application
    func forceQuitApp(_ process: SandboxProcessInfo) async -> TerminationResult {
        // Safety check: never terminate ourselves
        guard !isSelfProcess(process) else {
            logger.warning("Prevented self force-quit attempt")
            return .protectedProcess
        }

        // Safety check: don't terminate critical processes
        guard !isProtectedProcess(process) else {
            logger.warning("Prevented force-quit of protected process: \(process.name)")
            return .protectedProcess
        }

        // Find the NSRunningApplication
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == process.pid }) {
            // Try force terminate
            if app.forceTerminate() {
                logger.info("Force terminated via NSRunningApplication: \(process.name)")

                // Wait and verify
                for _ in 1...5 {
                    try? await Task.sleep(nanoseconds: 200_000_000)

                    let stillRunning = NSWorkspace.shared.runningApplications.contains {
                        $0.processIdentifier == process.pid
                    }

                    if !stillRunning {
                        cleanupProcessData(pid: process.pid)
                        return .success
                    }
                }
            }
        }

        // Fallback: try POSIX signals (SIGTERM then SIGKILL)
        // These work within sandbox for processes owned by the same user

        // Try SIGTERM first
        let termResult = kill(process.pid, SIGTERM)
        if termResult == 0 {
            logger.info("Sent SIGTERM to: \(process.name)")

            // Wait for graceful termination
            for _ in 1...5 {
                try? await Task.sleep(nanoseconds: 200_000_000)

                if kill(process.pid, 0) != 0 {
                    cleanupProcessData(pid: process.pid)
                    return .success
                }
            }

            // Still running, send SIGKILL
            let killResult = kill(process.pid, SIGKILL)
            if killResult == 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)

                if kill(process.pid, 0) != 0 {
                    logger.info("Force killed via SIGKILL: \(process.name)")
                    cleanupProcessData(pid: process.pid)
                    return .success
                }
            } else {
                let errorString = String(cString: strerror(errno))
                logger.error("SIGKILL failed for \(process.name): \(errorString)")
            }
        } else if errno == EPERM {
            logger.warning("Permission denied for \(process.name) - may require elevated privileges")
            return .accessDenied
        }

        return .failed(nil)
    }

    /// Get top memory consumers
    func getTopMemoryConsumers(limit: Int = 5) -> [SandboxProcessInfo] {
        return Array(processes
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(limit))
    }

    /// Get top CPU consumers
    func getTopCPUConsumers(limit: Int = 5) -> [SandboxProcessInfo] {
        return Array(processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
            .prefix(limit))
    }

    /// Get background apps (non-regular activation policy)
    func getBackgroundApps() -> [SandboxProcessInfo] {
        let backgroundApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy != .regular }
            .map { $0.processIdentifier }

        return processes.filter { backgroundApps.contains($0.pid) }
    }

    // MARK: - Private Methods

    private func initializeCPUTicks() {
        let pidsPointer = UnsafeMutablePointer<Int32>.allocate(capacity: maxproc)
        defer { pidsPointer.deallocate() }

        let count = proc_listallpids(pidsPointer, Int32(MemoryLayout<Int32>.size * maxproc))
        guard count > 0 else { return }

        let pids = Array(UnsafeBufferPointer(start: pidsPointer, count: Int(count)))
        let currentTime = Date()

        for pid in pids where pid > 0 {
            var taskInfo = proc_taskinfo()
            let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize)

            if result > 0 {
                previousCPUTicks[pid] = (
                    user: taskInfo.pti_total_user,
                    system: taskInfo.pti_total_system,
                    time: currentTime
                )
            }
        }
    }

    private func fetchRunningProcesses() async -> [SandboxProcessInfo] {
        var processes: [SandboxProcessInfo] = []

        // Get running applications from NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let localizedName = app.localizedName else { continue }

            let details = getDetailedProcessInfo(for: app.processIdentifier)

            let processInfo = SandboxProcessInfo(
                pid: app.processIdentifier,
                name: localizedName,
                bundleIdentifier: app.bundleIdentifier,
                isUserApp: app.activationPolicy == .regular,
                cpuUsage: details?.cpuUsage ?? 0,
                memoryUsage: details?.memoryUsage ?? 0,
                creationTime: details?.creationTime,
                parentPID: details?.parentPID,
                executablePath: details?.executablePath,
                threads: details?.threads ?? 0,
                uid: details?.uid ?? 0,
                icon: app.icon
            )

            processes.append(processInfo)
        }

        return processes
    }

    private func getDetailedProcessInfo(for pid: Int32) -> (
        cpuUsage: Double,
        memoryUsage: Int64,
        creationTime: Date?,
        parentPID: Int32?,
        executablePath: String?,
        threads: Int32?,
        uid: uid_t?
    )? {
        // Get BSD info
        var bsdInfo = proc_bsdinfo()
        let bsdSize = MemoryLayout<proc_bsdinfo>.size
        let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(bsdSize))
        guard bsdResult == Int32(bsdSize) else { return nil }

        // Get task info
        var taskInfo = proc_taskinfo()
        let taskSize = MemoryLayout<proc_taskinfo>.size
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(taskSize))

        let memoryUsage = taskResult == Int32(taskSize) ? Int64(taskInfo.pti_resident_size) : 0
        let threads = taskResult == Int32(taskSize) ? taskInfo.pti_threadnum : 0

        // Calculate CPU usage
        let cpuUsage = calculateCPUUsage(for: pid, taskInfo: taskResult == Int32(taskSize) ? taskInfo : nil)

        // Get creation time
        let creationTime = Date(
            timeIntervalSince1970: TimeInterval(bsdInfo.pbi_start_tvsec) +
            TimeInterval(bsdInfo.pbi_start_tvusec) / 1_000_000
        )

        // Get executable path
        var pathBuffer = [Int8](repeating: 0, count: 4096)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(4096))
        let executablePath = pathLength > 0 ? String(cString: pathBuffer) : nil

        return (
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            creationTime: creationTime,
            parentPID: Int32(bsdInfo.pbi_ppid),
            executablePath: executablePath,
            threads: threads,
            uid: bsdInfo.pbi_uid
        )
    }

    private func calculateCPUUsage(for pid: Int32, taskInfo: proc_taskinfo?) -> Double {
        guard let taskInfo = taskInfo else { return 0.0 }

        let currentTime = Date()
        let currentUser = taskInfo.pti_total_user
        let currentSystem = taskInfo.pti_total_system

        defer {
            previousCPUTicks[pid] = (user: currentUser, system: currentSystem, time: currentTime)
        }

        guard let previous = previousCPUTicks[pid] else { return 0.0 }

        let timeDelta = currentTime.timeIntervalSince(previous.time)
        guard timeDelta > 0 else { return 0.0 }

        let userDelta = currentUser - previous.user
        let systemDelta = currentSystem - previous.system
        let totalDelta = userDelta + systemDelta

        // Convert from nanoseconds to seconds
        let cpuTime = Double(totalDelta) / 1_000_000_000.0
        let cpuUsage = (cpuTime / timeDelta) * 100.0

        return min(cpuUsage, 100.0)
    }

    private func isSelfProcess(_ process: SandboxProcessInfo) -> Bool {
        // Multiple safety checks
        if process.pid == ownPID { return true }
        if process.bundleIdentifier == ownBundleID { return true }
        if process.pid == ownRunningApp.processIdentifier { return true }

        // Check against known bundle ID variations
        if let bundleID = process.bundleIdentifier,
           SandboxConfiguration.excludedBundleIdentifiers.contains(bundleID) {
            return true
        }

        return false
    }

    private func isProtectedProcess(_ process: SandboxProcessInfo) -> Bool {
        // Check name against critical processes
        if SandboxConfiguration.criticalProcessNames.contains(process.name) {
            return true
        }

        // Check bundle ID against excluded list
        if let bundleID = process.bundleIdentifier,
           SandboxConfiguration.excludedBundleIdentifiers.contains(bundleID) {
            return true
        }

        return false
    }

    private func cleanupProcessData(pid: Int32) {
        previousCPUTicks.removeValue(forKey: pid)
    }
}

// MARK: - Process Filtering Extensions

extension SandboxProcessManager {

    /// Filter processes by memory threshold
    func processes(withMemoryAbove threshold: Int64) -> [SandboxProcessInfo] {
        return processes.filter { $0.memoryUsage > threshold }
    }

    /// Filter processes by CPU threshold
    func processes(withCPUAbove threshold: Double) -> [SandboxProcessInfo] {
        return processes.filter { $0.cpuUsage > threshold }
    }

    /// Get processes grouped by category
    func processesGroupedByCategory() -> [String: [SandboxProcessInfo]] {
        var groups: [String: [SandboxProcessInfo]] = [
            "Heavy Memory (>500 MB)": [],
            "Moderate Memory (100-500 MB)": [],
            "Light (<100 MB)": [],
            "Background Apps": []
        ]

        let backgroundPIDs = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy != .regular }
                .map { $0.processIdentifier }
        )

        for process in processes {
            if backgroundPIDs.contains(process.pid) {
                groups["Background Apps"]?.append(process)
            } else if process.memoryUsage > 500 * 1024 * 1024 {
                groups["Heavy Memory (>500 MB)"]?.append(process)
            } else if process.memoryUsage > 100 * 1024 * 1024 {
                groups["Moderate Memory (100-500 MB)"]?.append(process)
            } else {
                groups["Light (<100 MB)"]?.append(process)
            }
        }

        return groups
    }
}
