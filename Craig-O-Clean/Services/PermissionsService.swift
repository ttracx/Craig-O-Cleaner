// PermissionsService.swift
// ClearMind Control Center
//
// Service for managing app permissions and security settings
// Provides status checking and guidance for users to enable required permissions

import Foundation
import AppKit
import Combine

// MARK: - Permission Types

/// Types of permissions the app may request
enum PermissionType: String, CaseIterable, Identifiable {
    case automation = "Automation"
    case accessibility = "Accessibility"
    case fullDiskAccess = "Full Disk Access"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .automation:
            return "Required to manage browser tabs and control other applications"
        case .accessibility:
            return "Required for advanced system monitoring features"
        case .fullDiskAccess:
            return "Required for complete process information access"
        }
    }
    
    var systemSettingsPath: String {
        switch self {
        case .automation:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .fullDiskAccess:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }
    }
    
    var icon: String {
        switch self {
        case .automation:
            return "gearshape.2"
        case .accessibility:
            return "accessibility"
        case .fullDiskAccess:
            return "externaldrive.fill"
        }
    }
    
    var importance: PermissionImportance {
        switch self {
        case .automation:
            return .required
        case .accessibility:
            return .optional
        case .fullDiskAccess:
            return .optional
        }
    }
}

/// Importance level for permissions
enum PermissionImportance: String {
    case required = "Required"
    case recommended = "Recommended"
    case optional = "Optional"
    
    var color: String {
        switch self {
        case .required: return "red"
        case .recommended: return "orange"
        case .optional: return "blue"
        }
    }
}

/// Status of a permission
enum PermissionStatus: String {
    case granted = "Granted"
    case denied = "Denied"
    case unknown = "Unknown"
    case notDetermined = "Not Determined"
    
    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .unknown, .notDetermined: return "questionmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .granted: return "green"
        case .denied: return "red"
        case .unknown, .notDetermined: return "orange"
        }
    }
}

/// Model for permission information
struct PermissionInfo: Identifiable {
    let id: PermissionType
    var status: PermissionStatus
    let description: String
    let importance: PermissionImportance
    var lastChecked: Date?
    
    var type: PermissionType { id }
}

/// Automation permission detail for specific apps
struct AutomationPermissionDetail: Identifiable {
    let id: String
    let appName: String
    let bundleIdentifier: String
    var status: PermissionStatus
    
    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return app.icon
        }
        return NSWorkspace.shared.icon(forFile: "/Applications/\(appName).app")
    }
}

// MARK: - Permissions Service

/// Service for checking and managing app permissions
@MainActor
class PermissionsService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var permissions: [PermissionInfo] = []
    @Published var automationPermissions: [AutomationPermissionDetail] = []
    @Published var isChecking = false
    @Published var lastCheckTime: Date?
    
    // MARK: - Apps that require automation permission
    
    private let automationTargetApps = [
        ("Safari", "com.apple.Safari"),
        ("Google Chrome", "com.google.Chrome"),
        ("Microsoft Edge", "com.microsoft.edgemac"),
        ("Brave Browser", "com.brave.Browser"),
        ("Arc", "company.thebrowser.Browser"),
        ("System Events", "com.apple.systemevents")
    ]
    
    // MARK: - Initialization
    
    init() {
        initializePermissions()
        Task {
            await checkAllPermissions()
        }
    }
    
    private func initializePermissions() {
        permissions = PermissionType.allCases.map { type in
            PermissionInfo(
                id: type,
                status: .unknown,
                description: type.description,
                importance: type.importance,
                lastChecked: nil
            )
        }
        
        automationPermissions = automationTargetApps.map { (name, bundleId) in
            AutomationPermissionDetail(
                id: bundleId,
                appName: name,
                bundleIdentifier: bundleId,
                status: .unknown
            )
        }
    }
    
    // MARK: - Permission Checking
    
    /// Check all permissions
    func checkAllPermissions() async {
        isChecking = true
        
        // Check automation permissions for each target app
        await checkAutomationPermissions()
        
        // Update general permission status based on automation checks
        updatePermissionStatus(for: .automation)
        
        // Check accessibility
        await checkAccessibilityPermission()
        
        lastCheckTime = Date()
        isChecking = false
    }
    
    /// Check automation permissions for target apps
    private func checkAutomationPermissions() async {
        for i in 0..<automationPermissions.count {
            let detail = automationPermissions[i]
            let status = await checkAutomationPermission(for: detail.appName)
            automationPermissions[i].status = status
        }
    }
    
    /// Check automation permission for a specific app
    private func checkAutomationPermission(for appName: String) async -> PermissionStatus {
        // Skip if the app isn't installed
        let appPath = "/Applications/\(appName).app"
        guard FileManager.default.fileExists(atPath: appPath) || appName == "System Events" else {
            return .unknown
        }
        
        let script = """
        tell application "\(appName)"
            return "test"
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                _ = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                    // -1743 = not authorized
                    if errorNumber == -1743 {
                        continuation.resume(returning: .denied)
                    } else {
                        continuation.resume(returning: .unknown)
                    }
                } else {
                    continuation.resume(returning: .granted)
                }
            }
        }
    }
    
    /// Update general permission status
    private func updatePermissionStatus(for type: PermissionType) {
        guard let index = permissions.firstIndex(where: { $0.id == type }) else { return }
        
        switch type {
        case .automation:
            // Automation is granted if at least one browser is accessible
            let grantedCount = automationPermissions.filter { $0.status == .granted }.count
            let installedCount = automationPermissions.filter { $0.status != .unknown }.count
            
            if grantedCount == installedCount && installedCount > 0 {
                permissions[index].status = .granted
            } else if grantedCount > 0 {
                permissions[index].status = .granted // Partial, but functional
            } else {
                permissions[index].status = .denied
            }
            
        case .accessibility:
            // Handled separately
            break
            
        case .fullDiskAccess:
            // Check by trying to access a protected location
            let protectedPath = "/Library/Application Support/com.apple.TCC/TCC.db"
            permissions[index].status = FileManager.default.isReadableFile(atPath: protectedPath) ? .granted : .denied
        }
        
        permissions[index].lastChecked = Date()
    }
    
    /// Check accessibility permission
    private func checkAccessibilityPermission() async {
        guard let index = permissions.firstIndex(where: { $0.id == .accessibility }) else { return }
        
        // Use AXIsProcessTrusted() to check accessibility
        let isTrusted = AXIsProcessTrusted()
        permissions[index].status = isTrusted ? .granted : .denied
        permissions[index].lastChecked = Date()
    }
    
    // MARK: - Permission Actions
    
    /// Open System Settings for a specific permission
    func openSettings(for permission: PermissionType) {
        if let url = URL(string: permission.systemSettingsPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Open System Settings for automation
    func openAutomationSettings() {
        openSettings(for: .automation)
    }
    
    /// Request accessibility permission
    func requestAccessibilityPermission() {
        // This will prompt the user to grant accessibility permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }
    
    /// Open general security settings
    func openSecuritySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if all required permissions are granted
    var allRequiredPermissionsGranted: Bool {
        permissions.filter { $0.importance == .required }
            .allSatisfy { $0.status == .granted }
    }
    
    /// Get count of granted permissions
    var grantedPermissionsCount: Int {
        permissions.filter { $0.status == .granted }.count
    }
    
    /// Get count of denied permissions
    var deniedPermissionsCount: Int {
        permissions.filter { $0.status == .denied }.count
    }
    
    /// Get granted automation apps
    var grantedAutomationApps: [AutomationPermissionDetail] {
        automationPermissions.filter { $0.status == .granted }
    }
    
    /// Get denied automation apps
    var deniedAutomationApps: [AutomationPermissionDetail] {
        automationPermissions.filter { $0.status == .denied }
    }
}

// MARK: - Permission Instructions

extension PermissionsService {
    /// Get step-by-step instructions for enabling a permission
    func getInstructions(for permission: PermissionType) -> [String] {
        switch permission {
        case .automation:
            return [
                "Open System Settings",
                "Go to Privacy & Security → Automation",
                "Find 'ClearMind Control Center' in the list",
                "Enable the toggle for each browser you want to manage",
                "You may need to restart the app after granting permission"
            ]
        case .accessibility:
            return [
                "Open System Settings",
                "Go to Privacy & Security → Accessibility",
                "Click the lock icon to make changes",
                "Click '+' and add ClearMind Control Center",
                "Enable the toggle next to the app"
            ]
        case .fullDiskAccess:
            return [
                "Open System Settings",
                "Go to Privacy & Security → Full Disk Access",
                "Click the lock icon to make changes",
                "Click '+' and add ClearMind Control Center",
                "Enable the toggle next to the app",
                "Restart the app for changes to take effect"
            ]
        }
    }
}
