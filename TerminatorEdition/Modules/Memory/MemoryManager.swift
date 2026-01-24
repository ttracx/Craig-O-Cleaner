import Foundation

// MARK: - Memory Manager
/// Memory monitoring, optimization, and purging for macOS Silicon
/// Provides low-overhead memory management operations

@MainActor
public final class MemoryManager: ObservableObject {

    // MARK: - Types

    public struct MemoryInfo: Sendable {
        public let totalBytes: UInt64
        public let usedBytes: UInt64
        public let freeBytes: UInt64
        public let activeBytes: UInt64
        public let inactiveBytes: UInt64
        public let wiredBytes: UInt64
        public let compressedBytes: UInt64
        public let cachedBytes: UInt64

        public var usedPercent: Double {
            Double(usedBytes) / Double(totalBytes) * 100
        }

        public var freePercent: Double {
            Double(freeBytes) / Double(totalBytes) * 100
        }

        public var totalGB: Double {
            Double(totalBytes) / 1_073_741_824
        }

        public var usedGB: Double {
            Double(usedBytes) / 1_073_741_824
        }

        public var freeGB: Double {
            Double(freeBytes) / 1_073_741_824
        }

        public var summary: String {
            """
            Memory: \(String(format: "%.1f", usedGB))GB / \(String(format: "%.1f", totalGB))GB (\(String(format: "%.1f", usedPercent))%)
            Active: \(formatBytes(activeBytes)) | Inactive: \(formatBytes(inactiveBytes))
            Wired: \(formatBytes(wiredBytes)) | Compressed: \(formatBytes(compressedBytes))
            """
        }

        private func formatBytes(_ bytes: UInt64) -> String {
            ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
        }
    }

    public struct SwapInfo: Sendable {
        public let totalBytes: UInt64
        public let usedBytes: UInt64
        public let freeBytes: UInt64
        public let encrypted: Bool

        public var usedPercent: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(usedBytes) / Double(totalBytes) * 100
        }
    }

    public enum MemoryPressure: String, Sendable {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
        case unknown = "Unknown"
    }

    public struct PurgeResult {
        public let memoryFreed: UInt64
        public let previousUsed: UInt64
        public let currentUsed: UInt64
        public let duration: TimeInterval
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var currentMemoryInfo: MemoryInfo?
    @Published public private(set) var memoryPressure: MemoryPressure = .unknown
    @Published public private(set) var swapInfo: SwapInfo?

    // Page size for macOS (typically 16KB on Apple Silicon)
    private let pageSize: UInt64 = 16384

    // MARK: - Memory Information

    /// Get current memory information
    public func getMemoryInfo() async throws -> MemoryInfo {
        // Get total memory
        let totalResult = try await executor.execute("sysctl -n hw.memsize")
        let totalBytes = UInt64(totalResult.output) ?? 0

        // Get vm_stat output
        let vmStatResult = try await executor.execute("vm_stat")
        let vmStats = parseVMStat(vmStatResult.output)

        let freePages = vmStats["Pages free"] ?? 0
        let activePages = vmStats["Pages active"] ?? 0
        let inactivePages = vmStats["Pages inactive"] ?? 0
        let wiredPages = vmStats["Pages wired down"] ?? 0
        let compressedPages = vmStats["Pages occupied by compressor"] ?? 0
        let cachedPages = vmStats["File-backed pages"] ?? 0

        let freeBytes = freePages * pageSize
        let activeBytes = activePages * pageSize
        let inactiveBytes = inactivePages * pageSize
        let wiredBytes = wiredPages * pageSize
        let compressedBytes = compressedPages * pageSize
        let cachedBytes = cachedPages * pageSize

        let usedBytes = activeBytes + wiredBytes + compressedBytes

        let info = MemoryInfo(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: freeBytes + inactiveBytes,
            activeBytes: activeBytes,
            inactiveBytes: inactiveBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            cachedBytes: cachedBytes
        )

        currentMemoryInfo = info
        return info
    }

    /// Get quick memory usage percentage
    public func getMemoryUsagePercent() async -> Double {
        let result = try? await executor.execute(
            "top -l 1 -s 0 | grep PhysMem"
        )

        guard let output = result?.output else { return 0 }

        // Parse: "PhysMem: 12G used (2097M wired, 3271M compressor), 4056M unused."
        if let usedMatch = output.range(of: #"(\d+)([GM]) used"#, options: .regularExpression) {
            let usedStr = String(output[usedMatch])
            // Extract number and unit
            let scanner = Scanner(string: usedStr)
            if let number = scanner.scanDouble() {
                let unit = usedStr.contains("G") ? 1024.0 : 1.0
                let usedMB = number * unit

                let totalResult = try? await executor.execute("sysctl -n hw.memsize")
                let totalBytes = Double(totalResult?.output ?? "0") ?? 0
                let totalMB = totalBytes / 1_048_576

                return (usedMB / totalMB) * 100
            }
        }

        return 0
    }

    /// Get memory pressure status
    public func getMemoryPressure() async -> MemoryPressure {
        let result = try? await executor.execute("memory_pressure")

        guard let output = result?.output.lowercased() else {
            return .unknown
        }

        if output.contains("critical") {
            memoryPressure = .critical
        } else if output.contains("warn") {
            memoryPressure = .warning
        } else if output.contains("normal") {
            memoryPressure = .normal
        } else {
            memoryPressure = .unknown
        }

        return memoryPressure
    }

    /// Get swap information
    public func getSwapInfo() async throws -> SwapInfo {
        let result = try await executor.execute("sysctl vm.swapusage")

        // Parse: "vm.swapusage: total = 2048.00M  used = 1024.00M  free = 1024.00M  (encrypted)"
        let output = result.output

        var total: UInt64 = 0
        var used: UInt64 = 0
        var free: UInt64 = 0
        let encrypted = output.contains("encrypted")

        let patterns = [
            ("total = ", &total),
            ("used = ", &used),
            ("free = ", &free)
        ]

        for (prefix, target) in patterns {
            if let range = output.range(of: "\(prefix)\\d+\\.?\\d*[MG]", options: .regularExpression) {
                let value = String(output[range]).replacingOccurrences(of: prefix, with: "")
                target.pointee = parseMemoryValue(value)
            }
        }

        let info = SwapInfo(
            totalBytes: total,
            usedBytes: used,
            freeBytes: free,
            encrypted: encrypted
        )

        swapInfo = info
        return info
    }

    // MARK: - Memory Purging

    /// Purge inactive memory
    public func purgeInactiveMemory() async throws -> PurgeResult {
        let startTime = Date()

        // Get before state
        let beforeInfo = try await getMemoryInfo()

        // Sync and purge
        _ = try await executor.executePrivileged("sync && purge")

        // Small delay for purge to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        // Get after state
        let afterInfo = try await getMemoryInfo()

        let duration = Date().timeIntervalSince(startTime)
        let freed = beforeInfo.usedBytes > afterInfo.usedBytes ?
            beforeInfo.usedBytes - afterInfo.usedBytes : 0

        return PurgeResult(
            memoryFreed: freed,
            previousUsed: beforeInfo.usedBytes,
            currentUsed: afterInfo.usedBytes,
            duration: duration
        )
    }

    /// Sync file system buffers
    public func syncFileSystem() async throws {
        _ = try await executor.execute("sync")
    }

    /// Flush DNS cache (also frees some memory)
    public func flushDNSCache() async throws {
        _ = try await executor.executePrivileged(
            "dscacheutil -flushcache && killall -HUP mDNSResponder"
        )
    }

    // MARK: - Memory Monitoring

    /// Get top memory-consuming processes
    public func getTopMemoryProcesses(limit: Int = 10) async throws -> [(name: String, pid: Int, memoryMB: Double)] {
        let result = try await executor.execute(
            "ps aux --sort=-%mem | head -\(limit + 1) | tail -n +2"
        )

        var processes: [(String, Int, Double)] = []

        for line in result.output.components(separatedBy: .newlines) {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard components.count >= 11 else { continue }

            if let pid = Int(components[1]),
               let rss = Double(components[5]) {
                let name = URL(fileURLWithPath: components[10]).lastPathComponent
                let memoryMB = rss / 1024.0
                processes.append((name, pid, memoryMB))
            }
        }

        return processes
    }

    /// Monitor memory continuously
    public func startMemoryMonitoring(interval: TimeInterval = 5) -> AsyncStream<MemoryInfo> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    if let info = try? await self.getMemoryInfo() {
                        continuation.yield(info)
                    }
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private Helpers

    private func parseVMStat(_ output: String) -> [String: UInt64] {
        var stats: [String: UInt64] = [:]

        for line in output.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ":")
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let valueStr = parts[1]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ".", with: "")

            if let value = UInt64(valueStr) {
                stats[key] = value
            }
        }

        return stats
    }

    private func parseMemoryValue(_ value: String) -> UInt64 {
        let numStr = value.trimmingCharacters(in: CharacterSet.letters.union(.whitespaces))
        guard let number = Double(numStr) else { return 0 }

        if value.uppercased().contains("G") {
            return UInt64(number * 1_073_741_824)
        } else if value.uppercased().contains("M") {
            return UInt64(number * 1_048_576)
        } else if value.uppercased().contains("K") {
            return UInt64(number * 1024)
        }

        return UInt64(number)
    }
}

// MARK: - Memory Commands Reference

public enum MemoryCommands {

    // Information
    public static let vmStat = "vm_stat"
    public static let memoryPressure = "memory_pressure"
    public static let totalMemory = "sysctl hw.memsize"
    public static let swapUsage = "sysctl vm.swapusage"
    public static let physMemSummary = "top -l 1 -s 0 | grep PhysMem"

    // Top processes
    public static let topByMemory = "ps aux --sort=-%mem | head -20"
    public static let topByRSS = "ps -eo pid,rss,comm | sort -k2 -rn | head -20"

    // Purging
    public static let purge = "sudo purge"
    public static let syncAndPurge = "sync && sudo purge"
    public static let flushDNS = "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"

    // Continuous monitoring
    public static let vmStatContinuous = "vm_stat 1"
    public static let topInteractive = "top -o mem"

    // Human-readable memory
    public static let memoryReadable = """
        vm_stat | perl -ne '/page size of (\\d+)/ and $size=$1; /Pages\\s+(\\w+)[^\\d]+(\\d+)/ and printf("%-16s % 16.2f MB\\n", "$1:", $2 * $size / 1048576);'
        """

    // Memory calculation script
    public static let memoryPercentScript = """
        vm_stat | awk '
        /Pages active/ {active=$3}
        /Pages inactive/ {inactive=$3}
        /Pages wired/ {wired=$4}
        /Pages free/ {free=$3}
        END {
            total=active+inactive+wired+free
            used=active+wired
            printf "Memory Used: %.1f%%\\n", (used/total)*100
        }'
        """
}
