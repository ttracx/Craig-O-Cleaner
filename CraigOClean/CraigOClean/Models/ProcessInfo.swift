//
//  ProcessInfo.swift
//  Craig-O-Clean
//
//  Model for storing process information
//

import Foundation

struct ProcessInfo: Identifiable, Hashable {
    let id: Int32 // PID
    let name: String
    let memoryUsageMB: Double
    
    var formattedMemory: String {
        if memoryUsageMB >= 1024 {
            return String(format: "%.2f GB", memoryUsageMB / 1024)
        } else {
            return String(format: "%.1f MB", memoryUsageMB)
        }
    }
}
