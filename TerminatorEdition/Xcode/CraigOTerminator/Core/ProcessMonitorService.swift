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
    private var isFetching = false // Prevent concurrent fetches

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
        guard !isMonitoring else {
            print("ProcessMonitorService: Already monitoring, skipping")
            return
        }

        print("ProcessMonitorService: ===== STARTING BACKGROUND MONITORING =====")
        isMonitoring = true

        print("ProcessMonitorService: Creating initial fetch task...")
        // Initial fetch
        Task {
            print("ProcessMonitorService: Inside initial fetch Task")
            await fetchProcesses()
            print("ProcessMonitorService: Initial fetch completed")
        }

        // Set up periodic updates
        print("ProcessMonitorService: Setting up timer with interval \(updateInterval)s...")
        monitorTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            print("ProcessMonitorService: Timer fired, creating fetch task...")
            Task { @MainActor [weak self] in
                await self?.fetchProcesses()
            }
        }
        print("ProcessMonitorService: Timer setup complete, monitoring active")
    }

    func stopMonitoring() {
        print("ProcessMonitorService: Stopping background monitoring...")
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    // MARK: - Process Fetching

    func fetchProcesses() async {
        // Prevent concurrent fetches
        if isFetching {
            print("ProcessMonitorService: Already fetching, skipping...")
            return
        }

        print("ProcessMonitorService: fetchProcesses() called")
        isFetching = true

        // Run in detached task to avoid blocking
        let data = await Task.detached {
            await self.fetchProcessData()
        }.value

        print("ProcessMonitorService: fetchProcessData returned \(data.processes.count) processes, CPU: \(data.totalCPU), Mem: \(data.totalMemory)")

        // Defer before updating @Published properties
        await Task.yield()
        await Task.yield()

        // Update on main actor
        processes = data.processes
        cpuUsageTotal = data.totalCPU
        memoryUsageTotal = data.totalMemory
        lastUpdateTime = Date()
        isFetching = false

        print("ProcessMonitorService: Updated \(processes.count) processes")
    }

    private func fetchProcessData() async -> (processes: [ProcessInfo], totalCPU: Double, totalMemory: Double) {
        print("ProcessMonitorService: fetchProcessData() starting...")
        var processList: [ProcessInfo] = []
        var totalCPU: Double = 0
        var totalMemory: Double = 0

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["aux"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.standardInput = Pipe() // Close stdin to prevent hanging

        var output = ""

        do {
            print("ProcessMonitorService: Launching ps process...")

            // Read output asynchronously
            let outputHandle = pipe.fileHandleForReading

            try task.run()

            // Close stdin immediately so ps doesn't wait for input
            if let stdinPipe = task.standardInput as? Pipe {
                try? stdinPipe.fileHandleForWriting.close()
            }

            print("ProcessMonitorService: Reading output...")

            // Read with timeout using async
            let readTask = Task<Data, Error> {
                return outputHandle.readDataToEndOfFile()
            }

            // Wait for both task completion and data with timeout
            let timeoutTask = Task<Void, Error> {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                throw NSError(domain: "Timeout", code: -1)
            }

            let dataResult: Data
            do {
                dataResult = try await withThrowingTaskGroup(of: Data.self) { group in
                    group.addTask { try await readTask.value }

                    // Race between read and timeout
                    if let result = try await group.next() {
                        timeoutTask.cancel()
                        return result
                    }
                    throw NSError(domain: "Timeout", code: -1)
                }
            } catch {
                print("ProcessMonitorService: Read timed out, terminating process...")
                task.terminate()
                readTask.cancel()
                timeoutTask.cancel()
                return ([], 0, 0)
            }

            task.waitUntilExit()

            print("ProcessMonitorService: ps completed with status \(task.terminationStatus)")
            print("ProcessMonitorService: Read \(dataResult.count) bytes")

            guard let decodedOutput = String(data: dataResult, encoding: .utf8) else {
                print("ProcessMonitorService: Failed to decode ps output")
                return ([], 0, 0)
            }

            output = decodedOutput

        } catch {
            print("ProcessMonitorService: Failed to run ps: \(error)")
            return ([], 0, 0)
        }

        // Parse output - limit to maxProcessCount
        let lines = output.components(separatedBy: "\n")
        print("ProcessMonitorService: ps command returned \(lines.count) lines")

        for (index, line) in lines.enumerated() {
            // Skip header line
            if index == 0 { continue }
            guard !line.isEmpty else { continue }

            // Limit to maxProcessCount
            if processList.count >= maxProcessCount {
                break
            }

            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 11 else { continue }

            // Parse fields
            let user = String(parts[0])
            guard let pid = Int(parts[1]) else { continue }
            guard let cpu = Double(parts[2]) else { continue }
            guard let mem = Double(parts[3]) else { continue }

            // VSZ and RSS (virtual and resident memory)
            _ = Int(parts[4]) ?? 0 // VSZ (virtual size) - not currently used
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
