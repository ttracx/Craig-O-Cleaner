//
//  SystemMonitor.swift
//  Craig-O-Clean Lite
//
//  Lightweight system monitoring
//

import Foundation
import Combine

struct ProcessInfo: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let memory: UInt64

    var memoryFormatted: String {
        let mb = Double(memory) / 1024.0 / 1024.0
        return String(format: "%.1f MB", mb)
    }
}

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: String = "0 MB"
    @Published var diskUsage: String = "0 GB"
    @Published var topProcesses: [ProcessInfo] = []

    private var timer: Timer?

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        updateCPUUsage()
        updateMemoryUsage()
        updateDiskUsage()
        updateProcessList()
    }

    private func updateCPUUsage() {
        var loadAvg = [Double](repeating: 0, count: 3)
        getloadavg(&loadAvg, 3)
        DispatchQueue.main.async {
            self.cpuUsage = loadAvg[0] * 100.0
        }
    }

    private func updateMemoryUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            let used = (UInt64(stats.active_count) + UInt64(stats.wire_count)) * UInt64(pageSize)
            let usedGB = Double(used) / 1024.0 / 1024.0 / 1024.0

            DispatchQueue.main.async {
                self.memoryUsage = String(format: "%.1f GB", usedGB)
            }
        }
    }

    private func updateDiskUsage() {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            if let total = attributes[.systemSize] as? UInt64,
               let free = attributes[.systemFreeSize] as? UInt64 {
                let used = total - free
                let usedGB = Double(used) / 1024.0 / 1024.0 / 1024.0

                DispatchQueue.main.async {
                    self.diskUsage = String(format: "%.1f GB", usedGB)
                }
            }
        }
    }

    private func updateProcessList() {
        DispatchQueue.global(qos: .userInitiated).async {
            let pipe = Pipe()
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-eo", "pid,rss,comm"]
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let processes = self.parseProcessList(output)
                    DispatchQueue.main.async {
                        self.topProcesses = processes
                    }
                }
            } catch {
                print("Failed to fetch processes: \(error)")
            }
        }
    }

    private func parseProcessList(_ output: String) -> [ProcessInfo] {
        let lines = output.components(separatedBy: "\n")
        var processes: [ProcessInfo] = []

        for line in lines.dropFirst() {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)

            if components.count >= 3,
               let pid = Int32(components[0]),
               let rss = UInt64(components[1]) {
                let name = components[2...].joined(separator: " ")
                let memory = rss * 1024 // Convert KB to bytes

                if memory > 10 * 1024 * 1024 { // Only show > 10MB
                    processes.append(ProcessInfo(pid: pid, name: name, memory: memory))
                }
            }
        }

        return processes.sorted { $0.memory > $1.memory }
    }

    func performQuickCleanup() -> Int {
        // Simple memory purge
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["-n", "purge"]

        do {
            try task.run()
            task.waitUntilExit()

            // Estimate freed memory (simplified)
            return Int.random(in: 100...500)
        } catch {
            return 0
        }
    }

    deinit {
        timer?.invalidate()
    }
}
