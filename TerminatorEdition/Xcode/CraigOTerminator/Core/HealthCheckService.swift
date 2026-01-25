import Foundation
import AppKit
import OSLog

/// Diagnostic health check service for troubleshooting
@MainActor
final class HealthCheckService: ObservableObject {

    static let shared = HealthCheckService()

    private let logger = Logger(subsystem: "ai.neuralquantum.CraigOTerminator", category: "HealthCheck")

    @Published var isRunning = false
    @Published var results: [HealthCheckResult] = []
    @Published var lastRunTime: Date?

    struct HealthCheckResult: Identifiable {
        let id = UUID()
        let category: String
        let name: String
        let status: Status
        let message: String
        let details: String?

        enum Status {
            case pass
            case warning
            case fail
            case info

            var icon: String {
                switch self {
                case .pass: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .fail: return "xmark.circle.fill"
                case .info: return "info.circle.fill"
                }
            }

            var color: String {
                switch self {
                case .pass: return "green"
                case .warning: return "orange"
                case .fail: return "red"
                case .info: return "blue"
                }
            }
        }
    }

    private init() {}

    // MARK: - Run Health Check

    func runFullHealthCheck() async {
        logger.info("🏥 Starting full health check...")
        isRunning = true
        results = []

        await checkSystemInfo()
        await checkPermissions()
        await checkShellCommands()
        await checkAutomation()
        await checkFileSystemAccess()
        await checkServices()

        lastRunTime = Date()
        isRunning = false
        logger.info("✅ Health check complete: \(self.results.count) checks performed")
    }

    // MARK: - System Info

    private func checkSystemInfo() async {
        logger.debug("Checking system info...")

        let processInfo = ProcessInfo.processInfo

        addResult(
            category: "System",
            name: "macOS Version",
            status: .info,
            message: processInfo.operatingSystemVersionString,
            details: nil
        )

        addResult(
            category: "System",
            name: "Architecture",
            status: .info,
            message: "\(processInfo.processorCount) cores",
            details: "Physical Memory: \(ByteCountFormatter.string(fromByteCount: Int64(processInfo.physicalMemory), countStyle: .memory))"
        )

        // Check if running as menu bar app
        let isMenuBarApp = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true
        addResult(
            category: "System",
            name: "App Type",
            status: isMenuBarApp ? .pass : .warning,
            message: isMenuBarApp ? "Menu Bar App (LSUIElement=true)" : "Standard App",
            details: isMenuBarApp ? "No Dock icon, background operation" : nil
        )

        // Check sandbox status
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        addResult(
            category: "System",
            name: "App Sandbox",
            status: .info,
            message: isSandboxed ? "Enabled (Restricted)" : "Disabled (Full Access)",
            details: isSandboxed ? "Limited system access" : "Full system access, requires careful security management"
        )
    }

    // MARK: - Permissions

    private func checkPermissions() async {
        logger.debug("Checking TCC permissions...")

        let permissionsManager = PermissionsManager.shared
        await permissionsManager.checkAllPermissions()

        for permissionType in PermissionsManager.PermissionType.allCases {
            let status = permissionsManager.getStatus(for: permissionType)

            let checkStatus: HealthCheckResult.Status
            let message: String
            var details: String?

            switch status {
            case .granted:
                checkStatus = .pass
                message = "Granted"
            case .denied:
                checkStatus = .fail
                message = "Denied"
                details = "Grant in System Settings → Privacy & Security → \(permissionType.rawValue)"
            case .notDetermined:
                checkStatus = .warning
                message = "Not Requested"
                details = "Permission will be requested when needed"
            }

            addResult(
                category: "Permissions",
                name: permissionType.rawValue,
                status: checkStatus,
                message: message,
                details: details
            )
        }
    }

    // MARK: - Shell Commands

    private func checkShellCommands() async {
        logger.debug("Testing shell command execution...")

        // Test ps command
        let psResult = await testShellCommand(
            name: "ps Command",
            executable: "/bin/ps",
            arguments: ["aux"],
            timeout: 2.0,
            expectedOutput: "USER"
        )
        addResult(
            category: "Shell Commands",
            name: psResult.name,
            status: psResult.status,
            message: psResult.message,
            details: psResult.details
        )

        // Test lsof command
        let lsofResult = await testShellCommand(
            name: "lsof Command",
            executable: "/usr/sbin/lsof",
            arguments: ["-v"],
            timeout: 2.0,
            expectedOutput: "lsof"
        )
        addResult(
            category: "Shell Commands",
            name: lsofResult.name,
            status: lsofResult.status,
            message: lsofResult.message,
            details: lsofResult.details
        )

        // Test osascript command
        let osascriptResult = await testShellCommand(
            name: "osascript Command",
            executable: "/usr/bin/osascript",
            arguments: ["-e", "return \"test\""],
            timeout: 2.0,
            expectedOutput: "test"
        )
        addResult(
            category: "Shell Commands",
            name: osascriptResult.name,
            status: osascriptResult.status,
            message: osascriptResult.message,
            details: osascriptResult.details
        )
    }

    private func testShellCommand(
        name: String,
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        expectedOutput: String?
    ) async -> (name: String, status: HealthCheckResult.Status, message: String, details: String?) {

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.standardInput = Pipe()

        do {
            let startTime = Date()
            try task.run()

            // Close stdin
            if let stdinPipe = task.standardInput as? Pipe {
                try? stdinPipe.fileHandleForWriting.close()
            }

            // Read with timeout
            let readTask = Task<Data, Error> {
                return pipe.fileHandleForReading.readDataToEndOfFile()
            }

            let timeoutTask = Task<Void, Error> {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(domain: "Timeout", code: -1)
            }

            let dataResult: Data
            do {
                dataResult = try await withThrowingTaskGroup(of: Data.self) { group in
                    group.addTask { try await readTask.value }

                    if let result = try await group.next() {
                        timeoutTask.cancel()
                        return result
                    }
                    throw NSError(domain: "Timeout", code: -1)
                }
            } catch {
                task.terminate()
                readTask.cancel()
                timeoutTask.cancel()
                return (name, .fail, "Timed out after \(timeout)s", "Command hung and was terminated")
            }

            task.waitUntilExit()
            let duration = Date().timeIntervalSince(startTime)

            if task.terminationStatus == 0 {
                if let output = String(data: dataResult, encoding: .utf8) {
                    let outputPreview = output.prefix(100)

                    if let expected = expectedOutput, !output.contains(expected) {
                        return (name, .warning, "Unexpected output", "Expected '\(expected)' but got: \(outputPreview)")
                    }

                    return (name, .pass, "Success (\(String(format: "%.2f", duration))s)", "Output: \(dataResult.count) bytes")
                } else {
                    return (name, .warning, "Success but no output", "Completed in \(String(format: "%.2f", duration))s")
                }
            } else {
                return (name, .fail, "Failed with status \(task.terminationStatus)", nil)
            }

        } catch {
            return (name, .fail, "Failed to execute", error.localizedDescription)
        }
    }

    // MARK: - Automation

    private func checkAutomation() async {
        logger.debug("Testing AppleScript automation...")

        // Test Safari automation
        let safariResult = await testBrowserAutomation(browser: "Safari")
        addResult(
            category: "Automation",
            name: "Safari Automation",
            status: safariResult.status,
            message: safariResult.message,
            details: safariResult.details
        )

        // Test Chrome automation
        let chromeResult = await testBrowserAutomation(browser: "Google Chrome")
        addResult(
            category: "Automation",
            name: "Chrome Automation",
            status: chromeResult.status,
            message: chromeResult.message,
            details: chromeResult.details
        )
    }

    private func testBrowserAutomation(browser: String) async -> (status: HealthCheckResult.Status, message: String, details: String?) {
        let script = """
        tell application "\(browser)"
            if it is running then
                return "running"
            else
                return "not running"
            end if
        end tell
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return (.pass, "\(browser) is \(output)", "Automation permission granted")
                }
                return (.pass, "Success", nil)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8) {
                    if errorOutput.contains("Not authorized") || errorOutput.contains("not allowed") {
                        return (.fail, "Not Authorized", "Grant automation permission in System Settings → Privacy & Security → Automation")
                    }
                    return (.warning, "Error", errorOutput.prefix(200).description)
                }
                return (.fail, "Failed with status \(task.terminationStatus)", nil)
            }
        } catch {
            return (.fail, "Failed to execute", error.localizedDescription)
        }
    }

    // MARK: - File System

    private func checkFileSystemAccess() async {
        logger.debug("Testing file system access...")

        // Test home directory read
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let canReadHome = FileManager.default.isReadableFile(atPath: homeURL.path)
        addResult(
            category: "File System",
            name: "Home Directory Read",
            status: canReadHome ? .pass : .fail,
            message: canReadHome ? "Accessible" : "Not Accessible",
            details: homeURL.path
        )

        // Test temp directory write
        let tempURL = FileManager.default.temporaryDirectory
        let testFile = tempURL.appendingPathComponent("health_check_test.txt")

        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            addResult(
                category: "File System",
                name: "Temp Directory Write",
                status: .pass,
                message: "Writable",
                details: tempURL.path
            )
        } catch {
            addResult(
                category: "File System",
                name: "Temp Directory Write",
                status: .fail,
                message: "Not Writable",
                details: error.localizedDescription
            )
        }
    }

    // MARK: - Services

    private func checkServices() async {
        logger.debug("Checking service status...")

        // Check ProcessMonitorService
        let processMonitor = ProcessMonitorService.shared
        addResult(
            category: "Services",
            name: "Process Monitor",
            status: processMonitor.isMonitoring ? .pass : .warning,
            message: processMonitor.isMonitoring ? "Running" : "Not Running",
            details: processMonitor.isMonitoring ? "\(processMonitor.processes.count) processes tracked" : "Start monitoring to enable"
        )

        // Check PermissionMonitor
        let permissionMonitor = PermissionMonitor.shared
        addResult(
            category: "Services",
            name: "Permission Monitor",
            status: permissionMonitor.isMonitoring ? .pass : .warning,
            message: permissionMonitor.isMonitoring ? "Running" : "Not Running",
            details: nil
        )

        // Check BrowserTabService
        let browserTabService = BrowserTabService.shared
        addResult(
            category: "Services",
            name: "Browser Tab Service",
            status: .info,
            message: "\(browserTabService.tabs.count) tabs cached",
            details: browserTabService.isLoading ? "Currently loading..." : nil
        )
    }

    // MARK: - Helpers

    private func addResult(
        category: String,
        name: String,
        status: HealthCheckResult.Status,
        message: String,
        details: String?
    ) {
        let result = HealthCheckResult(
            category: category,
            name: name,
            status: status,
            message: message,
            details: details
        )
        results.append(result)

        // Log to console
        let emoji = status == .pass ? "✅" : status == .warning ? "⚠️" : status == .fail ? "❌" : "ℹ️"
        logger.info("\(emoji) [\(category)] \(name): \(message)")
        if let details = details {
            logger.debug("   Details: \(details)")
        }
    }

    // MARK: - Export

    func exportReport() -> String {
        var report = """
        Craig-O Terminator Health Check Report
        Generated: \(Date().formatted(date: .long, time: .complete))

        """

        let groupedResults = Dictionary(grouping: results) { $0.category }
        let sortedCategories = groupedResults.keys.sorted()

        for category in sortedCategories {
            report += "\n## \(category)\n\n"

            if let categoryResults = groupedResults[category] {
                for result in categoryResults {
                    let icon = result.status == .pass ? "✅" : result.status == .warning ? "⚠️" : result.status == .fail ? "❌" : "ℹ️"
                    report += "  \(icon) \(result.name): \(result.message)\n"
                    if let details = result.details {
                        report += "     → \(details)\n"
                    }
                }
            }
        }

        // Summary
        let passCount = results.filter { $0.status == .pass }.count
        let warningCount = results.filter { $0.status == .warning }.count
        let failCount = results.filter { $0.status == .fail }.count

        report += """


        ## Summary

        Total Checks: \(results.count)
        ✅ Passed: \(passCount)
        ⚠️ Warnings: \(warningCount)
        ❌ Failed: \(failCount)

        """

        return report
    }
}
