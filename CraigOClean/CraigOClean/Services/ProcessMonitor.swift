//
//  ProcessMonitor.swift
//  Craig-O-Clean
//
//  Service for monitoring running processes and their memory usage
//

import Foundation
import Combine

class ProcessMonitor: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var totalMemoryUsageGB: Double = 0.0
    @Published var availableMemoryGB: Double = 0.0
    @Published var totalMemoryGB: Double = 0.0
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        updateProcessList()
        updateSystemMemory()
        
        // Update every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateProcessList()
            self?.updateSystemMemory()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateProcessList() {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-arcwwwxo", "pid,rss,comm"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseProcessOutput(output)
            }
        } catch {
            print("Error running ps command: \(error)")
        }
    }
    
    private func parseProcessOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        var processInfoArray: [ProcessInfo] = []
        
        for line in lines.dropFirst() { // Skip header
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
            
            guard components.count >= 3,
                  let pid = Int32(components[0]),
                  let rssKB = Double(components[1]) else {
                continue
            }
            
            let name = components[2...].joined(separator: " ")
            let memoryMB = rssKB / 1024.0
            
            // Only include processes using more than 10MB
            if memoryMB > 10 {
                let info = ProcessInfo(id: pid, name: name, memoryUsageMB: memoryMB)
                processInfoArray.append(info)
            }
        }
        
        // Sort by memory usage (highest first) and take top 20
        DispatchQueue.main.async {
            self.processes = processInfoArray
                .sorted { $0.memoryUsageMB > $1.memoryUsageMB }
                .prefix(20)
                .map { $0 }
        }
    }
    
    func updateSystemMemory() {
        // Get total physical memory
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0 // Convert to GB
        
        // Get available memory using vm_stat
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseVMStat(output, physicalMemory: physicalMemory)
            }
        } catch {
            print("Error running vm_stat: \(error)")
        }
    }
    
    private func parseVMStat(_ output: String, physicalMemory: Double) {
        let lines = output.components(separatedBy: .newlines)
        var pageSize: Double = 4096 // Default page size
        var freePages: Double = 0
        var inactivePages: Double = 0
        
        for line in lines {
            if line.contains("page size of") {
                let components = line.components(separatedBy: .whitespaces)
                if let size = components.first(where: { Int($0) != nil }) {
                    pageSize = Double(size) ?? 4096
                }
            } else if line.contains("Pages free:") {
                freePages = extractPageCount(from: line)
            } else if line.contains("Pages inactive:") {
                inactivePages = extractPageCount(from: line)
            }
        }
        
        let availableBytes = (freePages + inactivePages) * pageSize
        let availableGB = availableBytes / 1_073_741_824.0
        let usedGB = physicalMemory - availableGB
        
        DispatchQueue.main.async {
            self.totalMemoryGB = physicalMemory
            self.availableMemoryGB = availableGB
            self.totalMemoryUsageGB = usedGB
        }
    }
    
    private func extractPageCount(from line: String) -> Double {
        let components = line.components(separatedBy: .whitespaces)
        if let countStr = components.last?.replacingOccurrences(of: ".", with: ""),
           let count = Double(countStr) {
            return count
        }
        return 0
    }
    
    func forceQuitProcess(_ process: ProcessInfo) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/kill")
        task.arguments = ["-9", "\(process.id)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Refresh the process list after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateProcessList()
            }
        } catch {
            print("Error killing process: \(error)")
        }
    }
}
