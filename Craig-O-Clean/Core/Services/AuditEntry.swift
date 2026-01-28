// MARK: - AuditEntry.swift
// Craig-O-Clean - Audit Log Entry Model
// Defines the structure for audit log entries

import Foundation

/// Actions that can be logged in the audit trail
enum AuditAction: String, Codable, CaseIterable {
    // MARK: - Application Actions
    case appQuit = "app.quit"
    case appForceQuit = "app.force_quit"
    case appLaunched = "app.launched"

    // MARK: - Browser Actions
    case tabClosed = "browser.tab.closed"
    case tabsClosedByDomain = "browser.tabs.closed_by_domain"
    case tabsClosedAll = "browser.tabs.closed_all"
    case browserQuit = "browser.quit"
    case browserForceQuit = "browser.force_quit"

    // MARK: - Cleanup Actions
    case cleanupDryRun = "cleanup.dry_run"
    case cleanupStarted = "cleanup.started"
    case cleanupCompleted = "cleanup.completed"
    case cleanupCancelled = "cleanup.cancelled"
    case cleanupFailed = "cleanup.failed"
    case fileDeleted = "cleanup.file.deleted"
    case folderCleared = "cleanup.folder.cleared"

    // MARK: - Permission Actions
    case permissionRequested = "permission.requested"
    case permissionGranted = "permission.granted"
    case permissionDenied = "permission.denied"
    case permissionRevoked = "permission.revoked"

    // MARK: - Folder Authorization Actions
    case folderAuthorized = "folder.authorized"
    case folderRevoked = "folder.revoked"
    case folderAccessStarted = "folder.access.started"
    case folderAccessStopped = "folder.access.stopped"

    // MARK: - Settings Actions
    case settingChanged = "setting.changed"
    case featureEnabled = "feature.enabled"
    case featureDisabled = "feature.disabled"

    // MARK: - System Actions
    case appStarted = "system.app.started"
    case appTerminated = "system.app.terminated"
    case errorOccurred = "system.error"

    // MARK: - Properties

    var displayName: String {
        switch self {
        case .appQuit: return "App Quit"
        case .appForceQuit: return "App Force Quit"
        case .appLaunched: return "App Launched"
        case .tabClosed: return "Tab Closed"
        case .tabsClosedByDomain: return "Tabs Closed (Domain)"
        case .tabsClosedAll: return "All Tabs Closed"
        case .browserQuit: return "Browser Quit"
        case .browserForceQuit: return "Browser Force Quit"
        case .cleanupDryRun: return "Cleanup Preview"
        case .cleanupStarted: return "Cleanup Started"
        case .cleanupCompleted: return "Cleanup Completed"
        case .cleanupCancelled: return "Cleanup Cancelled"
        case .cleanupFailed: return "Cleanup Failed"
        case .fileDeleted: return "File Deleted"
        case .folderCleared: return "Folder Cleared"
        case .permissionRequested: return "Permission Requested"
        case .permissionGranted: return "Permission Granted"
        case .permissionDenied: return "Permission Denied"
        case .permissionRevoked: return "Permission Revoked"
        case .folderAuthorized: return "Folder Authorized"
        case .folderRevoked: return "Folder Access Revoked"
        case .folderAccessStarted: return "Folder Access Started"
        case .folderAccessStopped: return "Folder Access Stopped"
        case .settingChanged: return "Setting Changed"
        case .featureEnabled: return "Feature Enabled"
        case .featureDisabled: return "Feature Disabled"
        case .appStarted: return "App Started"
        case .appTerminated: return "App Terminated"
        case .errorOccurred: return "Error"
        }
    }

    var category: AuditCategory {
        switch self {
        case .appQuit, .appForceQuit, .appLaunched:
            return .application
        case .tabClosed, .tabsClosedByDomain, .tabsClosedAll, .browserQuit, .browserForceQuit:
            return .browser
        case .cleanupDryRun, .cleanupStarted, .cleanupCompleted, .cleanupCancelled, .cleanupFailed, .fileDeleted, .folderCleared:
            return .cleanup
        case .permissionRequested, .permissionGranted, .permissionDenied, .permissionRevoked:
            return .permission
        case .folderAuthorized, .folderRevoked, .folderAccessStarted, .folderAccessStopped:
            return .fileAccess
        case .settingChanged, .featureEnabled, .featureDisabled:
            return .settings
        case .appStarted, .appTerminated, .errorOccurred:
            return .system
        }
    }

    var iconName: String {
        switch self.category {
        case .application: return "app.badge"
        case .browser: return "safari"
        case .cleanup: return "trash"
        case .permission: return "lock.shield"
        case .fileAccess: return "folder.badge.gearshape"
        case .settings: return "gearshape"
        case .system: return "cpu"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .appForceQuit, .tabClosed, .tabsClosedByDomain, .tabsClosedAll,
             .cleanupStarted, .fileDeleted, .folderCleared, .folderRevoked:
            return true
        default:
            return false
        }
    }
}

/// Categories for grouping audit actions
enum AuditCategory: String, Codable, CaseIterable {
    case application
    case browser
    case cleanup
    case permission
    case fileAccess
    case settings
    case system

    var displayName: String {
        switch self {
        case .application: return "Applications"
        case .browser: return "Browser"
        case .cleanup: return "Cleanup"
        case .permission: return "Permissions"
        case .fileAccess: return "File Access"
        case .settings: return "Settings"
        case .system: return "System"
        }
    }
}

/// A single audit log entry
struct AuditEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let action: AuditAction
    let target: String
    let metadata: [String: String]
    let success: Bool
    let errorMessage: String?
    let sessionId: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: AuditAction,
        target: String,
        metadata: [String: String] = [:],
        success: Bool = true,
        errorMessage: String? = nil,
        sessionId: String = AuditEntry.currentSessionId
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.target = target
        self.metadata = metadata
        self.success = success
        self.errorMessage = errorMessage
        self.sessionId = sessionId
    }

    // MARK: - Session Management

    /// Current session ID (generated at app launch)
    static let currentSessionId: String = UUID().uuidString

    // MARK: - Convenience Properties

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    var summary: String {
        var parts = [action.displayName]
        if !target.isEmpty {
            parts.append(target)
        }
        return parts.joined(separator: ": ")
    }

    var detailDescription: String {
        var lines = [
            "Action: \(action.displayName)",
            "Target: \(target)",
            "Time: \(formattedTimestamp)",
            "Success: \(success ? "Yes" : "No")"
        ]

        if let error = errorMessage {
            lines.append("Error: \(error)")
        }

        if !metadata.isEmpty {
            lines.append("Details:")
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(key): \(value)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Equatable

    static func == (lhs: AuditEntry, rhs: AuditEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audit Entry Builders

extension AuditEntry {
    /// Create an entry for a successful operation
    static func success(
        _ action: AuditAction,
        target: String,
        metadata: [String: String] = [:]
    ) -> AuditEntry {
        AuditEntry(
            action: action,
            target: target,
            metadata: metadata,
            success: true
        )
    }

    /// Create an entry for a failed operation
    static func failure(
        _ action: AuditAction,
        target: String,
        error: Error,
        metadata: [String: String] = [:]
    ) -> AuditEntry {
        AuditEntry(
            action: action,
            target: target,
            metadata: metadata,
            success: false,
            errorMessage: error.localizedDescription
        )
    }

    /// Create an entry for a failed operation with custom message
    static func failure(
        _ action: AuditAction,
        target: String,
        errorMessage: String,
        metadata: [String: String] = [:]
    ) -> AuditEntry {
        AuditEntry(
            action: action,
            target: target,
            metadata: metadata,
            success: false,
            errorMessage: errorMessage
        )
    }
}

// MARK: - Export Format

/// Format for exporting audit logs
struct AuditLogExport: Codable {
    let exportDate: Date
    let appVersion: String
    let sessionId: String
    let entries: [AuditEntry]

    var filename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "craig-o-clean-audit-\(formatter.string(from: exportDate)).json"
    }
}
