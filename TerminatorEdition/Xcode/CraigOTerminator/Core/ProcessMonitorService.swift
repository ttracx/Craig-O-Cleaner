import Foundation
import Combine

/// Background service that continuously monitors system processes
@MainActor
final class ProcessMonitorService: ObservableObject {

    static let shared = ProcessMonitorService()

    @Published var processes: [ProcessInfo] = []
    @Published var isMonitoring = false
    @Published var lastUpdateTime: Date?
    @Published var cpuUsageTotal: Double = 0
    @Published var memoryUsageTotal: Double = 0

    private var monitorTimer: Timer?
    private let updateInterval: TimeInterval = 3.0 // Update every 3 seconds
    private let maxProcessCount = 200 // Limit stored processes

    struct ProcessInfo: Identifiable, Hashable {
        let id = UUID()
        let pid: Int
        let name: String
        let user: String
        let cpuPercent: Double
        let memoryPercent: Double
        let memoryMB: Double
        let command: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(pid)
        }

        static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
            lhs.pid == rhs.pid
        }

        var isSystemProcess: Bool {
            user == "root" || user == "_windowserver" || user == "_coreaudiod"
        }

        var isHeavy: Bool {
            cpuPercent > 50 || memoryPercent > 5
        }
    }

    private init() {}

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }

        print("ProcessMonitorService: Starting background monitoring...")
        isMonitoring = true

        // Initial fetch
        Task {
            await fetchProcesses()
        }

        // Set up periodic updates
        monitorTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchProcesses()
            }
        }
    }

    func stopMonitoring() {
        print("ProcessMonitorService: Stopping background monitoring...")
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    // MARK: - Process Fetching

    func fetchProcesses() async {
        // Run in detached task to avoid blocking
        let data = await Task.detached {
            await self.fetchProcessData()
        }.value

        // Defer before updating @Published properties
        await Task.yield()
        await Task.yield()

        // Update on main actor
        processes = data.processes
        cpuUsageTotal = data.totalCPU
        memoryUsageTotal = data.totalMemory
        lastUpdateTime = Date()

        print("ProcessMonitorService: Updated \(processes.count) processes")
    }

    private func fetchProcessData() async -> (processes: [ProcessInfo], totalCPU: Double, totalMemory: Double) {
        var processList: [ProcessInfo] = []
        var totalCPU: Double = 0
        var totalMemory: Double = 0

        // Use ps aux with sorting for better performance
        let command = "ps aux --sort=-%mem | head -\(maxProcessCount)"

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else {
                print("ProcessMonitorService: ps command failed")
                return ([], 0, 0)
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return ([], 0, 0)
            }

            // Parse output
            let lines = output.components(separatedBy: "\n")

            for (index, line) in lines.enumerated() {
                // Skip header line
                if index == 0 { continue }
                guard !line.isEmpty else { continue }

                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 11 else { continue }

                // Parse fields
                let user = String(parts[0])
                guard let pid = Int(parts[1]) else { continue }
                guard let cpu = Double(parts[2]) else { continue }
                guard let mem = Double(parts[3]) else { continue }

                // VSZ and RSS (virtual and resident memory)
                let vsz = Int(parts[4]) ?? 0
                let rss = Int(parts[5]) ?? 0
                let memoryMB = Double(rss) / 1024.0 // Convert KB to MB

                // Command (everything after the first 10 fields)
                let commandParts = parts[10...]
                let fullCommand = commandParts.joined(separator: " ")
                let name = String(fullCommand.split(separator: "/").last ?? "")
                    .trimmingCharacters(in: .whitespaces)

                if !name.isEmpty {
                    processList.append(ProcessInfo(
                        pid: pid,
                        name: name,
                        user: user,
                        cpuPercent: cpu,
                        memoryPercent: mem,
                        memoryMB: memoryMB,
                        command: fullCommand
                    ))

                    totalCPU += cpu
                    totalMemory += mem
                }
            }

            print("ProcessMonitorService: Fetched \(processList.count) processes")

        } catch {
            print("ProcessMonitorService: Error fetching processes: \(error)")
        }

        return (processList, totalCPU, totalMemory)
    }

    // MARK: - Filtering & Searching

    func topProcessesByCPU(limit: Int = 10) -> [ProcessInfo] {
        Array(processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(limit))
    }

    func topProcessesByMemory(limit: Int = 10) -> [ProcessInfo] {
        Array(processes.sorted { $0.memoryPercent > $1.memoryPercent }.prefix(limit))
    }

    func heavyProcesses() -> [ProcessInfo] {
        processes.filter { $0.isHeavy }
    }

    func searchProcesses(query: String) -> [ProcessInfo] {
        guard !query.isEmpty else { return processes }
        let lowercased = query.lowercased()
        return processes.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.command.lowercased().contains(lowercased) ||
            String($0.pid).contains(query)
        }
    }

    func processesForUser(_ user: String) -> [ProcessInfo] {
        processes.filter { $0.user == user }
    }

    // MARK: - Process Actions

    func killProcess(pid: Int, force: Bool = false) async -> Result<Void, Error> {
        await Task.detached {
            let signal = force ? "-9" : "-15" // SIGKILL vs SIGTERM
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = [signal, String(pid)]
            task.standardOutput = Pipe()
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    return Result.success(())
                } else {
                    return Result.failure(NSError(domain: "ProcessMonitor", code: Int(task.terminationStatus)))
                }
            } catch {
                return Result.failure(error)
            }
        }.value
    }

    func killProcesses(_ pids: [Int], force: Bool = false) async -> (succeeded: Int, failed: Int) {
        var succeeded = 0
        var failed = 0

        for pid in pids {
            let result = await killProcess(pid: pid, force: force)
            switch result {
            case .success:
                succeeded += 1
            case .failure:
                failed += 1
            }
        }

        // Refresh process list after killing
        await fetchProcesses()

        return (succeeded, failed)
    }

    // MARK: - Port & File Monitoring

    func processesUsingPort(_ port: Int) async -> [ProcessInfo] {
        await Task.detached {
            let task = Process()
            task.launchPath = "/usr/sbin/lsof"
            task.arguments = ["-i", ":\(port)", "-n", "-P"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            var foundPIDs: Set<Int> = []

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: "\n")
                    for line in lines.dropFirst() { // Skip header
                        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                        if parts.count >= 2, let pid = Int(parts[1]) {
                            foundPIDs.insert(pid)
                        }
                    }
                }
            } catch {
                print("ProcessMonitorService: lsof failed: \(error)")
            }

            return foundPIDs
        }.value.compactMap { pid in
            processes.first { $0.pid == pid }
        }
    }

    func processesUsingDirectory(_ path: String) async -> [ProcessInfo] {
        await Task.detached {
            let task = Process()
            task.launchPath = "/usr/sbin/lsof"
            task.arguments = ["+D", path]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            var foundPIDs: Set<Int> = []

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: "\n")
                    for line in lines.dropFirst() {
                        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                        if parts.count >= 2, let pid = Int(parts[1]) {
                            foundPIDs.insert(pid)
                        }
                    }
                }
            } catch {
                print("ProcessMonitorService: lsof failed: \(error)")
            }

            return foundPIDs
        }.value.compactMap { pid in
            processes.first { $0.pid == pid }
        }
    }

    // MARK: - Statistics

    func processStatistics() -> ProcessStatistics {
        ProcessStatistics(
            total: processes.count,
            running: processes.count, // All listed processes are running
            sleeping: 0, // Would need different parsing for state
            system: processes.filter { $0.isSystemProcess }.count,
            user: processes.filter { !$0.isSystemProcess }.count,
            heavy: processes.filter { $0.isHeavy }.count,
            totalCPU: cpuUsageTotal,
            totalMemory: memoryUsageTotal
        )
    }

    struct ProcessStatistics {
        let total: Int
        let running: Int
        let sleeping: Int
        let system: Int
        let user: Int
        let heavy: Int
        let totalCPU: Double
        let totalMemory: Double
    }
}
