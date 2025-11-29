// SystemMetricsService.swift
// ClearMind Control Center
//
// Comprehensive system metrics service for monitoring CPU, RAM, disk, and network
// Uses low-level system APIs for accurate real-time data

import Foundation
import Combine

// MARK: - Memory Metrics

/// Detailed memory information
struct MemoryMetrics {
    let totalMemory: UInt64         // Total physical RAM in bytes
    let usedMemory: UInt64          // Currently used memory
    let freeMemory: UInt64          // Free memory
    let activeMemory: UInt64        // Active (recently used) memory
    let inactiveMemory: UInt64      // Inactive (can be reclaimed) memory
    let wiredMemory: UInt64         // Wired (cannot be paged out) memory
    let compressedMemory: UInt64    // Compressed memory
    let swapUsed: UInt64            // Swap space used
    let swapTotal: UInt64           // Total swap space
    
    var memoryPressure: MemoryPressureLevel {
        let usedRatio = Double(usedMemory) / Double(totalMemory)
        if usedRatio < 0.5 { return .normal }
        else if usedRatio < 0.75 { return .moderate }
        else if usedRatio < 0.9 { return .high }
        else { return .critical }
    }
    
    var usedPercentage: Double {
        Double(usedMemory) / Double(totalMemory) * 100
    }
    
    var freePercentage: Double {
        100 - usedPercentage
    }
    
    // Formatted strings
    var totalFormatted: String { formatBytes(totalMemory) }
    var usedFormatted: String { formatBytes(usedMemory) }
    var freeFormatted: String { formatBytes(freeMemory) }
    var activeFormatted: String { formatBytes(activeMemory) }
    var inactiveFormatted: String { formatBytes(inactiveMemory) }
    var wiredFormatted: String { formatBytes(wiredMemory) }
    var compressedFormatted: String { formatBytes(compressedMemory) }
    var swapUsedFormatted: String { formatBytes(swapUsed) }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576.0
            return String(format: "%.0f MB", mb)
        }
    }
}

/// Memory pressure levels
enum MemoryPressureLevel: String, CaseIterable {
    case normal = "Normal"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// MARK: - CPU Metrics

/// Detailed CPU information
struct CPUMetrics {
    let overallUsage: Double        // Overall CPU usage percentage
    let userUsage: Double           // User space CPU usage
    let systemUsage: Double         // Kernel space CPU usage
    let idlePercentage: Double      // Idle percentage
    let coreCount: Int              // Number of CPU cores
    let perCoreUsage: [Double]      // Per-core usage percentages
    let loadAverage: (one: Double, five: Double, fifteen: Double)
    
    var cpuPressure: CPUPressureLevel {
        if overallUsage < 30 { return .low }
        else if overallUsage < 60 { return .medium }
        else if overallUsage < 85 { return .high }
        else { return .critical }
    }
}

/// CPU pressure levels
enum CPUPressureLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Disk Metrics

/// Disk usage information
struct DiskMetrics {
    let totalSpace: UInt64
    let usedSpace: UInt64
    let freeSpace: UInt64
    let volumeName: String
    
    var usedPercentage: Double {
        Double(usedSpace) / Double(totalSpace) * 100
    }
    
    var freePercentage: Double {
        100 - usedPercentage
    }
    
    var totalFormatted: String { formatBytes(totalSpace) }
    var usedFormatted: String { formatBytes(usedSpace) }
    var freeFormatted: String { formatBytes(freeSpace) }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1024 {
            return String(format: "%.1f TB", gb / 1024)
        }
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Network Metrics

/// Network usage information
struct NetworkMetrics {
    let bytesReceived: UInt64
    let bytesSent: UInt64
    let packetsReceived: UInt64
    let packetsSent: UInt64
    let receiveRate: Double     // bytes per second
    let sendRate: Double        // bytes per second
    
    var receiveRateFormatted: String { formatRate(receiveRate) }
    var sendRateFormatted: String { formatRate(sendRate) }
    
    private func formatRate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_073_741_824 {
            return String(format: "%.1f GB/s", bytesPerSecond / 1_073_741_824)
        } else if bytesPerSecond >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        } else if bytesPerSecond >= 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}

// MARK: - System Health Summary

/// Overall system health summary
struct SystemHealthSummary {
    let memory: MemoryMetrics
    let cpu: CPUMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics?
    let timestamp: Date
    
    var overallHealth: SystemHealthLevel {
        // Calculate overall health based on memory and CPU
        let memoryScore: Int
        switch memory.memoryPressure {
        case .normal: memoryScore = 4
        case .moderate: memoryScore = 3
        case .high: memoryScore = 2
        case .critical: memoryScore = 1
        }
        
        let cpuScore: Int
        switch cpu.cpuPressure {
        case .low: cpuScore = 4
        case .medium: cpuScore = 3
        case .high: cpuScore = 2
        case .critical: cpuScore = 1
        }
        
        let average = (memoryScore + cpuScore) / 2
        
        switch average {
        case 4: return .excellent
        case 3: return .good
        case 2: return .fair
        default: return .poor
        }
    }
}

/// System health levels
enum SystemHealthLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var icon: String {
        switch self {
        case .excellent: return "heart.fill"
        case .good: return "heart.fill"
        case .fair: return "heart"
        case .poor: return "heart.slash"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - System Metrics Service

/// Service for monitoring system metrics
@MainActor
class SystemMetricsService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var memoryMetrics: MemoryMetrics?
    @Published var cpuMetrics: CPUMetrics?
    @Published var diskMetrics: DiskMetrics?
    @Published var networkMetrics: NetworkMetrics?
    @Published var healthSummary: SystemHealthSummary?
    @Published var isUpdating = false
    
    // Historical data for charts
    @Published var cpuHistory: [CPUHistoryPoint] = []
    @Published var memoryHistory: [MemoryHistoryPoint] = []
    
    // MARK: - Private Properties
    
    private var updateTimer: Timer?
    private var previousNetworkBytes: (received: UInt64, sent: UInt64)?
    private var previousNetworkTime: Date?
    private var previousCPUInfo: host_cpu_load_info?
    
    private let maxHistoryPoints = 60  // Keep 1 minute of history
    
    // MARK: - Initialization
    
    init() {
        updateAllMetrics()
        startAutoUpdate(interval: 2.0)
    }
    
    deinit {
        stopAutoUpdate()
    }
    
    // MARK: - Auto Update
    
    func startAutoUpdate(interval: TimeInterval = 2.0) {
        stopAutoUpdate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllMetrics()
            }
        }
    }
    
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Update Methods
    
    func updateAllMetrics() {
        isUpdating = true
        
        Task {
            async let memory = fetchMemoryMetrics()
            async let cpu = fetchCPUMetrics()
            async let disk = fetchDiskMetrics()
            async let network = fetchNetworkMetrics()
            
            let memResult = await memory
            let cpuResult = await cpu
            let diskResult = await disk
            let netResult = await network
            
            await MainActor.run {
                self.memoryMetrics = memResult
                self.cpuMetrics = cpuResult
                self.diskMetrics = diskResult
                self.networkMetrics = netResult
                
                // Update health summary
                if let mem = memResult, let cpu = cpuResult, let disk = diskResult {
                    self.healthSummary = SystemHealthSummary(
                        memory: mem,
                        cpu: cpu,
                        disk: disk,
                        network: netResult,
                        timestamp: Date()
                    )
                }
                
                // Update history
                self.updateHistory()
                
                self.isUpdating = false
            }
        }
    }
    
    private func updateHistory() {
        let now = Date()
        
        // CPU history
        if let cpu = cpuMetrics {
            cpuHistory.append(CPUHistoryPoint(timestamp: now, usage: cpu.overallUsage))
            if cpuHistory.count > maxHistoryPoints {
                cpuHistory.removeFirst(cpuHistory.count - maxHistoryPoints)
            }
        }
        
        // Memory history
        if let mem = memoryMetrics {
            memoryHistory.append(MemoryHistoryPoint(timestamp: now, usedPercentage: mem.usedPercentage))
            if memoryHistory.count > maxHistoryPoints {
                memoryHistory.removeFirst(memoryHistory.count - maxHistoryPoints)
            }
        }
    }
    
    // MARK: - Memory Metrics
    
    private func fetchMemoryMetrics() async -> MemoryMetrics? {
        // Get total physical memory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Get VM statistics
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        let pageSize = UInt64(vm_page_size)
        
        let freeMemory = UInt64(vmStats.free_count) * pageSize
        let activeMemory = UInt64(vmStats.active_count) * pageSize
        let inactiveMemory = UInt64(vmStats.inactive_count) * pageSize
        let wiredMemory = UInt64(vmStats.wire_count) * pageSize
        let compressedMemory = UInt64(vmStats.compressor_page_count) * pageSize
        
        let usedMemory = activeMemory + wiredMemory + compressedMemory
        
        // Get swap info
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapResult = sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        
        let swapUsed = swapResult == 0 ? UInt64(swapUsage.xsu_used) : 0
        let swapTotal = swapResult == 0 ? UInt64(swapUsage.xsu_total) : 0
        
        return MemoryMetrics(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            freeMemory: freeMemory,
            activeMemory: activeMemory,
            inactiveMemory: inactiveMemory,
            wiredMemory: wiredMemory,
            compressedMemory: compressedMemory,
            swapUsed: swapUsed,
            swapTotal: swapTotal
        )
    }
    
    // MARK: - CPU Metrics
    
    private func fetchCPUMetrics() async -> CPUMetrics? {
        var coreCount: natural_t = 0
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &coreCount,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS else { return nil }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
        }
        
        var perCoreUsage: [Double] = []
        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0
        
        for i in 0..<Int(coreCount) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(CPU_STATE_MAX) * i).withMemoryRebound(
                to: integer_t.self,
                capacity: Int(CPU_STATE_MAX)
            ) { $0 }
            
            let user = Double(cpuLoadInfo[Int(CPU_STATE_USER)])
            let system = Double(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            let nice = Double(cpuLoadInfo[Int(CPU_STATE_NICE)])
            
            let total = user + system + idle + nice
            
            if total > 0 {
                let usage = ((user + system + nice) / total) * 100.0
                perCoreUsage.append(usage)
                
                totalUser += user
                totalSystem += system
                totalIdle += idle
            } else {
                perCoreUsage.append(0)
            }
        }
        
        let totalTicks = totalUser + totalSystem + totalIdle
        let overallUsage = totalTicks > 0 ? ((totalUser + totalSystem) / totalTicks) * 100 : 0
        let userUsage = totalTicks > 0 ? (totalUser / totalTicks) * 100 : 0
        let systemUsage = totalTicks > 0 ? (totalSystem / totalTicks) * 100 : 0
        let idlePercentage = totalTicks > 0 ? (totalIdle / totalTicks) * 100 : 0
        
        // Get load averages
        var loadAvg: [Double] = [0, 0, 0]
        let loadResult = getloadavg(&loadAvg, 3)
        let loadAverage = loadResult >= 3 ? (loadAvg[0], loadAvg[1], loadAvg[2]) : (0.0, 0.0, 0.0)
        
        return CPUMetrics(
            overallUsage: overallUsage,
            userUsage: userUsage,
            systemUsage: systemUsage,
            idlePercentage: idlePercentage,
            coreCount: Int(coreCount),
            perCoreUsage: perCoreUsage,
            loadAverage: loadAverage
        )
    }
    
    // MARK: - Disk Metrics
    
    private func fetchDiskMetrics() async -> DiskMetrics? {
        let fileManager = FileManager.default
        let homeURL = fileManager.homeDirectoryForCurrentUser
        
        do {
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeNameKey
            ])
            
            let totalSpace = UInt64(values.volumeTotalCapacity ?? 0)
            let freeSpace = UInt64(values.volumeAvailableCapacity ?? 0)
            let volumeName = values.volumeName ?? "Macintosh HD"
            
            return DiskMetrics(
                totalSpace: totalSpace,
                usedSpace: totalSpace - freeSpace,
                freeSpace: freeSpace,
                volumeName: volumeName
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - Network Metrics
    
    private func fetchNetworkMetrics() async -> NetworkMetrics? {
        // Use netstat-style approach via system
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else { return nil }
        defer { freeifaddrs(ifaddrs) }
        
        var totalReceived: UInt64 = 0
        var totalSent: UInt64 = 0
        
        var addr = firstAddr
        while true {
            if addr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(addr.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalReceived += UInt64(data.pointee.ifi_ibytes)
                totalSent += UInt64(data.pointee.ifi_obytes)
            }
            
            guard let next = addr.pointee.ifa_next else { break }
            addr = next
        }
        
        // Calculate rates
        let now = Date()
        var receiveRate: Double = 0
        var sendRate: Double = 0
        
        if let previous = previousNetworkBytes, let prevTime = previousNetworkTime {
            let timeDelta = now.timeIntervalSince(prevTime)
            if timeDelta > 0 {
                receiveRate = Double(totalReceived - previous.received) / timeDelta
                sendRate = Double(totalSent - previous.sent) / timeDelta
            }
        }
        
        previousNetworkBytes = (totalReceived, totalSent)
        previousNetworkTime = now
        
        return NetworkMetrics(
            bytesReceived: totalReceived,
            bytesSent: totalSent,
            packetsReceived: 0,
            packetsSent: 0,
            receiveRate: max(0, receiveRate),
            sendRate: max(0, sendRate)
        )
    }
}

// MARK: - History Points

struct CPUHistoryPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let usage: Double
}

struct MemoryHistoryPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let usedPercentage: Double
}
