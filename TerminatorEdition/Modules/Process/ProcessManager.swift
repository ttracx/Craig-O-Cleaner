import Foundation

// MARK: - Process Manager
/// Comprehensive process management for macOS Silicon
/// Handles listing, monitoring, and terminating processes

@MainActor
public final class ProcessManager: ObservableObject {

    // MARK: - Types

    public struct ProcessInfo: Identifiable, Sendable {
        public let id: Int
        public var pid: Int { id }
        public let name: String
        public let user: String
        public let cpuPercent: Double
        public let memoryPercent: Double
        public let memoryMB: Double
        public let command: String
        public let parentPID: Int?

        public var isSystemCritical: Bool {
            let criticalProcesses = [
                "kernel_task", "launchd", "WindowServer", "loginwindow",
                "Finder", "Dock", "SystemUIServer", "ControlCenter",
                "cfprefsd", "coreaudiod", "coreservicesd", "mds", "mds_stores",
                "notifyd", "diskarbitrationd", "fseventsd", "securityd",
                "UserEventAgent", "trustd", "syspolicyd"
            ]
            return criticalProcesses.contains(name) || pid <= 1
        }
    }

    public struct LaunchAgent: Identifiable, Sendable {
        public let id: String
        public var label: String { id }
        public let pid: Int?
        public let status: String
        public let path: String?
        public let isRunning: Bool
        public let domain: AgentDomain

        public enum AgentDomain: String, Sendable {
            case user = "User"
            case system = "System"
            case global = "Global"
        }
    }

    public struct TerminationResult {
        public let pid: Int
        public let processName: String
        public let success: Bool
        public let wasForced: Bool
        public let error: String?
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var processes: [ProcessInfo] = []
    @Published public private(set) var launchAgents: [LaunchAgent] = []

    // MARK: - Process Listing

    /// Get all running processes
    public func listAllProcesses() async throws -> [ProcessInfo] {
        let result = try await executor.execute(
            "ps aux | tail -n +2"
        )

        guard result.isSuccess else {
            throw CommandExecutor.CommandError.executionFailed(result.error)
        }

        let processes = parseProcessList(result.output)
        self.processes = processes
        return processes
    }

    /// Get processes sorted by CPU usage
    public func getProcessesByCPU(limit: Int = 20) async throws -> [ProcessInfo] {
        let result = try await executor.execute(
            "ps aux --sort=-%cpu | head -\(limit + 1) | tail -n +2"
        )

        guard result.isSuccess else {
            throw CommandExecutor.CommandError.executionFailed(result.error)
        }

        return parseProcessList(result.output)
    }

    /// Get processes sorted by memory usage
    public func getProcessesByMemory(limit: Int = 20, minimumMB: Double = 0) async throws -> [ProcessInfo] {
        let result = try await executor.execute(
            "ps aux --sort=-%mem | head -\(limit + 1) | tail -n +2"
        )

        guard result.isSuccess else {
            throw CommandExecutor.CommandError.executionFailed(result.error)
        }

        let processes = parseProcessList(result.output)
        if minimumMB > 0 {
            return processes.filter { $0.memoryMB >= minimumMB }
        }
        return processes
    }

    /// Find process by name
    public func findProcess(name: String) async throws -> [ProcessInfo] {
        let result = try await executor.execute(
            "ps aux | grep -i \"\(name)\" | grep -v grep"
        )

        // grep returns exit code 1 if no matches
        if result.output.isEmpty {
            return []
        }

        return parseProcessList(result.output)
    }

    /// Find process by PID
    public func getProcess(pid: Int) async throws -> ProcessInfo? {
        let result = try await executor.execute(
            "ps aux | awk '$2 == \(pid)'"
        )

        let processes = parseProcessList(result.output)
        return processes.first
    }

    /// Get processes using a specific port
    public func getProcessesUsingPort(_ port: Int) async throws -> [ProcessInfo] {
        let result = try await executor.execute(
            "lsof -i :\(port) -t 2>/dev/null"
        )

        guard result.isSuccess, !result.output.isEmpty else {
            return []
        }

        let pids = result.output.components(separatedBy: .newlines)
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        var processes: [ProcessInfo] = []
        for pid in pids {
            if let process = try? await getProcess(pid: pid) {
                processes.append(process)
            }
        }

        return processes
    }

    // MARK: - Process Termination

    /// Terminate process by PID (graceful)
    public func terminateProcess(pid: Int, force: Bool = false) async throws -> Bool {
        let signal = force ? "-9" : "-15"
        let result = try await executor.execute("kill \(signal) \(pid)")
        return result.isSuccess || result.error.contains("No such process")
    }

    /// Terminate all processes by name
    public func terminateAllByName(_ name: String, force: Bool = false) async throws -> Int {
        let signal = force ? "-9 " : ""
        let result = try await executor.execute("killall \(signal)\"\(name)\" 2>/dev/null; echo $?")

        // Count how many were killed
        let countResult = try await executor.execute("pgrep -c \"\(name)\" 2>/dev/null || echo 0")
        let remaining = Int(countResult.output) ?? 0

        let beforeCount = try? await findProcess(name: name).count ?? 0
        return max(0, (beforeCount ?? 0) - remaining)
    }

    /// Force quit application by name
    public func forceQuitApplication(_ appName: String) async throws {
        // First try graceful quit via AppleScript
        let appleScript = "tell application \"\(appName)\" to quit"
        _ = try? await executor.executeAppleScript(appleScript)

        // Wait a moment
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Check if still running, force kill if needed
        let stillRunning = try await findProcess(name: appName)
        if !stillRunning.isEmpty {
            _ = try await executor.execute("killall -9 \"\(appName)\"")
        }
    }

    /// Terminate resource-heavy processes
    public func terminateResourceHogs(
        cpuThreshold: Double = 90,
        memoryThresholdMB: Double = 1000,
        excludeApps: [String] = []
    ) async throws -> [TerminationResult] {

        var results: [TerminationResult] = []

        let cpuHogs = try await getProcessesByCPU(limit: 50)
        let memHogs = try await getProcessesByMemory(limit: 50, minimumMB: memoryThresholdMB)

        let candidates = Set(cpuHogs.filter { $0.cpuPercent > cpuThreshold }.map { $0.pid })
            .union(Set(memHogs.map { $0.pid }))

        for pid in candidates {
            guard let process = try? await getProcess(pid: pid) else { continue }

            // Skip system critical and excluded apps
            if process.isSystemCritical { continue }
            if excludeApps.contains(where: { process.name.lowercased().contains($0.lowercased()) }) {
                continue
            }

            let success = try await terminateProcess(pid: pid, force: false)
            results.append(TerminationResult(
                pid: pid,
                processName: process.name,
                success: success,
                wasForced: false,
                error: success ? nil : "Failed to terminate"
            ))
        }

        return results
    }

    /// Pause a process (SIGSTOP)
    public func pauseProcess(pid: Int) async throws {
        _ = try await executor.execute("kill -STOP \(pid)")
    }

    /// Resume a paused process (SIGCONT)
    public func resumeProcess(pid: Int) async throws {
        _ = try await executor.execute("kill -CONT \(pid)")
    }

    // MARK: - Launch Agents & Daemons

    /// List all launch agents
    public func listLaunchAgents() async throws -> [LaunchAgent] {
        var agents: [LaunchAgent] = []

        // User launch agents
        let userAgents = try await listAgentsInDirectory(
            "~/Library/LaunchAgents",
            domain: .user
        )
        agents.append(contentsOf: userAgents)

        // System launch agents
        let systemAgents = try await listAgentsInDirectory(
            "/Library/LaunchAgents",
            domain: .global
        )
        agents.append(contentsOf: systemAgents)

        self.launchAgents = agents
        return agents
    }

    private func listAgentsInDirectory(_ path: String, domain: LaunchAgent.AgentDomain) async throws -> [LaunchAgent] {
        let expandedPath = (path as NSString).expandingTildeInPath
        let result = try await executor.execute("ls \(expandedPath) 2>/dev/null || echo ''")

        guard !result.output.isEmpty else { return [] }

        var agents: [LaunchAgent] = []
        let files = result.output.components(separatedBy: .newlines)

        for file in files where file.hasSuffix(".plist") {
            let label = file.replacingOccurrences(of: ".plist", with: "")
            let fullPath = "\(expandedPath)/\(file)"

            // Check if running
            let statusResult = try? await executor.execute("launchctl list | grep \"\(label)\"")
            let isRunning = statusResult?.isSuccess == true && !statusResult!.output.isEmpty

            var pid: Int? = nil
            if isRunning, let output = statusResult?.output {
                let components = output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let pidStr = components.first, let parsedPid = Int(pidStr) {
                    pid = parsedPid
                }
            }

            agents.append(LaunchAgent(
                id: label,
                pid: pid,
                status: isRunning ? "Running" : "Stopped",
                path: fullPath,
                isRunning: isRunning,
                domain: domain
            ))
        }

        return agents
    }

    /// Stop a launch agent
    public func stopLaunchAgent(label: String) async throws {
        _ = try await executor.execute("launchctl stop \(label)")
    }

    /// Start a launch agent
    public func startLaunchAgent(label: String) async throws {
        _ = try await executor.execute("launchctl start \(label)")
    }

    /// Unload a launch agent
    public func unloadLaunchAgent(path: String) async throws {
        _ = try await executor.execute("launchctl unload \"\(path)\"")
    }

    /// Load a launch agent
    public func loadLaunchAgent(path: String) async throws {
        _ = try await executor.execute("launchctl load \"\(path)\"")
    }

    /// Restart a launch agent
    public func restartLaunchAgent(label: String) async throws {
        let userId = try await executor.execute("id -u")
        _ = try await executor.execute("launchctl kickstart -k gui/\(userId.output)/\(label)")
    }

    // MARK: - Parsing Helpers

    private func parseProcessList(_ output: String) -> [ProcessInfo] {
        let lines = output.components(separatedBy: .newlines)
        var processes: [ProcessInfo] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // ps aux format: USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 11 else { continue }

            let user = components[0]
            guard let pid = Int(components[1]) else { continue }
            let cpu = Double(components[2]) ?? 0
            let mem = Double(components[3]) ?? 0
            let rss = Double(components[5]) ?? 0  // RSS in KB
            let memoryMB = rss / 1024.0
            let command = components[10...].joined(separator: " ")
            let name = URL(fileURLWithPath: components[10]).lastPathComponent

            processes.append(ProcessInfo(
                id: pid,
                name: name,
                user: user,
                cpuPercent: cpu,
                memoryPercent: mem,
                memoryMB: memoryMB,
                command: command,
                parentPID: nil
            ))
        }

        return processes
    }
}

// MARK: - Process Commands Reference

public enum ProcessCommands {
    // Listing
    public static let listAll = "ps aux"
    public static let listByCPU = "ps aux --sort=-%cpu | head -20"
    public static let listByMemory = "ps aux --sort=-%mem | head -20"
    public static let topSnapshot = "top -l 1 -s 0 | head -20"

    // Finding
    public static func findByName(_ name: String) -> String {
        "pgrep -l \"\(name)\""
    }

    public static func findByPort(_ port: Int) -> String {
        "lsof -i :\(port)"
    }

    // Termination
    public static func kill(pid: Int, force: Bool = false) -> String {
        force ? "kill -9 \(pid)" : "kill \(pid)"
    }

    public static func killAll(name: String, force: Bool = false) -> String {
        let signal = force ? "-9 " : ""
        return "killall \(signal)\"\(name)\""
    }

    // Launch agents
    public static let listLaunchctl = "launchctl list"
    public static let listRunningAgents = "launchctl list | grep -v '^-'"

    public static func stopAgent(label: String) -> String {
        "launchctl stop \(label)"
    }

    public static func startAgent(label: String) -> String {
        "launchctl start \(label)"
    }
}
