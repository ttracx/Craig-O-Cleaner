import Foundation
import Combine

class ProcessManager: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var isRefreshing = false
    @Published var lastUpdateTime: Date?
    @Published var totalMemoryUsage: Double = 0 // in GB
    
    private var timer: Timer?
    
    init() {
        refreshProcesses()
        startAutoRefresh()
    }
    
    func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshProcesses()
        }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshProcesses() {
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let processes = self?.fetchProcesses() ?? []
            
            DispatchQueue.main.async {
                self?.processes = processes
                self?.isRefreshing = false
                self?.lastUpdateTime = Date()
                self?.calculateTotalMemory()
            }
        }
    }
    
    private func fetchProcesses() -> [ProcessInfo] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axm", "-o", "pid,rss,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            return parseProcessOutput(output)
        } catch {
            print("Error fetching processes: \(error)")
            return []
        }
    }
    
    private func parseProcessOutput(_ output: String) -> [ProcessInfo] {
        let lines = output.components(separatedBy: .newlines)
        var processDict: [Int: ProcessInfo] = [:]
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let components = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard components.count >= 3 else { continue }
            
            guard let pid = Int(components[0]),
                  let rssKB = Int(components[1]) else {
                continue
            }
            
            let memoryMB = Double(rssKB) / 1024.0
            let name = String(components[2])
            
            // Aggregate memory by process name (combining threads)
            if let existing = processDict[pid] {
                processDict[pid] = ProcessInfo(
                    pid: pid,
                    name: existing.name,
                    memoryUsage: existing.memoryUsage + memoryMB
                )
            } else {
                processDict[pid] = ProcessInfo(
                    pid: pid,
                    name: name,
                    memoryUsage: memoryMB
                )
            }
        }
        
        // Sort by memory usage and return top processes
        return Array(processDict.values)
            .filter { $0.memoryUsage > 10 } // Only show processes using more than 10 MB
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(50)
            .map { $0 }
    }
    
    private func calculateTotalMemory() {
        let totalMB = processes.reduce(0) { $0 + $1.memoryUsage }
        totalMemoryUsage = totalMB / 1024.0 // Convert to GB
    }
    
    func forceQuitProcess(pid: Int) {
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", String(pid)]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Refresh the process list after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshProcesses()
            }
        } catch {
            print("Error force quitting process: \(error)")
        }
    }
    
    func purgeMemory(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            var totalOperations = 0
            
            // Operation 1: Sync file system buffers
            totalOperations += 1
            do {
                let syncTask = Process()
                syncTask.launchPath = "/bin/sync"
                try syncTask.run()
                syncTask.waitUntilExit()
                if syncTask.terminationStatus == 0 {
                    successCount += 1
                }
            } catch {
                print("Sync failed: \(error)")
            }
            
            // Operation 2: Simulate memory pressure to force system to free memory
            totalOperations += 1
            do {
                let pressureTask = Process()
                pressureTask.launchPath = "/usr/bin/memory_pressure"
                pressureTask.arguments = ["-l", "critical", "-S", "1"]
                
                let pipe = Pipe()
                pressureTask.standardOutput = pipe
                pressureTask.standardError = pipe
                
                try pressureTask.run()
                pressureTask.waitUntilExit()
                if pressureTask.terminationStatus == 0 {
                    successCount += 1
                }
            } catch {
                print("Memory pressure failed: \(error)")
            }
            
            // Operation 3: Clear DNS cache (doesn't require root on recent macOS)
            totalOperations += 1
            do {
                let dnsTask = Process()
                dnsTask.launchPath = "/usr/bin/dscacheutil"
                dnsTask.arguments = ["-flushcache"]
                try dnsTask.run()
                dnsTask.waitUntilExit()
                if dnsTask.terminationStatus == 0 {
                    successCount += 1
                }
            } catch {
                print("DNS cache flush failed: \(error)")
            }
            
            // Give the system a moment to process
            Thread.sleep(forTimeInterval: 1.0)
            
            // Determine success based on how many operations succeeded
            let success = successCount >= 2
            let message: String
            
            if success {
                message = "Memory optimization completed successfully!\n\nThe system has freed up inactive memory and cleared caches. You should see improved performance."
            } else {
                message = "Memory optimization partially completed.\n\n\(successCount) of \(totalOperations) operations succeeded. Some memory may have been freed."
            }
            
            DispatchQueue.main.async {
                completion(success, message)
                // Refresh process list after purge
                self.refreshProcesses()
            }
        }
    }
    
    deinit {
        stopAutoRefresh()
    }
}
