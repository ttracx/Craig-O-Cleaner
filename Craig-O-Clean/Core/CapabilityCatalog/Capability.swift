// MARK: - Capability.swift
// Craig-O-Clean - Capability Model
// Single source of truth for all allowed operations

import Foundation

// MARK: - Executor Type

enum ExecutorType: String, Codable {
    case process
    case appleEvents
    case helperXpc
}

// MARK: - Privilege Level

enum PrivilegeLevel: String, Codable {
    case user
    case elevated
}

// MARK: - Required Permission

enum RequiredPermission: String, Codable {
    case none
    case automationSafari = "automation(Safari)"
    case automationChrome = "automation(Google Chrome)"
    case automationEdge = "automation(Microsoft Edge)"
    case automationBrave = "automation(Brave Browser)"
    case automationArc = "automation(Arc)"
    case automationFirefox = "automation(Firefox)"
    case automationSystemEvents = "automation(System Events)"
    case fullDiskAccessOptional = "fullDiskAccessOptional"
    case accessibilityOptional = "accessibilityOptional"

    /// Returns the browser name if this is an automation permission
    var automationBrowserName: String? {
        switch self {
        case .automationSafari: return "Safari"
        case .automationChrome: return "Google Chrome"
        case .automationEdge: return "Microsoft Edge"
        case .automationBrave: return "Brave Browser"
        case .automationArc: return "Arc"
        case .automationFirefox: return "Firefox"
        case .automationSystemEvents: return "System Events"
        default: return nil
        }
    }
}

// MARK: - Risk Class

enum RiskClass: String, Codable {
    case safe
    case moderate
    case destructive
}

// MARK: - Capability Category

enum CapabilityCategory: String, Codable, CaseIterable {
    case diagnostics = "Diagnostics"
    case quickClean = "Quick Clean"
    case deepClean = "Deep Clean"
    case browsers = "Browsers"
    case disk = "Disk"
    case memory = "Memory"
    case devTools = "Dev Tools"
    case system = "System"
    case network = "Network"
}

// MARK: - Output Parsing Mode

enum OutputParsingMode: String, Codable {
    case none
    case regex
    case json
    case custom
}

// MARK: - Preflight Check

struct PreflightCheck: Codable, Equatable {
    let type: CheckType
    let value: String
    let message: String?

    enum CheckType: String, Codable {
        case pathExists
        case appRunning
        case appInstalled
        case minOSVersion
        case commandExists
        case sipNote
    }
}

// MARK: - UI Hints

struct UIHints: Codable, Equatable {
    let confirmText: String?
    let warningText: String?
    let estimatedTime: String?
    let closeAppsFirst: [String]?
}

// MARK: - Capability Model

struct Capability: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let category: CapabilityCategory
    let executorType: ExecutorType
    let commandTemplate: String?
    let args: [String]?
    let appleScript: String?
    let requiredPrivileges: PrivilegeLevel
    let requiredPermissions: [RequiredPermission]
    let riskClass: RiskClass
    let preflightChecks: [PreflightCheck]
    let dryRunSupport: Bool
    let dryRunVariant: String?
    let outputParsing: OutputParsingMode
    let rollbackNotes: String?
    let uiHints: UIHints?

    static func == (lhs: Capability, rhs: Capability) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Catalog Root

struct CapabilityCatalogData: Codable {
    let version: String
    let generatedAt: String
    let capabilities: [Capability]
}
