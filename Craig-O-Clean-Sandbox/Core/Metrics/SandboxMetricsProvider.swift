// MARK: - SandboxMetricsProvider.swift
// Craig-O-Clean Sandbox Edition - System Metrics Provider
// Uses only native macOS APIs (Mach, BSD) that work within the sandbox

import Foundation
import Combine
import os.log

// MARK: - Memory Pressure Level

enum SandboxMemoryPressureLevel: String, CaseIterable {
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
        case .critical: return "Memory is under high pressure - consider closing some apps"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Metrics Data Structures

struct SandboxCPUMetrics: Equatable {
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double
    let totalUsage: Double
    let coreCount: Int
    let perCoreUsage: [Double]
    let loadAverage: (one: Double, five: Double, fifteen: Double)

    static func == (lhs: SandboxCPUMetrics, rhs: SandboxCPUMetrics) -> Bool {
        return lhs.totalUsage == rhs.totalUsage && lhs.coreCount == rhs.coreCount
    }

    var formattedUsage: String {
        return String(format: "%.1f%%", totalUsage)
    }
}

struct SandboxMemoryMetrics: Equatable {
    let totalRAM: UInt64
    let usedRAM: UInt64
    let freeRAM: UInt64
    let activeRAM: UInt64
    let inactiveRAM: UInt64
    let wiredRAM: UInt64
    let compressedRAM: UInt64
    let cachedFiles: UInt64
    let swapUsed: UInt64
    let swapTotal: UInt64
    let pressureLevel: SandboxMemoryPressureLevel
    let pressurePercentage: Double

    var usedPercentage: Double {
        guard totalRAM > 0 else { return 0 }
        return Double(usedRAM) / Double(totalRAM) * 100
    }

    var availableRAM: UInt64 {
        return freeRAM + inactiveRAM + cachedFiles
    }

    var formattedUsedRAM: String {
        return ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
    }

    var formattedTotalRAM: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)
    }

    static func == (lhs: SandboxMemoryMetrics, rhs: SandboxMemoryMetrics) -> Bool {
        return lhs.totalRAM == rhs.totalRAM && lhs.usedRAM == rhs.usedRAM
    }
}

struct SandboxDiskMetrics: Equatable {
    let totalSpace: UInt64
    let usedSpace: UInt64
    let freeSpace: UInt64
    let mountPoint: String
    let fileSystem: String

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    var formattedFreeSpace: String {
        return ByteCountFormatter.string(fromByteCount: Int64(freeSpace), countStyle: .file)
    }

    var formattedTotalSpace: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSpace), countStyle: .file)
    }
}

struct SandboxNetworkMetrics: Equatable {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let packetsIn: UInt64
    let packetsOut: UInt64
    let bytesInPerSecond: Double
    let bytesOutPerSecond: Double
    let timestamp: Date

    var formattedDownloadSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytesInPerSecond), countStyle: .file) + "/s"
    }

    var formattedUploadSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytesOutPerSecond), countStyle: .file) + "/s"
    }

    static func == (lhs: SandboxNetworkMetrics, rhs: SandboxNetworkMetrics) -> Bool {
        return lhs.bytesIn == rhs.bytesIn && lhs.bytesOut == rhs.bytesOut
    }
}

// MARK: - Sandbox Metrics Provider

/// Provides system metrics using only sandbox-compliant native APIs
/// No shell commands are used - all data comes from Mach and BSD APIs
@MainActor
final class SandboxMetricsProvider: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var cpuMetrics: SandboxCPUMetrics?
    @Published private(set) var memoryMetrics: SandboxMemoryMetrics?
    @Published private(set) var diskMetrics: SandboxDiskMetrics?
    @Published private(set) var networkMetrics: SandboxNetworkMetrics?
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var systemUptime: TimeInterval = 0

    // MARK: - Memory Pressure Source

    private var memoryPressureSource: DispatchSourceMemoryPressure?
    @Published private(set) var currentMemoryPressure: DispatchSource.MemoryPressureEvent = []

    // MARK: - Private Properties

    private var timer: Timer?
    private var previousNetworkBytes: (in: UInt64, out: UInt64)?
    private var previousNetworkTime: Date?
    private let logger = Logger(subsystem: "com.craigoclean.sandbox", category: "Metrics")

    var refreshInterval: TimeInterval = SandboxConfiguration.Timing.metricsRefreshInterval {
        didSet {
            if isMonitoring {
                stopMonitoring()
                startMonitoring()
            }
        }
    }

    // MARK: - Initialization

    init() {
        logger.info("SandboxMetricsProvider initialized - using native APIs only")
        setupMemoryPressureMonitoring()
    }

    deinit {
        timer?.invalidate()
        memoryPressureSource?.cancel()
    }

    // MARK: - Public Methods

    /// Start continuous monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }

        logger.info("Starting system metrics monitoring (interval: \(self.refreshInterval)s)")
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
        cpuMetrics = await fetchCPUMetrics()
        memoryMetrics = await fetchMemoryMetrics()
        diskMetrics = await fetchDiskMetrics()
        networkMetrics = await fetchNetworkMetrics()
        systemUptime = fetchSystemUptime()
        lastUpdateTime = Date()
    }

    // MARK: - Memory Pressure Monitoring

    /// Setup memory pressure monitoring using DispatchSource
    /// This is the Apple-recommended way to respond to memory pressure
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical, .normal],
            queue: .main
        )

        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self,
                  let source = self.memoryPressureSource else { return }

            let event = source.data
            self.currentMemoryPressure = event

            if event.contains(.critical) {
                self.logger.warning("Memory pressure CRITICAL - system may terminate apps")
                self.handleMemoryPressure(.critical)
            } else if event.contains(.warning) {
                self.logger.info("Memory pressure WARNING - consider freeing memory")
                self.handleMemoryPressure(.warning)
            } else {
                self.logger.info("Memory pressure returned to NORMAL")
                self.handleMemoryPressure(.normal)
            }
        }

        memoryPressureSource?.resume()
        logger.info("Memory pressure monitoring active")
    }

    /// Handle memory pressure events
    private func handleMemoryPressure(_ level: SandboxMemoryPressureLevel) {
        // Post notification for other parts of the app to respond
        NotificationCenter.default.post(
            name: .memoryPressureChanged,
            object: nil,
            userInfo: ["level": level]
        )
    }

    // MARK: - CPU Metrics (Mach API)

    private func fetchCPUMetrics() async -> SandboxCPUMetrics {
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
                continuation.resume(returning: SandboxCPUMetrics(
                    userUsage: 0, systemUsage: 0, idleUsage: 100, totalUsage: 0,
                    coreCount: 0, perCoreUsage: [], loadAverage: (0, 0, 0)
                ))
                return
            }

            defer {
                vm_deallocate(
                    mach_task_self_,
                    vm_address_t(bitPattern: cpuInfo),
                    vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size)
                )
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

            // Get load averages using BSD API
            var loadAvg: [Double] = [0, 0, 0]
            getloadavg(&loadAvg, 3)

            continuation.resume(returning: SandboxCPUMetrics(
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

    // MARK: - Memory Metrics (Mach API)

    private func fetchMemoryMetrics() async -> SandboxMemoryMetrics {
        return await withCheckedContinuation { continuation in
            // Get total physical memory
            let totalRAM = UInt64(ProcessInfo.processInfo.physicalMemory)

            // Get VM statistics using Mach API
            var vmStats = vm_statistics64()
            var count = mach_msg_type_number_t(
                MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
            )

            let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
                }
            }

            guard result == KERN_SUCCESS else {
                continuation.resume(returning: SandboxMemoryMetrics(
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

            // Get swap info using sysctl
            var swapUsage = xsw_usage()
            var swapSize = MemoryLayout<xsw_usage>.size
            sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)

            let swapUsed = UInt64(swapUsage.xsu_used)
            let swapTotal = UInt64(swapUsage.xsu_total)

            // Calculate memory pressure level based on thresholds
            let usedPercentage = Double(usedRAM) / Double(totalRAM) * 100
            let pressureLevel: SandboxMemoryPressureLevel
            let pressurePercentage: Double

            if usedPercentage < SandboxConfiguration.MemoryThresholds.warningPercentage {
                pressureLevel = .normal
                pressurePercentage = usedPercentage
            } else if usedPercentage < SandboxConfiguration.MemoryThresholds.criticalPercentage {
                pressureLevel = .warning
                pressurePercentage = usedPercentage
            } else {
                pressureLevel = .critical
                pressurePercentage = usedPercentage
            }

            continuation.resume(returning: SandboxMemoryMetrics(
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

    // MARK: - Disk Metrics (FileManager API)

    private func fetchDiskMetrics() async -> SandboxDiskMetrics {
        return await withCheckedContinuation { continuation in
            let fileManager = FileManager.default

            do {
                let attributes = try fileManager.attributesOfFileSystem(forPath: "/")

                let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
                let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
                let usedSpace = totalSpace - freeSpace

                // Get file system type using statfs
                var statfsBuffer = Darwin.statfs()
                _ = statfs("/", &statfsBuffer)

                let fileSystem = withUnsafePointer(to: &statfsBuffer.f_fstypename) { ptr in
                    return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                }

                continuation.resume(returning: SandboxDiskMetrics(
                    totalSpace: totalSpace,
                    usedSpace: usedSpace,
                    freeSpace: freeSpace,
                    mountPoint: "/",
                    fileSystem: fileSystem
                ))
            } catch {
                continuation.resume(returning: SandboxDiskMetrics(
                    totalSpace: 0, usedSpace: 0, freeSpace: 0,
                    mountPoint: "/", fileSystem: "Unknown"
                ))
            }
        }
    }

    // MARK: - Network Metrics (BSD API)

    private func fetchNetworkMetrics() async -> SandboxNetworkMetrics {
        return await withCheckedContinuation { continuation in
            var ifaddr: UnsafeMutablePointer<ifaddrs>?

            guard getifaddrs(&ifaddr) == 0 else {
                continuation.resume(returning: SandboxNetworkMetrics(
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
                    let data = unsafeBitCast(
                        interface.pointee.ifa_data,
                        to: UnsafeMutablePointer<if_data>.self
                    )
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
                    // Handle counter resets
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

            continuation.resume(returning: SandboxNetworkMetrics(
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

    // MARK: - System Uptime (sysctl)

    private func fetchSystemUptime() -> TimeInterval {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 {
            return Date().timeIntervalSince1970 - TimeInterval(bootTime.tv_sec)
        }
        return 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let memoryPressureChanged = Notification.Name("com.craigoclean.memoryPressureChanged")
}

// MARK: - Formatting Helpers

extension SandboxMetricsProvider {

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
