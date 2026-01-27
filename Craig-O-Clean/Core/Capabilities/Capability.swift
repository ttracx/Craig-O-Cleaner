// MARK: - Capability.swift
// Craig-O-Clean - Capability Model
// Defines the capability-based command execution model with privilege separation

import Foundation

// MARK: - Privilege Level

/// Privilege level required for command execution
enum PrivilegeLevel: String, Codable, Hashable {
    case user           // No elevation needed
    case elevated       // Requires Authorization Services
    case automation     // Requires Apple Events permission
    case fullDiskAccess // Optional, enhances functionality
}

// MARK: - Risk Classification

/// Risk classification determining UI confirmation flow
enum RiskClass: String, Codable, Hashable {
    case safe           // No confirmation, instant execute
    case moderate       // Single confirmation
    case destructive    // Confirm + dry-run preview required
}

// MARK: - Output Parser

/// Strategy for parsing command output
enum OutputParser: String, Codable, Hashable {
    case text           // Raw text display
    case json           // Parse as JSON
    case regex          // Apply pattern extraction
    case table          // Parse tabular output
    case memoryPressure // Special: memory_pressure format
    case diskUsage      // Special: df/du format
    case processTable   // Special: ps aux format
}

// MARK: - Capability Group

/// UI grouping for menu organization
enum CapabilityGroup: String, Codable, CaseIterable, Hashable {
    case diagnostics = "diagnostics"
    case quickClean  = "quickClean"
    case deepClean   = "deepClean"
    case browsers    = "browsers"
    case disk        = "disk"
    case memory      = "memory"
    case devTools    = "devTools"
    case system      = "system"

    var displayName: String {
        switch self {
        case .diagnostics: return "Diagnostics"
        case .quickClean:  return "Quick Clean"
        case .deepClean:   return "Deep Clean"
        case .browsers:    return "Browser Management"
        case .disk:        return "Disk Utilities"
        case .memory:      return "Memory Management"
        case .devTools:    return "Developer Tools"
        case .system:      return "System Utilities"
        }
    }

    var icon: String {
        switch self {
        case .diagnostics: return "stethoscope"
        case .quickClean:  return "bolt"
        case .deepClean:   return "trash"
        case .browsers:    return "globe"
        case .disk:        return "internaldrive"
        case .memory:      return "memorychip"
        case .devTools:    return "hammer"
        case .system:      return "gearshape.2"
        }
    }
}

// MARK: - Preflight Check

/// Validation rule that must pass before capability execution
struct PreflightCheck: Codable, Hashable {
    enum CheckType: String, Codable, Hashable {
        case pathExists
        case pathWritable
        case appRunning
        case appNotRunning
        case diskSpaceAvailable
        case sipStatus
        case automationPermission
    }

    let type: CheckType
    let target: String
    let failureMessage: String
}

// MARK: - Capability

/// Complete capability definition for a single executable action
struct Capability: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let group: CapabilityGroup

    // Execution
    let commandTemplate: String
    let arguments: [String]
    let workingDirectory: String?
    let timeout: TimeInterval

    // Security
    let privilegeLevel: PrivilegeLevel
    let riskClass: RiskClass

    // Parsing
    let outputParser: OutputParser
    let parserPattern: String?

    // Preflight
    let preflightChecks: [PreflightCheck]
    let requiredPaths: [String]
    let requiredApps: [String]

    // UI
    let icon: String
    let rollbackNotes: String?
    let estimatedDuration: TimeInterval?

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Capability, rhs: Capability) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Execution Types

/// Progress reported during capability execution
struct ExecutionProgress {
    let phase: ExecutionPhase
    let stdout: String?
    let stderr: String?
    let percentage: Double?
}

/// Execution lifecycle phases
enum ExecutionPhase: Equatable {
    case preparing
    case requestingPermission
    case executing
    case parsing
    case complete
    case failed(String)
    case cancelled
}

/// Result of a capability execution
struct ExecutionResult {
    let capabilityId: String
    let startTime: Date
    let endTime: Date
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let parsedOutput: ParsedOutput?
    let record: RunRecord
}

/// Parsed output from command execution
enum ParsedOutput {
    case text(String)
    case lines([String])
    case keyValue([String: String])
    case table(headers: [String], rows: [[String]])
    case json(Any)
    case memoryInfo(used: String, free: String, pressure: String)
    case diskInfo(total: String, used: String, free: String)
}

/// Result of preflight validation
struct PreflightResult {
    let canExecute: Bool
    let missingPermissions: [PermissionRequirement]
    let failedChecks: [PreflightCheck]
    let remediationSteps: [RemediationStep]
}

/// A specific permission requirement
struct PermissionRequirement {
    let type: PermissionType
    let target: String?
    let description: String
}

/// A step to remediate a permission issue
struct RemediationStep {
    let instruction: String
    let systemSettingsPath: String?
    let canOpenAutomatically: Bool
}

// MARK: - Execution Status

/// Status of a completed execution
enum ExecutionStatus: String, Codable {
    case success
    case partialSuccess
    case failed
    case cancelled
    case permissionDenied
    case timeout
}
