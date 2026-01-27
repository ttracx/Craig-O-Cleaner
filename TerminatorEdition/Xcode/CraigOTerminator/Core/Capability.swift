//
//  Capability.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

// MARK: - Privilege Level

/// Privilege level required for command execution
enum PrivilegeLevel: String, Codable {
    case user           // No elevation needed
    case elevated       // Requires Authorization Services
    case automation     // Requires Apple Events permission
    case fullDiskAccess // Optional, enhances functionality
}

// MARK: - Risk Class

/// Risk classification for UI flow
enum RiskClass: String, Codable {
    case safe           // No confirmation, instant execute
    case moderate       // Single confirmation
    case destructive    // Confirm + dry-run preview required
}

// MARK: - Capability Group

/// UI grouping for menu organization
enum CapabilityGroup: String, Codable, CaseIterable {
    case diagnostics = "diagnostics"
    case quickClean = "quickClean"
    case deepClean = "deepClean"
    case browsers = "browsers"
    case disk = "disk"
    case memory = "memory"
    case devTools = "devTools"
    case system = "system"

    /// Display title for UI
    var displayTitle: String {
        switch self {
        case .diagnostics: return "Diagnostics"
        case .quickClean: return "Quick Clean"
        case .deepClean: return "Deep Clean"
        case .browsers: return "Browser Management"
        case .disk: return "Disk Utilities"
        case .memory: return "Memory Management"
        case .devTools: return "Developer Tools"
        case .system: return "System Utilities"
        }
    }

    /// SF Symbol icon for group
    var icon: String {
        switch self {
        case .diagnostics: return "stethoscope"
        case .quickClean: return "sparkles"
        case .deepClean: return "paintbrush"
        case .browsers: return "safari"
        case .disk: return "internaldrive"
        case .memory: return "memorychip"
        case .devTools: return "hammer"
        case .system: return "gearshape.2"
        }
    }
}

// MARK: - Output Parser

/// Output parsing strategy
enum OutputParser: String, Codable {
    case text           // Raw text display
    case json           // Parse as JSON
    case regex          // Apply pattern extraction
    case table          // Parse tabular output
    case memoryPressure // Special: memory_pressure format
    case diskUsage      // Special: df/du format
    case processTable   // Special: ps aux format
}

// MARK: - Preflight Check

/// Preflight validation rules
struct PreflightCheck: Codable, Equatable {
    enum CheckType: String, Codable {
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

/// Complete capability definition
struct Capability: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let group: CapabilityGroup

    // MARK: Execution
    let commandTemplate: String
    let arguments: [String]
    let workingDirectory: String?
    let timeout: TimeInterval

    // MARK: Security
    let privilegeLevel: PrivilegeLevel
    let riskClass: RiskClass

    // MARK: Parsing
    let outputParser: OutputParser
    let parserPattern: String?

    // MARK: Preflight
    let preflightChecks: [PreflightCheck]
    let requiredPaths: [String]
    let requiredApps: [String]

    // MARK: UI
    let icon: String
    let rollbackNotes: String?
    let estimatedDuration: TimeInterval?

    // MARK: - Equatable
    static func == (lhs: Capability, rhs: Capability) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Catalog Schema

/// Root structure of catalog.json
struct CapabilityCatalogSchema: Codable {
    let version: String
    let lastUpdated: String
    let author: String
    let schema: SchemaDefinition
    let capabilities: [Capability]
}

/// Schema validation metadata
struct SchemaDefinition: Codable {
    let privilegeLevels: [String]
    let riskClasses: [String]
    let groups: [String]
    let outputParsers: [String]
}
