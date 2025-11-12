import Foundation

struct ProcessInfo: Identifiable, Hashable {
    let id = UUID()
    let pid: Int
    let name: String
    let memoryUsage: Double // in MB
    
    var formattedMemory: String {
        if memoryUsage >= 1024 {
            return String(format: "%.2f GB", memoryUsage / 1024)
        } else {
            return String(format: "%.2f MB", memoryUsage)
        }
    }
}
