import Foundation

// MARK: - Diagnostics Manager
/// System diagnostics and monitoring for macOS Silicon
/// Provides CPU, memory, disk, network, and battery information

@MainActor
public final class DiagnosticsManager: ObservableObject {

    // MARK: - Types

    public struct SystemInfo: Sendable {
        public let hostname: String
        public let osVersion: String
        public let osBuild: String
        public let kernelVersion: String
        public let architecture: String
        public let modelName: String
        public let serialNumber: String?
        public let uptime: TimeInterval
    }

    public struct CPUInfo: Sendable {
        public let brandString: String
        public let coreCount: Int
        public let physicalCores: Int
        public let logicalCores: Int
        public let architecture: String
        public let usagePercent: Double
        public let userPercent: Double
        public let systemPercent: Double
        public let idlePercent: Double

        public var summary: String {
            """
            \(brandString)
            Cores: \(physicalCores) physical, \(logicalCores) logical
            Usage: \(String(format: "%.1f", usagePercent))% (User: \(String(format: "%.1f", userPercent))%, System: \(String(format: "%.1f", systemPercent))%)
            """
        }
    }

    public struct NetworkInfo: Sendable {
        public let interfaceName: String
        public let ipAddress: String?
        public let macAddress: String?
        public let isActive: Bool
        public let bytesIn: UInt64
        public let bytesOut: UInt64
        public let packetsIn: UInt64
        public let packetsOut: UInt64
    }

    public struct BatteryInfo: Sendable {
        public let isPresent: Bool
        public let isCharging: Bool
        public let chargePercent: Int
        public let cycleCount: Int
        public let condition: String
        public let timeRemaining: TimeInterval?
        public let powerSource: String

        public var summary: String {
            let status = isCharging ? "Charging" : "On Battery"
            let time = timeRemaining.map { "\(Int($0 / 60)) min remaining" } ?? ""
            return "\(chargePercent)% (\(status)) \(time)"
        }
    }

    public struct HealthReport: Sendable {
        public let timestamp: Date
        public let system: SystemInfo
        public let cpu: CPUInfo
        public let memoryUsagePercent: Double
        public let diskUsagePercent: Double
        public let processCount: Int
        public let networkInterfaces: [NetworkInfo]
        public let battery: BatteryInfo?

        public var overallHealth: HealthStatus {
            if memoryUsagePercent > 95 || diskUsagePercent > 98 || cpu.usagePercent > 95 {
                return .critical
            } else if memoryUsagePercent > 85 || diskUsagePercent > 90 || cpu.usagePercent > 85 {
                return .warning
            }
            return .good
        }

        public enum HealthStatus: String {
            case good = "Good"
            case warning = "Warning"
            case critical = "Critical"
        }
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var systemInfo: SystemInfo?
    @Published public private(set) var cpuInfo: CPUInfo?
    @Published public private(set) var batteryInfo: BatteryInfo?

    // MARK: - System Information

    /// Get comprehensive system information
    public func getSystemInfo() async throws -> SystemInfo {
        async let hostnameTask = executor.execute("hostname")
        async let versionTask = executor.execute("sw_vers -productVersion")
        async let buildTask = executor.execute("sw_vers -buildVersion")
        async let kernelTask = executor.execute("uname -r")
        async let archTask = executor.execute("arch")
        async let modelTask = executor.execute("sysctl -n hw.model")
        async let uptimeTask = executor.execute("sysctl -n kern.boottime | awk '{print $4}' | tr -d ','")

        let results = try await (hostnameTask, versionTask, buildTask, kernelTask, archTask, modelTask, uptimeTask)

        // Calculate uptime
        var uptime: TimeInterval = 0
        if let bootTime = Double(results.6.output) {
            uptime = Date().timeIntervalSince1970 - bootTime
        }

        let info = SystemInfo(
            hostname: results.0.output,
            osVersion: results.1.output,
            osBuild: results.2.output,
            kernelVersion: results.3.output,
            architecture: results.4.output,
            modelName: results.5.output,
            serialNumber: nil,
            uptime: uptime
        )

        systemInfo = info
        return info
    }

    /// Get CPU information and usage
    public func getCPUInfo() async throws -> CPUInfo {
        async let brandTask = executor.execute("sysctl -n machdep.cpu.brand_string")
        async let coreTask = executor.execute("sysctl -n hw.ncpu")
        async let physTask = executor.execute("sysctl -n hw.physicalcpu")
        async let logicalTask = executor.execute("sysctl -n hw.logicalcpu")
        async let archTask = executor.execute("arch")
        async let usageTask = executor.execute("top -l 1 -s 0 | grep 'CPU usage'")

        let results = try await (brandTask, coreTask, physTask, logicalTask, archTask, usageTask)

        // Parse CPU usage
        var userPercent = 0.0
        var systemPercent = 0.0
        var idlePercent = 0.0

        let usageOutput = results.5.output
        if let userMatch = usageOutput.range(of: #"(\d+\.?\d*)% user"#, options: .regularExpression) {
            userPercent = Double(usageOutput[userMatch].replacingOccurrences(of: "% user", with: "")) ?? 0
        }
        if let sysMatch = usageOutput.range(of: #"(\d+\.?\d*)% sys"#, options: .regularExpression) {
            systemPercent = Double(usageOutput[sysMatch].replacingOccurrences(of: "% sys", with: "")) ?? 0
        }
        if let idleMatch = usageOutput.range(of: #"(\d+\.?\d*)% idle"#, options: .regularExpression) {
            idlePercent = Double(usageOutput[idleMatch].replacingOccurrences(of: "% idle", with: "")) ?? 0
        }

        let info = CPUInfo(
            brandString: results.0.output,
            coreCount: Int(results.1.output) ?? 0,
            physicalCores: Int(results.2.output) ?? 0,
            logicalCores: Int(results.3.output) ?? 0,
            architecture: results.4.output,
            usagePercent: userPercent + systemPercent,
            userPercent: userPercent,
            systemPercent: systemPercent,
            idlePercent: idlePercent
        )

        cpuInfo = info
        return info
    }

    /// Get quick CPU usage percentage
    public func getCPUUsage() async -> Double {
        let result = try? await executor.execute("top -l 1 -s 0 | grep 'CPU usage'")
        guard let output = result?.output else { return 0 }

        var total = 0.0
        if let userMatch = output.range(of: #"(\d+\.?\d*)% user"#, options: .regularExpression) {
            total += Double(output[userMatch].replacingOccurrences(of: "% user", with: "")) ?? 0
        }
        if let sysMatch = output.range(of: #"(\d+\.?\d*)% sys"#, options: .regularExpression) {
            total += Double(output[sysMatch].replacingOccurrences(of: "% sys", with: "")) ?? 0
        }

        return total
    }

    /// Get memory usage percentage
    public func getMemoryUsage() async -> Double {
        let result = try? await executor.execute("top -l 1 -s 0 | grep PhysMem")
        guard let output = result?.output else { return 0 }

        // Parse: "PhysMem: 12G used (2097M wired, 3271M compressor), 4056M unused."
        if let usedMatch = output.range(of: #"(\d+)([GM]) used"#, options: .regularExpression),
           let unusedMatch = output.range(of: #"(\d+)([GM]) unused"#, options: .regularExpression) {

            let usedStr = String(output[usedMatch])
            let unusedStr = String(output[unusedMatch])

            let usedValue = parseMemoryString(usedStr.replacingOccurrences(of: " used", with: ""))
            let unusedValue = parseMemoryString(unusedStr.replacingOccurrences(of: " unused", with: ""))

            let total = usedValue + unusedValue
            if total > 0 {
                return (usedValue / total) * 100
            }
        }

        return 0
    }

    /// Get disk usage percentage
    public func getDiskUsage() async -> Double {
        let result = try? await executor.execute("df -h / | tail -1 | awk '{print $5}'")
        guard let output = result?.output else { return 0 }
        return Double(output.replacingOccurrences(of: "%", with: "")) ?? 0
    }

    /// Get process count
    public func getProcessCount() async -> Int {
        let result = try? await executor.execute("ps aux | wc -l")
        guard let output = result?.output else { return 0 }
        return (Int(output.trimmingCharacters(in: .whitespaces)) ?? 1) - 1
    }

    // MARK: - Network Diagnostics

    /// Get network interface information
    public func getNetworkInterfaces() async -> [NetworkInfo] {
        var interfaces: [NetworkInfo] = []

        let result = try? await executor.execute("ifconfig -a")
        guard let output = result?.output else { return [] }

        // Parse ifconfig output (simplified)
        var currentInterface: String?
        var ipAddress: String?
        var macAddress: String?
        var isActive = false

        for line in output.components(separatedBy: .newlines) {
            if line.first?.isLetter == true && line.contains(":") {
                // Save previous interface
                if let name = currentInterface {
                    interfaces.append(NetworkInfo(
                        interfaceName: name,
                        ipAddress: ipAddress,
                        macAddress: macAddress,
                        isActive: isActive,
                        bytesIn: 0,
                        bytesOut: 0,
                        packetsIn: 0,
                        packetsOut: 0
                    ))
                }

                currentInterface = line.components(separatedBy: ":").first
                ipAddress = nil
                macAddress = nil
                isActive = line.contains("status: active")
            } else if line.contains("inet ") && !line.contains("inet6") {
                ipAddress = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .dropFirst()
                    .first
            } else if line.contains("ether ") {
                macAddress = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .dropFirst()
                    .first
            } else if line.contains("status: active") {
                isActive = true
            }
        }

        // Don't forget last interface
        if let name = currentInterface {
            interfaces.append(NetworkInfo(
                interfaceName: name,
                ipAddress: ipAddress,
                macAddress: macAddress,
                isActive: isActive,
                bytesIn: 0,
                bytesOut: 0,
                packetsIn: 0,
                packetsOut: 0
            ))
        }

        return interfaces.filter { $0.ipAddress != nil || $0.isActive }
    }

    /// Test network connectivity
    public func testConnectivity(host: String = "8.8.8.8") async -> Bool {
        let result = try? await executor.execute("ping -c 1 -W 2 \(host) 2>/dev/null")
        return result?.isSuccess == true
    }

    /// Get external IP address
    public func getExternalIP() async -> String? {
        let result = try? await executor.execute("curl -s --connect-timeout 5 ifconfig.me 2>/dev/null")
        guard result?.isSuccess == true, let ip = result?.output, !ip.isEmpty else { return nil }
        return ip
    }

    // MARK: - Battery (MacBooks)

    /// Get battery information
    public func getBatteryInfo() async -> BatteryInfo? {
        let result = try? await executor.execute("pmset -g batt")
        guard let output = result?.output, output.contains("Battery") else {
            return nil // No battery (desktop Mac)
        }

        let isCharging = output.contains("charging") || output.contains("AC Power")
        var chargePercent = 0
        var timeRemaining: TimeInterval? = nil

        // Parse percentage
        if let percentMatch = output.range(of: #"(\d+)%"#, options: .regularExpression) {
            chargePercent = Int(output[percentMatch].replacingOccurrences(of: "%", with: "")) ?? 0
        }

        // Parse time remaining
        if let timeMatch = output.range(of: #"(\d+):(\d+) remaining"#, options: .regularExpression) {
            let timeStr = String(output[timeMatch])
            let parts = timeStr.replacingOccurrences(of: " remaining", with: "").components(separatedBy: ":")
            if parts.count == 2, let hours = Int(parts[0]), let mins = Int(parts[1]) {
                timeRemaining = Double(hours * 3600 + mins * 60)
            }
        }

        // Get cycle count
        let cycleResult = try? await executor.execute(
            "system_profiler SPPowerDataType | grep 'Cycle Count' | awk '{print $3}'"
        )
        let cycleCount = Int(cycleResult?.output ?? "") ?? 0

        // Get condition
        let conditionResult = try? await executor.execute(
            "system_profiler SPPowerDataType | grep 'Condition' | awk -F: '{print $2}'"
        )
        let condition = conditionResult?.output.trimmingCharacters(in: .whitespaces) ?? "Unknown"

        let powerSource = output.contains("AC Power") ? "AC Power" : "Battery"

        let info = BatteryInfo(
            isPresent: true,
            isCharging: isCharging,
            chargePercent: chargePercent,
            cycleCount: cycleCount,
            condition: condition,
            timeRemaining: timeRemaining,
            powerSource: powerSource
        )

        batteryInfo = info
        return info
    }

    // MARK: - Comprehensive Health Report

    /// Generate comprehensive health report
    public func generateHealthReport() async throws -> HealthReport {
        async let systemTask = getSystemInfo()
        async let cpuTask = getCPUInfo()
        async let memTask = getMemoryUsage()
        async let diskTask = getDiskUsage()
        async let processTask = getProcessCount()
        async let networkTask = getNetworkInterfaces()
        async let batteryTask = getBatteryInfo()

        let results = try await (systemTask, cpuTask, memTask, diskTask, processTask, networkTask, batteryTask)

        return HealthReport(
            timestamp: Date(),
            system: results.0,
            cpu: results.1,
            memoryUsagePercent: results.2,
            diskUsagePercent: results.3,
            processCount: results.4,
            networkInterfaces: results.5,
            battery: results.6
        )
    }

    /// Print system health summary to console
    public func printHealthSummary() async {
        guard let report = try? await generateHealthReport() else {
            print("Failed to generate health report")
            return
        }

        print("""
        ╔══════════════════════════════════════════════════════════════╗
        ║           macOS Silicon System Health Report                  ║
        ╚══════════════════════════════════════════════════════════════╝

        System: \(report.system.hostname)
        macOS: \(report.system.osVersion) (\(report.system.osBuild))
        Model: \(report.system.modelName)
        Architecture: \(report.system.architecture)
        Uptime: \(formatUptime(report.system.uptime))

        CPU: \(report.cpu.brandString)
        Cores: \(report.cpu.physicalCores) physical, \(report.cpu.logicalCores) logical
        Usage: \(String(format: "%.1f", report.cpu.usagePercent))%

        Memory Usage: \(String(format: "%.1f", report.memoryUsagePercent))%
        Disk Usage: \(String(format: "%.1f", report.diskUsagePercent))%
        Processes: \(report.processCount)

        Overall Health: \(report.overallHealth.rawValue)
        """)

        if let battery = report.battery {
            print("Battery: \(battery.summary)")
        }
    }

    // MARK: - Helpers

    private func parseMemoryString(_ str: String) -> Double {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        let number = Double(trimmed.dropLast()) ?? 0

        if trimmed.uppercased().hasSuffix("G") {
            return number * 1024
        } else if trimmed.uppercased().hasSuffix("M") {
            return number
        }
        return number
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds / 86400)
        let hours = Int((seconds.truncatingRemainder(dividingBy: 86400)) / 3600)
        let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days)d \(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Diagnostic Commands Reference

public enum DiagnosticCommands {

    // System info
    public static let systemProfile = "system_profiler SPHardwareDataType"
    public static let softwareProfile = "system_profiler SPSoftwareDataType"
    public static let osVersion = "sw_vers"
    public static let kernelInfo = "uname -a"
    public static let architecture = "arch"
    public static let hostname = "hostname"
    public static let uptime = "uptime"

    // CPU
    public static let cpuBrand = "sysctl -n machdep.cpu.brand_string"
    public static let cpuCores = "sysctl hw.ncpu"
    public static let cpuUsage = "top -l 1 -s 0 | grep 'CPU usage'"

    // Memory
    public static let memoryStatus = "top -l 1 -s 0 | grep PhysMem"
    public static let memoryPressure = "memory_pressure"
    public static let vmStat = "vm_stat"

    // Disk
    public static let diskFree = "df -h"
    public static let diskList = "diskutil list"
    public static let diskInfo = "diskutil info /"

    // Network
    public static let ifconfig = "ifconfig"
    public static let networkQuality = "networkQuality"
    public static let pingTest = "ping -c 3 8.8.8.8"
    public static let externalIP = "curl -s ifconfig.me"

    // Battery
    public static let batteryStatus = "pmset -g batt"
    public static let powerSettings = "pmset -g"
    public static let batteryProfile = "system_profiler SPPowerDataType"

    // Processes
    public static let processCount = "ps aux | wc -l"
    public static let topProcesses = "top -l 1 -s 0 -n 20"

    // Logs
    public static let recentErrors = "log show --last 1h --predicate 'eventMessage contains \"error\"' --style compact | tail -20"
    public static let systemLog = "log show --last 30m"
}
