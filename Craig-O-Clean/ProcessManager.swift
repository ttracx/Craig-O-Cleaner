import Foundation
import AppKit

// Constants
private let PROC_PIDPATHINFO_MAXSIZE: Int = 1024 * 4

// MARK: - Enhanced Process Information Model
struct ProcessInfo: Identifiable, Hashable {
    var id: Int32 { pid }  // Use PID as stable identity for SwiftUI
    let pid: Int32         // Process ID
    let name: String
    let bundleIdentifier: String?
    let isUserProcess: Bool
    let cpuUsage: Double
    let memoryUsage: Int64
    let creationTime: Date?
    let parentPID: Int32?
    let executablePath: String?
    let threads: Int32
    let ports: Int32
    let arguments: [String]
    let workingDirectory: String?
    let uid: uid_t

    init(pid: Int32, name: String, bundleIdentifier: String? = nil, isUserProcess: Bool = true,
         cpuUsage: Double = 0.0, memoryUsage: Int64 = 0, creationTime: Date? = nil,
         parentPID: Int32? = nil, executablePath: String? = nil, threads: Int32 = 0,
         ports: Int32 = 0, arguments: [String] = [], workingDirectory: String? = nil, uid: uid_t = 0) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isUserProcess = isUserProcess
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.creationTime = creationTime
        self.parentPID = parentPID
        self.executablePath = executablePath
        self.threads = threads
        self.ports = ports
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.uid = uid
    }
    
    // MARK: - Hashable & Equatable (based on PID only for stable identity)
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
    
    static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }
    
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
}

// MARK: - CPU Usage Data
struct CPUUsageData {
    let timestamp: Date
    let usage: Double
}

// MARK: - System CPU Info
struct SystemCPUInfo {
    let coreCount: Int
    let perCoreUsage: [Double]
    let totalUsage: Double
    let systemLoad: (one: Double, five: Double, fifteen: Double)
}

// MARK: - CPU Core Data
struct CPUCoreData: Identifiable {
    let id: Int
    let usage: Double
}

// MARK: - Enhanced Process Manager
@MainActor
class ProcessManager: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var isLoading = false
    @Published var totalCPUUsage: Double = 0
    @Published var totalMemoryUsage: Int64 = 0
    @Published var systemLoad: (one: Double, five: Double, fifteen: Double) = (0, 0, 0)
    @Published var selectedProcessDetails: ProcessDetails?
    @Published var systemCPUInfo: SystemCPUInfo?
    @Published var cpuCoreData: [CPUCoreData] = []

    private var updateTimer: Timer?
    private var cpuHistoryTimer: Timer?
    private var previousCPUTicks: [Int32: (user: UInt64, system: UInt64, time: Date)] = [:]
    private var cpuHistory: [Int32: [CPUUsageData]] = [:] // Store CPU history for each process
    private let maxHistoryPoints = 60 // Keep 60 data points (1 minute at 1 second intervals)
    private var previousSystemCPU: host_cpu_load_info?
    private var previousSystemTime: Date?
    
    init() {
        startAutoUpdate()
        startCPUHistoryTracking()
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        cpuHistoryTimer?.invalidate()
        cpuHistoryTimer = nil
    }
    
    func startAutoUpdate() {
        updateProcessList()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateProcessList()
            }
        }
    }
    
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func startCPUHistoryTracking() {
        cpuHistoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateCPUHistory()
            }
        }
    }
    
    func stopCPUHistoryTracking() {
        cpuHistoryTimer?.invalidate()
        cpuHistoryTimer = nil
    }
    
    func updateProcessList() {
        isLoading = true

        Task {
            let runningProcesses = await fetchRunningProcesses()
            let systemStats = await fetchSystemStats()
            let cpuInfo = await fetchSystemCPUInfo()

            await MainActor.run {
                self.processes = runningProcesses.sorted { $0.name.lowercased() < $1.name.lowercased() }
                self.totalCPUUsage = systemStats.totalCPU
                self.totalMemoryUsage = systemStats.totalMemory
                self.systemLoad = systemStats.systemLoad
                self.systemCPUInfo = cpuInfo
                self.cpuCoreData = cpuInfo.perCoreUsage.enumerated().map { CPUCoreData(id: $0, usage: $1) }
                self.isLoading = false
            }
        }
    }
    
    private func updateCPUHistory() {
        let now = Date()
        
        for process in processes {
            let cpuData = CPUUsageData(timestamp: now, usage: process.cpuUsage)

            if cpuHistory[process.pid] == nil {
                cpuHistory[process.pid] = []
            }

            cpuHistory[process.pid]?.append(cpuData)

            // Keep only the last maxHistoryPoints data points
            if let count = cpuHistory[process.pid]?.count, count > maxHistoryPoints {
                cpuHistory[process.pid]?.removeFirst(count - maxHistoryPoints)
            }
        }
        
        // Clean up history for processes that no longer exist
        let currentPIDs = Set(processes.map { $0.pid })
        cpuHistory = cpuHistory.filter { currentPIDs.contains($0.key) }
    }
    
    func getCPUHistory(for pid: Int32) -> [CPUUsageData] {
        return cpuHistory[pid] ?? []
    }
    
    private func fetchRunningProcesses() async -> [ProcessInfo] {
        var processes: [ProcessInfo] = []
        
        // Get running applications
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let pid = app.processIdentifier as Int32?,
                  let localizedName = app.localizedName else { continue }
            
            let details = getDetailedProcessInfo(for: pid)
            
            let processInfo = ProcessInfo(
                pid: pid,
                name: localizedName,
                bundleIdentifier: app.bundleIdentifier,
                isUserProcess: app.activationPolicy == .regular,
                cpuUsage: details?.cpuUsage ?? 0,
                memoryUsage: details?.memoryUsage ?? 0,
                creationTime: details?.creationTime,
                parentPID: details?.parentPID,
                executablePath: details?.executablePath,
                threads: details?.threads ?? 0,
                ports: details?.ports ?? 0,
                arguments: details?.arguments ?? [],
                workingDirectory: details?.workingDirectory,
                uid: details?.uid ?? 0
            )
            processes.append(processInfo)
        }
        
        // Get system processes using BSD process list
        let systemProcesses = getSystemProcesses()
        processes.append(contentsOf: systemProcesses)
        
        return processes
    }
    
    private func getSystemProcesses() -> [ProcessInfo] {
        var processes: [ProcessInfo] = []
        var processCount: size_t = 0
        
        // Get process count
        let result = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard result > 0 else { return processes }

        processCount = size_t(result) / MemoryLayout<pid_t>.size
        let pids = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(processCount))
        defer { pids.deallocate() }

        let actualResult = proc_listpids(UInt32(PROC_ALL_PIDS), 0, pids, Int32(processCount * MemoryLayout<pid_t>.size))
        guard actualResult > 0 else { return processes }
        
        let actualCount = Int(actualResult) / MemoryLayout<pid_t>.size
        
        for i in 0..<actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            var pathBuffer = [Int8](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
            
            guard pathLength > 0 else { continue }
            
            let processPath = String(cString: pathBuffer)
            let processName = URL(fileURLWithPath: processPath).lastPathComponent
            
            // Skip if we already have this process from NSWorkspace
            let alreadyExists = processes.contains { $0.pid == pid }
            guard !alreadyExists else { continue }
            
            let details = getDetailedProcessInfo(for: pid)
            
            let processInfo = ProcessInfo(
                pid: pid,
                name: processName.isEmpty ? "Unknown Process (\(pid))" : processName,
                bundleIdentifier: nil,
                isUserProcess: false,
                cpuUsage: details?.cpuUsage ?? 0,
                memoryUsage: details?.memoryUsage ?? 0,
                creationTime: details?.creationTime,
                parentPID: details?.parentPID,
                executablePath: processPath,
                threads: details?.threads ?? 0,
                ports: details?.ports ?? 0,
                arguments: details?.arguments ?? [],
                workingDirectory: details?.workingDirectory,
                uid: details?.uid ?? 0
            )
            processes.append(processInfo)
        }
        
        return processes
    }
    
    private func getDetailedProcessInfo(for pid: Int32) -> (cpuUsage: Double, memoryUsage: Int64, creationTime: Date?, parentPID: Int32?, executablePath: String?, threads: Int32?, ports: Int32?, arguments: [String]?, workingDirectory: String?, uid: uid_t?)? {
        
        // Get basic process info
        var bsdInfo = proc_bsdinfo()
        let bsdSize = MemoryLayout<proc_bsdinfo>.size
        let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(bsdSize))
        guard bsdResult == Int32(bsdSize) else { return nil }
        
        // Get task info for memory and threads
        var taskInfo = proc_taskinfo()
        let taskSize = MemoryLayout<proc_taskinfo>.size
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(taskSize))
        
        let memoryUsage = taskResult == Int32(taskSize) ? Int64(taskInfo.pti_resident_size) : 0
        let threads = taskResult == Int32(taskSize) ? taskInfo.pti_threadnum : 0
        
        // Calculate CPU usage
        let cpuUsage = calculateCPUUsage(for: pid, taskInfo: taskResult == Int32(taskSize) ? taskInfo : nil)
        
        // Get creation time
        let creationTime = Date(timeIntervalSince1970: TimeInterval(bsdInfo.pbi_start_tvsec) + TimeInterval(bsdInfo.pbi_start_tvusec) / 1_000_000)
        
        // Get executable path
        var pathBuffer = [Int8](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        let executablePath = pathLength > 0 ? String(cString: pathBuffer) : nil
        
        // Get arguments (simplified)
        let arguments = getProcessArguments(for: pid)
        
        // Get working directory (if available)
        let workingDirectory = getWorkingDirectory(for: pid)
        
        return (
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            creationTime: creationTime,
            parentPID: Int32(bsdInfo.pbi_ppid),
            executablePath: executablePath,
            threads: threads,
            ports: 0, // Port count would require additional system calls
            arguments: arguments,
            workingDirectory: workingDirectory,
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
        
        // Convert from nanoseconds to seconds, then calculate percentage
        let cpuTime = Double(totalDelta) / 1_000_000_000.0 // Convert nanoseconds to seconds
        let cpuUsage = (cpuTime / timeDelta) * 100.0
        
        return min(cpuUsage, 100.0) // Cap at 100%
    }
    
    private func getProcessArguments(for pid: Int32) -> [String] {
        var args: [String] = []
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0
        
        // Get size first
        let result = sysctl(&mib, 3, nil, &size, nil, 0)
        guard result == 0, size > 0 else { return args }
        
        // Allocate buffer and get data
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        
        let dataResult = sysctl(&mib, 3, buffer, &size, nil, 0)
        guard dataResult == 0 else { return args }
        
        // Parse arguments (simplified parsing)
        var offset = MemoryLayout<Int32>.size // Skip argc
        
        // Skip executable path
        while offset < size && buffer[offset] != 0 {
            offset += 1
        }
        offset += 1 // Skip null terminator
        
        // Skip trailing nulls
        while offset < size && buffer[offset] == 0 {
            offset += 1
        }
        
        // Parse arguments
        while offset < size {
            let argStart = buffer.advanced(by: offset)
            let argString = String(cString: argStart)
            if !argString.isEmpty {
                args.append(argString)
            }
            
            offset += argString.utf8.count + 1
            
            // Skip any additional null bytes
            while offset < size && buffer[offset] == 0 {
                offset += 1
            }
        }
        
        return args
    }
    
    private func getWorkingDirectory(for pid: Int32) -> String? {
        var vnodeInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnodeInfo, Int32(size))
        
        guard result == Int32(size) else { return nil }
        
        return withUnsafePointer(to: &vnodeInfo.pvi_cdir.vip_path) { ptr in
            return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }
    
    private func fetchSystemStats() async -> (totalCPU: Double, totalMemory: Int64, systemLoad: (Double, Double, Double)) {
        // Get system load averages
        var loadAvg: [Double] = [0, 0, 0]
        let result = getloadavg(&loadAvg, 3)
        let systemLoad = result >= 3 ? (loadAvg[0], loadAvg[1], loadAvg[2]) : (0.0, 0.0, 0.0)

        // Calculate total CPU usage from all processes
        let totalCPU = processes.reduce(0) { $0 + $1.cpuUsage }

        // Calculate total memory usage
        let totalMemory = processes.reduce(0) { $0 + $1.memoryUsage }

        return (totalCPU, totalMemory, systemLoad)
    }

    private func fetchSystemCPUInfo() async -> SystemCPUInfo {
        var coreCount: natural_t = 0
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &coreCount, &cpuInfo, &numCpuInfo)

        guard result == KERN_SUCCESS else {
            return SystemCPUInfo(coreCount: 0, perCoreUsage: [], totalUsage: 0, systemLoad: (0, 0, 0))
        }

        var perCoreUsage: [Double] = []
        var totalUsage: Double = 0

        for i in 0..<Int(coreCount) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(CPU_STATE_MAX) * i).withMemoryRebound(to: integer_t.self, capacity: Int(CPU_STATE_MAX)) { $0 }

            let user = Double(cpuLoadInfo[Int(CPU_STATE_USER)])
            let system = Double(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            let nice = Double(cpuLoadInfo[Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice

            if total > 0 {
                let usage = ((user + system + nice) / total) * 100.0
                perCoreUsage.append(usage)
                totalUsage += usage
            } else {
                perCoreUsage.append(0)
            }
        }

        if coreCount > 0 {
            totalUsage /= Double(coreCount)
        }

        // Get system load averages
        var loadAvg: [Double] = [0, 0, 0]
        let loadResult = getloadavg(&loadAvg, 3)
        let systemLoad = loadResult >= 3 ? (loadAvg[0], loadAvg[1], loadAvg[2]) : (0.0, 0.0, 0.0)

        return SystemCPUInfo(
            coreCount: Int(coreCount),
            perCoreUsage: perCoreUsage,
            totalUsage: totalUsage,
            systemLoad: systemLoad
        )
    }
    
    func terminateProcess(_ process: ProcessInfo) async -> Bool {
        // First try graceful termination via NSRunningApplication
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == process.pid }) {
            let result = app.terminate()
            if result {
                await cleanupProcessHistory(for: process.pid)
                return true
            }
        }
        
        // Try graceful quit via AppleScript for user apps
        if process.isUserProcess {
            let appleScriptResult = await runAppleScriptQuit(processName: process.name)
            if appleScriptResult {
                await cleanupProcessHistory(for: process.pid)
                return true
            }
        }
        
        // Fall back to SIGTERM for system processes
        let result = kill(process.pid, SIGTERM)
        if result == 0 {
            await cleanupProcessHistory(for: process.pid)
            return true
        }
        
        return false
    }
    
    func forceQuitProcess(_ process: ProcessInfo) async -> Bool {
        // Method 1: Try NSRunningApplication.forceTerminate() first (works for user apps)
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == process.pid }) {
            if app.forceTerminate() {
                await cleanupProcessHistory(for: process.pid)
                return true
            }
        }
        
        // Method 2: Try killall -9 "App Name" via shell command
        if await runShellForceKill(byName: process.name) {
            await cleanupProcessHistory(for: process.pid)
            return true
        }
        
        // Method 3: Try pkill -9 by bundle identifier (if available)
        if let bundleId = process.bundleIdentifier {
            if await runShellForceKill(byBundleId: bundleId) {
                await cleanupProcessHistory(for: process.pid)
                return true
            }
        }
        
        // Method 4: Try kill -9 PID via shell command
        if await runShellForceKill(byPID: process.pid) {
            await cleanupProcessHistory(for: process.pid)
            return true
        }
        
        // Method 5: Last resort - direct SIGKILL (may fail for sandboxed apps)
        let result = kill(process.pid, SIGKILL)
        if result == 0 {
            await cleanupProcessHistory(for: process.pid)
            return true
        }
        
        return false
    }
    
    // MARK: - Shell Command Force Kill Methods
    
    /// Force kill process by application name using: killall -9 "App Name"
    private func runShellForceKill(byName name: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            task.arguments = ["-9", name]
            
            // Suppress output
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus == 0)
            } catch {
                print("[ProcessManager] killall failed for '\(name)': \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Force kill process by bundle identifier using: pkill -9 -f "bundle.identifier"
    private func runShellForceKill(byBundleId bundleId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            task.arguments = ["-9", "-f", bundleId]
            
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus == 0)
            } catch {
                print("[ProcessManager] pkill failed for bundle '\(bundleId)': \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Force kill process by PID using: kill -9 PID
    private func runShellForceKill(byPID pid: Int32) async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/kill")
            task.arguments = ["-9", String(pid)]
            
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus == 0)
            } catch {
                print("[ProcessManager] kill -9 failed for PID \(pid): \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Graceful quit via AppleScript
    private func runAppleScriptQuit(processName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let script = """
            tell application "\(processName)"
                quit
            end tell
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error == nil {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Clean up CPU and tick history for a terminated process
    private func cleanupProcessHistory(for pid: Int32) async {
        await MainActor.run {
            cpuHistory.removeValue(forKey: pid)
            previousCPUTicks.removeValue(forKey: pid)
        }
    }
    
    // MARK: - Batch Kill Methods
    
    /// Kill all helper processes for an app (e.g., "Google Chrome Helper")
    func killAllHelperProcesses(for appName: String) async -> Int {
        let helperNames = [
            "\(appName) Helper",
            "\(appName) Helper (Renderer)",
            "\(appName) Helper (GPU)",
            "\(appName) Helper (Plugin)"
        ]
        
        var killedCount = 0
        for helperName in helperNames {
            if await runShellForceKill(byName: helperName) {
                killedCount += 1
            }
        }
        
        return killedCount
    }
    
    /// Kill a list of known heavy apps to free up memory
    /// Returns array of successfully killed app names
    func killHeavyApps(appNames: [String]? = nil) async -> [String] {
        let defaultHeavyApps = [
            "Google Chrome",
            "Google Chrome Helper",
            "Safari",
            "Firefox",
            "Microsoft Edge",
            "Slack",
            "Discord",
            "Microsoft Teams",
            "Zoom",
            "Xcode",
            "Simulator",
            "Docker Desktop",
            "Android Studio",
            "Spotify"
        ]
        
        let appsToKill = appNames ?? defaultHeavyApps
        var killedApps: [String] = []
        
        for appName in appsToKill {
            // Check if process is actually running before trying to kill
            let isRunning = processes.contains { $0.name == appName }
            if isRunning {
                if await runShellForceKill(byName: appName) {
                    killedApps.append(appName)
                }
            }
        }
        
        // Also kill Chrome helpers specifically
        if appsToKill.contains("Google Chrome") {
            _ = await killAllHelperProcesses(for: "Google Chrome")
        }
        
        // Refresh process list after killing
        updateProcessList()
        
        return killedApps
    }
    
    /// Restart Finder (common fix for UI issues)
    func restartFinder() async -> Bool {
        return await runShellForceKill(byName: "Finder")
        // Finder will automatically restart after being killed
    }
    
    /// Restart Dock (common fix for UI issues)
    func restartDock() async -> Bool {
        return await runShellForceKill(byName: "Dock")
        // Dock will automatically restart after being killed
    }
    
    /// Force kill process using AppleScript with administrator privileges (prompts for password)
    func forceQuitWithAdminPrivileges(_ process: ProcessInfo) async -> Bool {
        return await withCheckedContinuation { continuation in
            let script = """
            do shell script "kill -9 \(process.pid)" with administrator privileges
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error == nil {
                    continuation.resume(returning: true)
                } else {
                    print("[ProcessManager] Admin kill failed: \(error ?? [:])")
                    continuation.resume(returning: false)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    func getProcessDetails(for process: ProcessInfo) -> ProcessDetails {
        return ProcessDetails(
            process: process,
            cpuHistory: getCPUHistory(for: process.pid),
            networkConnections: getNetworkConnections(for: process.pid),
            openFiles: getOpenFiles(for: process.pid),
            environmentVariables: getEnvironmentVariables(for: process.pid)
        )
    }
    
    /// Get open files for a process using lsof
    private func getOpenFiles(for pid: Int32) -> [String] {
        var openFiles: [String] = []
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", "\(pid)", "-F", "n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if line.hasPrefix("n") && !line.hasPrefix("n->") {
                        let path = String(line.dropFirst()) // Remove 'n' prefix
                        if path.hasPrefix("/") && !path.contains("(") {
                            openFiles.append(path)
                        }
                    }
                }
            }
        } catch {
            // lsof may fail for system processes, return empty array
        }
        
        return Array(openFiles.prefix(100)) // Limit to first 100 files
    }
    
    /// Get network connections for a process using lsof
    private func getNetworkConnections(for pid: Int32) -> [NetworkConnection] {
        var connections: [NetworkConnection] = []
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", "\(pid)", "-i", "-n", "-P"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines.dropFirst() { // Skip header
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        // Parse the connection info
                        // Format: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
                        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if components.count >= 9 {
                            let protocolType = components.count > 7 ? components[7] : "TCP"
                            let connectionStr = components.last ?? ""
                            
                            // Parse connection string like "192.168.1.1:443->10.0.0.1:12345 (ESTABLISHED)"
                            if let connection = parseNetworkConnection(connectionStr, protocolType: protocolType) {
                                connections.append(connection)
                            }
                        }
                    }
                }
            }
        } catch {
            // lsof may fail for system processes, return empty array
        }
        
        return connections
    }
    
    /// Parse a network connection string from lsof output
    private func parseNetworkConnection(_ connectionStr: String, protocolType: String) -> NetworkConnection? {
        // Common formats:
        // "localhost:8080->remotehost:443 (ESTABLISHED)"
        // "*:8080 (LISTEN)"
        // "[::1]:8080->[::1]:54321 (ESTABLISHED)"
        
        var localAddr = "*"
        var localPort = 0
        var remoteAddr = "*"
        var remotePort = 0
        var state = "UNKNOWN"
        
        // Extract state if present
        if let stateMatch = connectionStr.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
            state = String(connectionStr[stateMatch]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        // Remove state from connection string for parsing
        let cleanStr = connectionStr.replacingOccurrences(of: "\\s*\\([^)]+\\)", with: "", options: .regularExpression)
        
        // Check for arrow (connection with remote)
        if cleanStr.contains("->") {
            let parts = cleanStr.components(separatedBy: "->")
            if parts.count >= 2 {
                // Parse local address:port
                if let (addr, port) = parseAddressPort(parts[0]) {
                    localAddr = addr
                    localPort = port
                }
                // Parse remote address:port
                if let (addr, port) = parseAddressPort(parts[1]) {
                    remoteAddr = addr
                    remotePort = port
                }
            }
        } else {
            // Just local listening
            if let (addr, port) = parseAddressPort(cleanStr) {
                localAddr = addr
                localPort = port
            }
        }
        
        return NetworkConnection(
            localAddress: localAddr,
            localPort: localPort,
            remoteAddress: remoteAddr,
            remotePort: remotePort,
            state: state,
            protocolType: protocolType
        )
    }
    
    /// Parse address:port string
    private func parseAddressPort(_ str: String) -> (String, Int)? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        
        // Handle IPv6 addresses like [::1]:8080
        if trimmed.hasPrefix("[") {
            if let closeBracket = trimmed.lastIndex(of: "]") {
                let addr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                let afterBracket = trimmed.index(after: closeBracket)
                if afterBracket < trimmed.endIndex && trimmed[afterBracket] == ":" {
                    let portStr = String(trimmed[trimmed.index(after: afterBracket)...])
                    if let port = Int(portStr) {
                        return (addr, port)
                    }
                }
            }
        } else {
            // Handle IPv4 addresses like 192.168.1.1:8080 or hostname:8080
            if let lastColon = trimmed.lastIndex(of: ":") {
                let addr = String(trimmed[..<lastColon])
                let portStr = String(trimmed[trimmed.index(after: lastColon)...])
                if let port = Int(portStr) {
                    return (addr, port)
                }
            }
        }
        
        return nil
    }
    
    /// Get environment variables for a process
    private func getEnvironmentVariables(for pid: Int32) -> [String: String] {
        var envVars: [String: String] = [:]
        
        // Use ps command to get environment variables
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-E", "-ww", "-o", "command="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Alternatively, try to read from /proc if available
            // Since macOS doesn't have /proc, we'll parse what we can
            // from KERN_PROCARGS2 for more detailed environment access
            
            var mib = [CTL_KERN, KERN_PROCARGS2, pid]
            var size: size_t = 0
            
            guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else {
                return envVars
            }
            
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
            defer { buffer.deallocate() }
            
            guard sysctl(&mib, 3, buffer, &size, nil, 0) == 0 else {
                return envVars
            }
            
            // Skip argc
            var offset = MemoryLayout<Int32>.size
            
            // Skip executable path
            while offset < size && buffer[offset] != 0 {
                offset += 1
            }
            offset += 1
            
            // Skip trailing nulls
            while offset < size && buffer[offset] == 0 {
                offset += 1
            }
            
            // Skip argv
            while offset < size {
                if buffer[offset] == 0 {
                    offset += 1
                    if offset < size && buffer[offset] == 0 {
                        // Found double null - end of argv
                        offset += 1
                        break
                    }
                } else {
                    offset += 1
                }
            }
            
            // Skip to environment variables (after argv)
            while offset < size && buffer[offset] == 0 {
                offset += 1
            }
            
            // Parse environment variables
            while offset < size {
                let envStart = buffer.advanced(by: offset)
                let envString = String(cString: envStart)
                
                if envString.isEmpty {
                    break
                }
                
                // Parse KEY=VALUE format
                if let equalsIndex = envString.firstIndex(of: "=") {
                    let key = String(envString[..<equalsIndex])
                    let value = String(envString[envString.index(after: equalsIndex)...])
                    envVars[key] = value
                }
                
                offset += envString.utf8.count + 1
            }
        } catch {
            // Failed to get environment variables
        }
        
        return envVars
    }
    
    /// Get port count for a process using lsof
    func getPortCount(for pid: Int32) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", "\(pid)", "-i", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                    .filter { !$0.isEmpty && !$0.hasPrefix("COMMAND") }
                return Int32(lines.count)
            }
        } catch {
            // lsof may fail for system processes
        }
        
        return 0
    }
}