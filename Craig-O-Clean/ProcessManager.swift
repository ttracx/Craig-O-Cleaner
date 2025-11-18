import Foundation
import AppKit

// Constants
private let PROC_PIDPATHINFO_MAXSIZE: Int = 1024 * 4

// MARK: - Enhanced Process Information Model
struct ProcessInfo: Identifiable, Hashable {
    let id: Int32
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
        self.id = pid
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
            
            if cpuHistory[process.id] == nil {
                cpuHistory[process.id] = []
            }
            
            cpuHistory[process.id]?.append(cpuData)
            
            // Keep only the last maxHistoryPoints data points
            if let count = cpuHistory[process.id]?.count, count > maxHistoryPoints {
                cpuHistory[process.id]?.removeFirst(count - maxHistoryPoints)
            }
        }
        
        // Clean up history for processes that no longer exist
        let currentPIDs = Set(processes.map { $0.id })
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
            let alreadyExists = processes.contains { $0.id == pid }
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
        // First try graceful termination
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == process.id }) {
            return app.terminate()
        }
        
        // Fall back to SIGTERM for system processes
        let result = kill(process.id, SIGTERM)
        if result == 0 {
            // Clean up history for terminated process
            await MainActor.run {
                cpuHistory.removeValue(forKey: process.id)
                previousCPUTicks.removeValue(forKey: process.id)
            }
            return true
        }
        
        return false
    }
    
    func forceQuitProcess(_ process: ProcessInfo) async -> Bool {
        // Force quit with SIGKILL
        let result = kill(process.id, SIGKILL)
        if result == 0 {
            // Clean up history for terminated process
            await MainActor.run {
                cpuHistory.removeValue(forKey: process.id)
                previousCPUTicks.removeValue(forKey: process.id)
            }
            return true
        }
        return false
    }
    
    func getProcessDetails(for process: ProcessInfo) -> ProcessDetails {
        return ProcessDetails(
            process: process,
            cpuHistory: getCPUHistory(for: process.id),
            networkConnections: [], // Would require additional implementation
            openFiles: getOpenFiles(for: process.id),
            environmentVariables: [:] // Would require additional implementation
        )
    }
    
    private func getOpenFiles(for pid: Int32) -> [String] {
        // This is a simplified implementation
        // In practice, you'd use lsof or similar system calls
        return []
    }
}