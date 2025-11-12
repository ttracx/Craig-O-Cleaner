import Foundation
import Combine

class SystemMemoryManager: ObservableObject {
    @Published var totalMemory: Double = 0 // in GB
    @Published var usedMemory: Double = 0 // in GB
    @Published var availableMemory: Double = 0 // in GB
    @Published var memoryPressure: String = "Normal"
    @Published var memoryPercentage: Double = 0 // percentage used
    
    func refreshMemoryInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchSystemMemory()
        }
    }
    
    private func fetchSystemMemory() {
        // Get physical memory
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        
        // Get memory statistics using vm_stat
        let task = Process()
        task.launchPath = "/usr/bin/vm_stat"
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return
            }
            
            parseVMStat(output, totalPhysicalMemory: physicalMemory)
        } catch {
            print("Error fetching memory stats: \(error)")
        }
    }
    
    private func parseVMStat(_ output: String, totalPhysicalMemory: Double) {
        let lines = output.components(separatedBy: .newlines)
        var pageSize: Int = 4096 // default page size
        var freePages: Int = 0
        var activePages: Int = 0
        var inactivePages: Int = 0
        var wiredPages: Int = 0
        var compressedPages: Int = 0
        
        for line in lines {
            if line.contains("page size of") {
                let components = line.components(separatedBy: " ")
                if let pageSizeIndex = components.firstIndex(where: { $0 == "of" }),
                   pageSizeIndex + 1 < components.count,
                   let size = Int(components[pageSizeIndex + 1]) {
                    pageSize = size
                }
            } else if line.contains("Pages free:") {
                freePages = extractNumber(from: line)
            } else if line.contains("Pages active:") {
                activePages = extractNumber(from: line)
            } else if line.contains("Pages inactive:") {
                inactivePages = extractNumber(from: line)
            } else if line.contains("Pages wired down:") {
                wiredPages = extractNumber(from: line)
            } else if line.contains("Pages occupied by compressor:") {
                compressedPages = extractNumber(from: line)
            }
        }
        
        // Calculate memory in GB
        let bytesPerGB = 1024.0 * 1024.0 * 1024.0
        let freeMemory = Double(freePages * pageSize) / bytesPerGB
        let activeMemory = Double(activePages * pageSize) / bytesPerGB
        let inactiveMemory = Double(inactivePages * pageSize) / bytesPerGB
        let wiredMemory = Double(wiredPages * pageSize) / bytesPerGB
        let compressedMemory = Double(compressedPages * pageSize) / bytesPerGB
        
        let usedMem = activeMemory + inactiveMemory + wiredMemory + compressedMemory
        let availableMem = freeMemory + inactiveMemory
        let percentage = (usedMem / totalPhysicalMemory) * 100
        
        // Determine memory pressure
        let pressure: String
        if percentage < 50 {
            pressure = "Normal"
        } else if percentage < 75 {
            pressure = "Moderate"
        } else {
            pressure = "High"
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.totalMemory = totalPhysicalMemory
            self?.usedMemory = usedMem
            self?.availableMemory = availableMem
            self?.memoryPercentage = percentage
            self?.memoryPressure = pressure
        }
    }
    
    private func extractNumber(from line: String) -> Int {
        let components = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let number = Int(component), number > 0 {
                return number
            }
        }
        return 0
    }
}

