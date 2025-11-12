//
//  MemoryManager.swift
//  Craig-O-Clean
//
//  Service for executing memory management commands
//

import Foundation

class MemoryManager: ObservableObject {
    @Published var isPurging: Bool = false
    @Published var lastPurgeTime: Date?
    @Published var purgeStatus: String = ""
    
    func executePurge(completion: @escaping (Bool, String) -> Void) {
        guard !isPurging else {
            completion(false, "Purge already in progress")
            return
        }
        
        DispatchQueue.main.async {
            self.isPurging = true
            self.purgeStatus = "Purging memory..."
        }
        
        // Execute sync && sudo purge
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.runPurgeCommand()
            
            DispatchQueue.main.async {
                self.isPurging = false
                if result.success {
                    self.lastPurgeTime = Date()
                    self.purgeStatus = "Memory purged successfully!"
                    completion(true, "Memory purged successfully!")
                } else {
                    self.purgeStatus = "Failed: \(result.message)"
                    completion(false, result.message)
                }
                
                // Clear status after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.purgeStatus = ""
                }
            }
        }
    }
    
    private func runPurgeCommand() -> (success: Bool, message: String) {
        // First, run sync
        let syncTask = Process()
        syncTask.executableURL = URL(fileURLWithPath: "/bin/sync")
        
        do {
            try syncTask.run()
            syncTask.waitUntilExit()
        } catch {
            return (false, "Failed to run sync: \(error.localizedDescription)")
        }
        
        // Then, run sudo purge
        // Note: This requires the user to have sudoers configured for passwordless purge
        // Or the app needs to be granted appropriate permissions
        let purgeTask = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        purgeTask.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        purgeTask.arguments = ["-n", "purge"] // -n means non-interactive (no password prompt)
        purgeTask.standardOutput = pipe
        purgeTask.standardError = errorPipe
        
        do {
            try purgeTask.run()
            purgeTask.waitUntilExit()
            
            if purgeTask.terminationStatus == 0 {
                return (true, "Memory purged successfully")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                
                if errorMessage.contains("password") || errorMessage.contains("sudo") {
                    return (false, "Sudo access required. Please configure sudoers for passwordless purge.")
                }
                return (false, "Purge failed: \(errorMessage)")
            }
        } catch {
            return (false, "Failed to execute purge: \(error.localizedDescription)")
        }
    }
    
    func checkSudoAccess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["-n", "true"]
            
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    completion(task.terminationStatus == 0)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
