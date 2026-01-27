// MARK: - SystemMetricsService.swift
// CraigOClean Control Center - System Metrics Service
// Provides comprehensive system monitoring for CPU, RAM, swap, memory pressure, disk, and network.
// Optimized for Apple Silicon (M-series) Macs running macOS 14+ (Sonoma)

import Foundation
import Combine
import os.log

// MARK: - Memory Pressure Level
enum MemoryPressureLevel: String, CaseIterable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .normal: return "System memory is healthy"
        case .warning: return "Memory pressure is elevated"
        case .critical: return "Memory is under high pressure"
        }
    }
}

// MARK: - System Metrics Data Models

struct CPUMetrics: Equatable {
    let userUsage: Double      // User-space CPU usage percentage
    let systemUsage: Double    // System (kernel) CPU usage percentage
    let idleUsage: Double      // Idle CPU percentage
    let totalUsage: Double     // Total CPU usage (user + system)
    let coreCount: Int         // Number of CPU cores
    let perCoreUsage: [Double] // Per-core usage percentages
    let loadAverage: (one: Double, five: Double, fifteen: Double)
    
    static func == (lhs: CPUMetrics, rhs: CPUMetrics) -> Bool {
        return lhs.totalUsage == rhs.totalUsage && lhs.coreCount == rhs.coreCount
    }
}

struct MemoryMetrics: Equatable {
    let totalRAM: UInt64           // Total physical RAM in bytes
    let usedRAM: UInt64            // Used RAM in bytes
    let freeRAM: UInt64            // Free RAM in bytes
    let activeRAM: UInt64          // Active memory in bytes
    let inactiveRAM: UInt64        // Inactive memory in bytes
    let wiredRAM: UInt64           // Wired (non-pageable) memory in bytes
    let compressedRAM: UInt64      // Compressed memory in bytes
    let cachedFiles: UInt64        // Cached files memory in bytes
    let swapUsed: UInt64           // Swap usage in bytes
    let swapTotal: UInt64          // Total swap in bytes
    let pressureLevel: MemoryPressureLevel
    let pressurePercentage: Double // 0-100 percentage
    
    var usedPercentage: Double {
        guard totalRAM > 0 else { return 0 }
        return Double(usedRAM) / Double(totalRAM) * 100
    }
    
    var availableRAM: UInt64 {
        return freeRAM + inactiveRAM + cachedFiles
    }
    
    static func == (lhs: MemoryMetrics, rhs: MemoryMetrics) -> Bool {
        return lhs.totalRAM == rhs.totalRAM && lhs.usedRAM == rhs.usedRAM
    }
}

struct DiskMetrics: Equatable {
    let totalSpace: UInt64     // Total disk space in bytes
    let usedSpace: UInt64      // Used disk space in bytes
    let freeSpace: UInt64      // Free disk space in bytes
    let mountPoint: String     // Mount point (e.g., "/")
    let fileSystem: String     // File system type
    
    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

struct NetworkMetrics: Equatable {
    let bytesIn: UInt64        // Bytes received
    let bytesOut: UInt64       // Bytes sent
    let packetsIn: UInt64      // Packets received
    let packetsOut: UInt64     // Packets sent
    let bytesInPerSecond: Double  // Download speed
    let bytesOutPerSecond: Double // Upload speed
    let timestamp: Date
    
    static func == (lhs: NetworkMetrics, rhs: NetworkMetrics) -> Bool {
        return lhs.bytesIn == rhs.bytesIn && lhs.bytesOut == rhs.bytesOut
    }
}

struct SystemMetricsSnapshot {
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let timestamp: Date
    let uptime: TimeInterval
}

// MARK: - System Metrics Service

@MainActor
final class SystemMetricsService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var cpuMetrics: CPUMetrics?
    @Published private(set) var memoryMetrics: MemoryMetrics?
    @Published private(set) var diskMetrics: DiskMetrics?
    @Published private(set) var networkMetrics: NetworkMetrics?
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var errorMessage: String?
    
    // MARK: - Configuration
    
    var refreshInterval: TimeInterval = 2.0 {
        didSet {
            if isMonitoring {
                stopMonitoring()
                startMonitoring()
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var previousNetworkBytes: (in: UInt64, out: UInt64)?
    private var previousNetworkTime: Date?
    private var previousCPUTicks: host_cpu_load_info?
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "SystemMetrics")
    
    // MARK: - Initialization
    
    init() {
        logger.info("SystemMetricsService initialized")
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start continuous monitoring of system metrics
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("Starting system metrics monitoring with interval: \(self.refreshInterval)s")
        isMonitoring = true
        
        // Initial fetch
        Task {
            await refreshAllMetrics()
        }
        
        // Schedule periodic updates
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllMetrics()
            }
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        logger.info("Stopping system metrics monitoring")
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }
    
    /// Manually refresh all metrics
    func refreshAllMetrics() async {
        do {
            async let cpu = fetchCPUMetrics()
            async let memory = fetchMemoryMetrics()
            async let disk = fetchDiskMetrics()
            async let network = fetchNetworkMetrics()
            
            cpuMetrics = try await cpu
            memoryMetrics = try await memory
            diskMetrics = try await disk
            networkMetrics = try await network
            lastUpdateTime = Date()
            errorMessage = nil
            
        } catch {
            logger.error("Failed to fetch metrics: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Get a complete snapshot of all system metrics
    func getSnapshot() -> SystemMetricsSnapshot? {
        guard let cpu = cpuMetrics,
              let memory = memoryMetrics,
              let disk = diskMetrics,
              let network = networkMetrics else {
            return nil
        }
        
        var uptime: TimeInterval = 0
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 {
            uptime = Date().timeIntervalSince1970 - TimeInterval(bootTime.tv_sec)
        }
        
        return SystemMetricsSnapshot(
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            timestamp: Date(),
            uptime: uptime
        )
    }
    
    // MARK: - CPU Metrics
    
    private func fetchCPUMetrics() async throws -> CPUMetrics {
        return await withCheckedContinuation { continuation in
            var coreCount: natural_t = 0
            var cpuInfo: processor_info_array_t?
            var numCpuInfo: mach_msg_type_number_t = 0
            
            let result = host_processor_info(
                mach_host_self(),
                PROCESSOR_CPU_LOAD_INFO,
                &coreCount,
                &cpuInfo,
                &numCpuInfo
            )
            
            guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
                continuation.resume(returning: CPUMetrics(
                    userUsage: 0, systemUsage: 0, idleUsage: 100, totalUsage: 0,
                    coreCount: 0, perCoreUsage: [], loadAverage: (0, 0, 0)
                ))
                return
            }
            
            defer {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size))
            }
            
            var perCoreUsage: [Double] = []
            var totalUser: Double = 0
            var totalSystem: Double = 0
            var totalIdle: Double = 0
            
            for i in 0..<Int(coreCount) {
                let offset = Int(CPU_STATE_MAX) * i
                
                let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
                let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
                let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
                let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])
                
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
            
            let totalAll = totalUser + totalSystem + totalIdle
            let userUsage = totalAll > 0 ? (totalUser / totalAll) * 100.0 : 0
            let systemUsage = totalAll > 0 ? (totalSystem / totalAll) * 100.0 : 0
            let idleUsage = totalAll > 0 ? (totalIdle / totalAll) * 100.0 : 0
            
            // Get load averages
            var loadAvg: [Double] = [0, 0, 0]
            getloadavg(&loadAvg, 3)
            
            continuation.resume(returning: CPUMetrics(
                userUsage: userUsage,
                systemUsage: systemUsage,
                idleUsage: idleUsage,
                totalUsage: userUsage + systemUsage,
                coreCount: Int(coreCount),
                perCoreUsage: perCoreUsage,
                loadAverage: (loadAvg[0], loadAvg[1], loadAvg[2])
            ))
        }
    }
    
    // MARK: - Memory Metrics
    
    private func fetchMemoryMetrics() async throws -> MemoryMetrics {
        return await withCheckedContinuation { continuation in
            // Get total physical memory
            let totalRAM = UInt64(Foundation.ProcessInfo.processInfo.physicalMemory)
            
            // Get VM statistics
            var vmStats = vm_statistics64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            
            let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
                }
            }
            
            guard result == KERN_SUCCESS else {
                continuation.resume(returning: MemoryMetrics(
                    totalRAM: totalRAM, usedRAM: 0, freeRAM: totalRAM,
                    activeRAM: 0, inactiveRAM: 0, wiredRAM: 0,
                    compressedRAM: 0, cachedFiles: 0,
                    swapUsed: 0, swapTotal: 0,
                    pressureLevel: .normal, pressurePercentage: 0
                ))
                return
            }
            
            let pageSize = UInt64(vm_kernel_page_size)
            
            let freeRAM = UInt64(vmStats.free_count) * pageSize
            let activeRAM = UInt64(vmStats.active_count) * pageSize
            let inactiveRAM = UInt64(vmStats.inactive_count) * pageSize
            let wiredRAM = UInt64(vmStats.wire_count) * pageSize
            let compressedRAM = UInt64(vmStats.compressor_page_count) * pageSize
            let cachedFiles = UInt64(vmStats.external_page_count) * pageSize
            
            // Calculate used RAM (app memory + wired + compressed)
            let usedRAM = activeRAM + wiredRAM + compressedRAM
            
            // Get swap info
            var swapUsage = xsw_usage()
            var swapSize = MemoryLayout<xsw_usage>.size
            sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
            
            let swapUsed = UInt64(swapUsage.xsu_used)
            let swapTotal = UInt64(swapUsage.xsu_total)
            
            // Calculate memory pressure
            let usedPercentage = Double(usedRAM) / Double(totalRAM) * 100
            let pressureLevel: MemoryPressureLevel
            let pressurePercentage: Double
            
            if usedPercentage < 60 {
                pressureLevel = .normal
                pressurePercentage = usedPercentage
            } else if usedPercentage < 80 {
                pressureLevel = .warning
                pressurePercentage = usedPercentage
            } else {
                pressureLevel = .critical
                pressurePercentage = usedPercentage
            }
            
            continuation.resume(returning: MemoryMetrics(
                totalRAM: totalRAM,
                usedRAM: usedRAM,
                freeRAM: freeRAM,
                activeRAM: activeRAM,
                inactiveRAM: inactiveRAM,
                wiredRAM: wiredRAM,
                compressedRAM: compressedRAM,
                cachedFiles: cachedFiles,
                swapUsed: swapUsed,
                swapTotal: swapTotal,
                pressureLevel: pressureLevel,
                pressurePercentage: pressurePercentage
            ))
        }
    }
    
    // MARK: - Disk Metrics
    
    private func fetchDiskMetrics() async throws -> DiskMetrics {
        return await withCheckedContinuation { continuation in
            let fileManager = FileManager.default
            
            do {
                let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
                
                let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
                let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
                let usedSpace = totalSpace - freeSpace
                
                // Get file system type
                var statfsBuffer = Darwin.statfs()
                _ = statfs("/", &statfsBuffer)

                let fileSystem = withUnsafePointer(to: &statfsBuffer.f_fstypename) { ptr in
                    return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                }
                
                continuation.resume(returning: DiskMetrics(
                    totalSpace: totalSpace,
                    usedSpace: usedSpace,
                    freeSpace: freeSpace,
                    mountPoint: "/",
                    fileSystem: fileSystem
                ))
            } catch {
                continuation.resume(returning: DiskMetrics(
                    totalSpace: 0, usedSpace: 0, freeSpace: 0,
                    mountPoint: "/", fileSystem: "Unknown"
                ))
            }
        }
    }
    
    // MARK: - Network Metrics
    
    private func fetchNetworkMetrics() async throws -> NetworkMetrics {
        return await withCheckedContinuation { continuation in
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            
            guard getifaddrs(&ifaddr) == 0 else {
                continuation.resume(returning: NetworkMetrics(
                    bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0,
                    bytesInPerSecond: 0, bytesOutPerSecond: 0, timestamp: Date()
                ))
                return
            }
            
            defer { freeifaddrs(ifaddr) }
            
            var totalBytesIn: UInt64 = 0
            var totalBytesOut: UInt64 = 0
            var totalPacketsIn: UInt64 = 0
            var totalPacketsOut: UInt64 = 0
            
            var ptr = ifaddr
            while let interface = ptr {
                if interface.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    let data = unsafeBitCast(interface.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                    totalBytesIn += UInt64(data.pointee.ifi_ibytes)
                    totalBytesOut += UInt64(data.pointee.ifi_obytes)
                    totalPacketsIn += UInt64(data.pointee.ifi_ipackets)
                    totalPacketsOut += UInt64(data.pointee.ifi_opackets)
                }
                ptr = interface.pointee.ifa_next
            }
            
            let now = Date()
            var bytesInPerSecond: Double = 0
            var bytesOutPerSecond: Double = 0

            if let previous = self.previousNetworkBytes,
               let previousTime = self.previousNetworkTime {
                let timeDelta = now.timeIntervalSince(previousTime)
                if timeDelta > 0 {
                    // Handle counter resets (e.g., after sleep/wake or interface reset)
                    // If current value is less than previous, counters were reset - skip rate calculation
                    if totalBytesIn >= previous.in {
                        bytesInPerSecond = Double(totalBytesIn - previous.in) / timeDelta
                    }
                    if totalBytesOut >= previous.out {
                        bytesOutPerSecond = Double(totalBytesOut - previous.out) / timeDelta
                    }
                }
            }
            
            self.previousNetworkBytes = (totalBytesIn, totalBytesOut)
            self.previousNetworkTime = now
            
            continuation.resume(returning: NetworkMetrics(
                bytesIn: totalBytesIn,
                bytesOut: totalBytesOut,
                packetsIn: totalPacketsIn,
                packetsOut: totalPacketsOut,
                bytesInPerSecond: max(0, bytesInPerSecond),
                bytesOutPerSecond: max(0, bytesOutPerSecond),
                timestamp: now
            ))
        }
    }
}

// MARK: - Formatting Helpers

extension SystemMetricsService {
    
    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    static func formatBytesPerSecond(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
    
    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
    
    static func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
