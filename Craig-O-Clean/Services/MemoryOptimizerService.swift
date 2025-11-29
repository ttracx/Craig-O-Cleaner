// MemoryOptimizerService.swift
// ClearMind Control Center
//
// Service for managing memory cleanup and optimization
// Provides safe, user-guided cleanup workflows

import Foundation
import AppKit
import Combine

// MARK: - Cleanup Candidate Models

/// An app that is a candidate for cleanup
struct CleanupCandidate: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let pid: pid_t
    let memoryUsage: UInt64
    let lastActiveTime: Date?
    let isBackground: Bool
    let icon: NSImage?
    
    var memoryFormatted: String {
        let mb = Double(memoryUsage) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
    
    var isInactive: Bool {
        guard let lastActive = lastActiveTime else { return true }
        return Date().timeIntervalSince(lastActive) > 300 // 5 minutes
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CleanupCandidate, rhs: CleanupCandidate) -> Bool {
        lhs.id == rhs.id
    }
}

/// Cleanup suggestion with reason
struct CleanupSuggestion {
    let candidate: CleanupCandidate
    let reason: CleanupReason
    let priority: CleanupPriority
}

/// Reasons for suggesting cleanup
enum CleanupReason: String {
    case highMemory = "Using significant memory"
    case inactive = "Inactive for a while"
    case background = "Running in background"
    case duplicate = "Multiple instances running"
    case heavyBrowser = "Many browser tabs open"
}

/// Priority levels for cleanup
enum CleanupPriority: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    
    static func < (lhs: CleanupPriority, rhs: CleanupPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

/// Result of a cleanup operation
struct CleanupResult {
    let success: Bool
    let freedMemory: UInt64
    let appsTerminated: Int
    let errors: [String]
    
    var freedMemoryFormatted: String {
        let mb = Double(freedMemory) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}

/// Cleanup workflow step
enum CleanupStep: Int, CaseIterable {
    case analyze = 0
    case review = 1
    case confirm = 2
    case execute = 3
    case complete = 4
    
    var title: String {
        switch self {
        case .analyze: return "Analyzing"
        case .review: return "Review Suggestions"
        case .confirm: return "Confirm Cleanup"
        case .execute: return "Cleaning Up"
        case .complete: return "Complete"
        }
    }
    
    var description: String {
        switch self {
        case .analyze: return "Scanning running applications..."
        case .review: return "Review the suggested apps to close"
        case .confirm: return "Confirm your selections"
        case .execute: return "Closing selected applications..."
        case .complete: return "Memory cleanup complete!"
        }
    }
}

// MARK: - Memory Optimizer Service

/// Service for memory optimization and cleanup
@MainActor
class MemoryOptimizerService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var cleanupCandidates: [CleanupCandidate] = []
    @Published var suggestions: [CleanupSuggestion] = []
    @Published var selectedForCleanup: Set<String> = []
    @Published var currentStep: CleanupStep = .analyze
    @Published var isProcessing = false
    @Published var lastResult: CleanupResult?
    @Published var estimatedMemoryToFree: UInt64 = 0
    
    // MARK: - Private Properties
    
    private let protectedApps = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.WindowServer",
        "com.apple.systemuiserver"
    ]
    
    private let heavyMemoryThreshold: UInt64 = 500 * 1024 * 1024 // 500 MB
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Analysis
    
    /// Analyze running apps and generate cleanup suggestions
    func analyzeForCleanup() async {
        isProcessing = true
        currentStep = .analyze
        
        let runningApps = NSWorkspace.shared.runningApplications
        var candidates: [CleanupCandidate] = []
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  !protectedApps.contains(bundleId),
                  app.activationPolicy == .regular || app.activationPolicy == .accessory else {
                continue
            }
            
            let pid = app.processIdentifier
            let memoryUsage = getMemoryUsage(for: pid)
            
            // Skip apps using very little memory
            guard memoryUsage > 10 * 1024 * 1024 else { continue } // > 10 MB
            
            let candidate = CleanupCandidate(
                id: bundleId,
                name: app.localizedName ?? "Unknown",
                bundleIdentifier: bundleId,
                pid: pid,
                memoryUsage: memoryUsage,
                lastActiveTime: nil,
                isBackground: !app.isActive,
                icon: app.icon
            )
            
            candidates.append(candidate)
        }
        
        // Sort by memory usage
        cleanupCandidates = candidates.sorted { $0.memoryUsage > $1.memoryUsage }
        
        // Generate suggestions
        generateSuggestions()
        
        currentStep = .review
        isProcessing = false
    }
    
    /// Generate cleanup suggestions based on analysis
    private func generateSuggestions() {
        var newSuggestions: [CleanupSuggestion] = []
        
        for candidate in cleanupCandidates {
            var reason: CleanupReason?
            var priority: CleanupPriority = .low
            
            // High memory usage
            if candidate.memoryUsage > heavyMemoryThreshold {
                reason = .highMemory
                priority = .high
            }
            // Background apps
            else if candidate.isBackground {
                reason = .background
                priority = .medium
            }
            // Browsers with many resources
            else if isBrowser(candidate.bundleIdentifier) {
                reason = .heavyBrowser
                priority = .medium
            }
            
            if let reason = reason {
                newSuggestions.append(CleanupSuggestion(
                    candidate: candidate,
                    reason: reason,
                    priority: priority
                ))
            }
        }
        
        // Sort by priority
        suggestions = newSuggestions.sorted { $0.priority > $1.priority }
        
        // Auto-select high priority items
        selectedForCleanup = Set(suggestions.filter { $0.priority == .high }.map { $0.candidate.id })
        
        updateEstimatedMemory()
    }
    
    /// Update the estimated memory to be freed
    func updateEstimatedMemory() {
        estimatedMemoryToFree = cleanupCandidates
            .filter { selectedForCleanup.contains($0.id) }
            .reduce(0) { $0 + $1.memoryUsage }
    }
    
    var estimatedMemoryFormatted: String {
        let mb = Double(estimatedMemoryToFree) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
    
    // MARK: - Selection Management
    
    /// Toggle selection of a candidate
    func toggleSelection(_ candidate: CleanupCandidate) {
        if selectedForCleanup.contains(candidate.id) {
            selectedForCleanup.remove(candidate.id)
        } else {
            selectedForCleanup.insert(candidate.id)
        }
        updateEstimatedMemory()
    }
    
    /// Select all candidates
    func selectAll() {
        selectedForCleanup = Set(cleanupCandidates.map { $0.id })
        updateEstimatedMemory()
    }
    
    /// Deselect all candidates
    func deselectAll() {
        selectedForCleanup.removeAll()
        updateEstimatedMemory()
    }
    
    /// Select only suggested items
    func selectSuggested() {
        selectedForCleanup = Set(suggestions.map { $0.candidate.id })
        updateEstimatedMemory()
    }
    
    // MARK: - Cleanup Execution
    
    /// Proceed to confirmation step
    func proceedToConfirm() {
        guard !selectedForCleanup.isEmpty else { return }
        currentStep = .confirm
    }
    
    /// Go back to review step
    func backToReview() {
        currentStep = .review
    }
    
    /// Execute the cleanup
    func executeCleanup() async -> CleanupResult {
        isProcessing = true
        currentStep = .execute
        
        var freedMemory: UInt64 = 0
        var appsTerminated = 0
        var errors: [String] = []
        
        let appsToClose = cleanupCandidates.filter { selectedForCleanup.contains($0.id) }
        
        for candidate in appsToClose {
            // Find the running application
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == candidate.bundleIdentifier
            }) else {
                errors.append("Could not find \(candidate.name)")
                continue
            }
            
            let memoryBefore = candidate.memoryUsage
            
            // Try graceful termination first
            let terminated = app.terminate()
            
            if terminated {
                freedMemory += memoryBefore
                appsTerminated += 1
            } else {
                // Try force quit
                let forceQuit = app.forceTerminate()
                if forceQuit {
                    freedMemory += memoryBefore
                    appsTerminated += 1
                } else {
                    errors.append("Could not quit \(candidate.name)")
                }
            }
            
            // Small delay between terminations
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        
        let result = CleanupResult(
            success: errors.isEmpty,
            freedMemory: freedMemory,
            appsTerminated: appsTerminated,
            errors: errors
        )
        
        lastResult = result
        currentStep = .complete
        isProcessing = false
        
        return result
    }
    
    /// Reset the cleanup workflow
    func reset() {
        cleanupCandidates = []
        suggestions = []
        selectedForCleanup = []
        currentStep = .analyze
        lastResult = nil
        estimatedMemoryToFree = 0
    }
    
    // MARK: - Quick Cleanup
    
    /// Perform a quick cleanup of high-memory background apps
    func quickCleanup() async -> CleanupResult {
        await analyzeForCleanup()
        
        // Select only high-memory background apps
        selectedForCleanup = Set(
            cleanupCandidates
                .filter { $0.isBackground && $0.memoryUsage > heavyMemoryThreshold }
                .map { $0.id }
        )
        
        return await executeCleanup()
    }
    
    // MARK: - Advanced Options
    
    /// Run the system purge command (requires admin)
    func runPurge() async throws {
        let script = """
        do shell script "purge" with administrator privileges
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        
        _ = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = appleScript?.executeAndReturnError(&error)
                continuation.resume(returning: result)
            }
        }
        
        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw NSError(domain: "Purge", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage(for pid: pid_t) -> UInt64 {
        var taskInfo = proc_taskinfo()
        let taskSize = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(taskSize))
        
        if result == Int32(taskSize) {
            return UInt64(taskInfo.pti_resident_size)
        }
        return 0
    }
    
    private func isBrowser(_ bundleId: String) -> Bool {
        let browsers = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "org.mozilla.firefox",
            "company.thebrowser.Browser"
        ]
        return browsers.contains(bundleId)
    }
    
    // MARK: - Statistics
    
    var totalCandidatesMemory: UInt64 {
        cleanupCandidates.reduce(0) { $0 + $1.memoryUsage }
    }
    
    var totalCandidatesMemoryFormatted: String {
        let mb = Double(totalCandidatesMemory) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
    
    var selectedCount: Int {
        selectedForCleanup.count
    }
    
    var suggestionCount: Int {
        suggestions.count
    }
}
