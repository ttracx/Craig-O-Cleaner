// MARK: - PermissionsService.swift
// Craig-O-Clean - Permissions Management Service
// Handles checking and requesting macOS permissions for Automation, Accessibility, Full Disk Access, etc.

import Foundation
import Combine
import AppKit
import os.log

// MARK: - Permission Types

enum PermissionType: String, CaseIterable, Identifiable {
    case automation = "Automation"
    case accessibility = "Accessibility"
    case fullDiskAccess = "Full Disk Access"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .automation:
            return "Control other apps like Safari and Chrome to manage browser tabs"
        case .accessibility:
            return "Access advanced system features and window management"
        case .fullDiskAccess:
            return "Read detailed process and system information"
        }
    }
    
    var icon: String {
        switch self {
        case .automation: return "gearshape.2"
        case .accessibility: return "accessibility"
        case .fullDiskAccess: return "externaldrive"
        }
    }
    
    var settingsPath: String {
        switch self {
        case .automation:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .fullDiskAccess:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }
    }
}

// MARK: - Permission Status

enum PermissionStatus: String {
    case granted = "Granted"
    case denied = "Denied"
    case notDetermined = "Not Determined"
    case restricted = "Restricted"
    
    var color: String {
        switch self {
        case .granted: return "green"
        case .denied: return "red"
        case .notDetermined: return "yellow"
        case .restricted: return "orange"
        }
    }
    
    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        case .restricted: return "lock.circle.fill"
        }
    }
}

// MARK: - Automation Target

struct AutomationTarget: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    var status: PermissionStatus
    
    static let safari = AutomationTarget(
        id: "safari",
        name: "Safari",
        bundleIdentifier: "com.apple.Safari",
        status: .notDetermined
    )
    
    static let chrome = AutomationTarget(
        id: "chrome",
        name: "Google Chrome",
        bundleIdentifier: "com.google.Chrome",
        status: .notDetermined
    )
    
    static let edge = AutomationTarget(
        id: "edge",
        name: "Microsoft Edge",
        bundleIdentifier: "com.microsoft.edgemac",
        status: .notDetermined
    )
    
    static let brave = AutomationTarget(
        id: "brave",
        name: "Brave Browser",
        bundleIdentifier: "com.brave.Browser",
        status: .notDetermined
    )
    
    static let arc = AutomationTarget(
        id: "arc",
        name: "Arc",
        bundleIdentifier: "company.thebrowser.Browser",
        status: .notDetermined
    )
    
    static let systemEvents = AutomationTarget(
        id: "systemEvents",
        name: "System Events",
        bundleIdentifier: "com.apple.systemevents",
        status: .notDetermined
    )
}

// MARK: - Permissions Service

@MainActor
final class PermissionsService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var accessibilityStatus: PermissionStatus = .notDetermined
    @Published private(set) var fullDiskAccessStatus: PermissionStatus = .notDetermined
    @Published private(set) var automationTargets: [AutomationTarget] = []
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckTime: Date?
    @Published var shouldShowPermissionsOnboarding: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.craigoclean.app", category: "Permissions")
    private var checkTimer: Timer?
    private let hasShownOnboarding = "hasShownPermissionsOnboarding"
    
    // MARK: - Computed Properties
    
    var hasRequiredPermissions: Bool {
        // At least one automation target should be granted for full functionality
        automationTargets.contains { $0.status == .granted }
    }

    var allAutomationGranted: Bool {
        automationTargets.allSatisfy { $0.status == .granted }
    }

    var hasAllCriticalPermissions: Bool {
        accessibilityStatus == .granted && fullDiskAccessStatus == .granted && hasRequiredPermissions
    }

    var missingCriticalPermissions: [PermissionType] {
        var missing: [PermissionType] = []
        if accessibilityStatus != .granted {
            missing.append(.accessibility)
        }
        if fullDiskAccessStatus != .granted {
            missing.append(.fullDiskAccess)
        }
        if !hasRequiredPermissions {
            missing.append(.automation)
        }
        return missing
    }
    
    // MARK: - Initialization
    
    init() {
        logger.info("PermissionsService initialized")
        setupAutomationTargets()

        // Check if we should show onboarding
        let hasShown = UserDefaults.standard.bool(forKey: hasShownOnboarding)
        shouldShowPermissionsOnboarding = !hasShown

        Task {
            await checkAllPermissions()

            // Auto-request permissions if this is first launch
            if shouldShowPermissionsOnboarding {
                await autoRequestPermissions()
            }
        }
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupAutomationTargets() {
        // Only add targets for installed browsers
        var targets: [AutomationTarget] = []
        
        let workspace = NSWorkspace.shared
        
        if workspace.urlForApplication(withBundleIdentifier: AutomationTarget.safari.bundleIdentifier) != nil {
            targets.append(.safari)
        }
        
        if workspace.urlForApplication(withBundleIdentifier: AutomationTarget.chrome.bundleIdentifier) != nil {
            targets.append(.chrome)
        }
        
        if workspace.urlForApplication(withBundleIdentifier: AutomationTarget.edge.bundleIdentifier) != nil {
            targets.append(.edge)
        }
        
        if workspace.urlForApplication(withBundleIdentifier: AutomationTarget.brave.bundleIdentifier) != nil {
            targets.append(.brave)
        }
        
        if workspace.urlForApplication(withBundleIdentifier: AutomationTarget.arc.bundleIdentifier) != nil {
            targets.append(.arc)
        }
        
        // System Events is always available
        targets.append(.systemEvents)
        
        automationTargets = targets
    }
    
    // MARK: - Public Methods
    
    /// Check all permissions
    func checkAllPermissions() async {
        isChecking = true

        // Check accessibility
        accessibilityStatus = checkAccessibilityPermission()

        // Check full disk access
        fullDiskAccessStatus = checkFullDiskAccessPermission()

        // Check automation for each target
        for i in automationTargets.indices {
            automationTargets[i].status = await checkAutomationPermission(for: automationTargets[i])
        }

        lastCheckTime = Date()
        isChecking = false

        logger.info("Permission check completed - Accessibility: \(self.accessibilityStatus.rawValue), Full Disk Access: \(self.fullDiskAccessStatus.rawValue)")
    }

    /// Auto-request all missing critical permissions
    func autoRequestPermissions() async {
        logger.info("Auto-requesting missing permissions...")

        // Request accessibility first
        if accessibilityStatus != .granted {
            logger.info("Requesting accessibility permission")
            requestAccessibilityPermission()
            try? await Task.sleep(for: .seconds(1))
        }

        // Full Disk Access must be manually enabled - we can only guide users
        if fullDiskAccessStatus != .granted {
            logger.info("Full Disk Access not granted - user must enable manually")
        }

        // Request automation for installed browsers
        for target in automationTargets where target.status != .granted {
            logger.info("Requesting automation permission for \(target.name)")
            requestAutomationPermission(for: target)
            try? await Task.sleep(for: .seconds(0.5))
        }
    }

    /// Mark onboarding as complete
    func completeOnboarding() {
        shouldShowPermissionsOnboarding = false
        UserDefaults.standard.set(true, forKey: hasShownOnboarding)
        logger.info("Permissions onboarding completed")
    }
    
    /// Check accessibility permission
    func checkAccessibilityPermission() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return trusted ? .granted : .denied
    }
    
    /// Request accessibility permission (opens System Settings)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Also open System Settings to the right place
        openSystemSettings(for: .accessibility)
    }

    /// Check Full Disk Access permission
    func checkFullDiskAccessPermission() -> PermissionStatus {
        // Try to access a protected location that requires Full Disk Access
        // For example, try to read Safari's history database
        let protectedPaths = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Safari/History.db"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/com.apple.sharedfilelist"),
        ]

        for path in protectedPaths {
            // Check if we can access file attributes (requires Full Disk Access)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path.path) {
                // Successfully accessed protected file
                if attributes[.type] != nil {
                    return .granted
                }
            }
        }

        // Also check if we can enumerate protected directories
        let protectedDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Mail")
        if let contents = try? FileManager.default.contentsOfDirectory(at: protectedDir, includingPropertiesForKeys: nil) {
            if !contents.isEmpty {
                return .granted
            }
        }

        return .denied
    }

    /// Request Full Disk Access permission (opens System Settings)
    func requestFullDiskAccessPermission() {
        // Can't programmatically request Full Disk Access, must guide user to System Settings
        openSystemSettings(for: .fullDiskAccess)
    }
    
    /// Check automation permission for a specific target
    func checkAutomationPermission(for target: AutomationTarget) async -> PermissionStatus {
        // We can't directly check automation permission without triggering a prompt
        // So we attempt a minimal AppleScript operation and check the result
        
        let script: String
        switch target.bundleIdentifier {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                return name
            end tell
            """
        case "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser":
            script = """
            tell application id "\(target.bundleIdentifier)"
                return name
            end tell
            """
        case "com.apple.systemevents":
            script = """
            tell application "System Events"
                return name
            end tell
            """
        default:
            return .notDetermined
        }
        
        // Only test if the app is running to avoid launching it
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == target.bundleIdentifier
        }
        
        // Special case for System Events - always try
        guard isRunning || target.bundleIdentifier == "com.apple.systemevents" else {
            return .notDetermined
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                    // -1743 is "Not authorized to send Apple events"
                    if errorNumber == -1743 {
                        continuation.resume(returning: .denied)
                    } else {
                        continuation.resume(returning: .notDetermined)
                    }
                } else {
                    continuation.resume(returning: .granted)
                }
            }
        }
    }
    
    /// Request automation permission for a specific target
    func requestAutomationPermission(for target: AutomationTarget) {
        // Trigger the permission prompt by attempting to use AppleScript
        let script = """
        tell application id "\(target.bundleIdentifier)"
            return name
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)
        }
        
        // Open System Settings to Automation
        openSystemSettings(for: .automation)
    }
    
    /// Open System Settings to a specific privacy section
    func openSystemSettings(for permission: PermissionType) {
        if let url = URL(string: permission.settingsPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Open System Settings to Privacy & Security
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Start periodic permission checks
    func startPeriodicCheck(interval: TimeInterval = 30.0) {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAllPermissions()
            }
        }
    }
    
    /// Stop periodic permission checks
    func stopPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    // MARK: - Helper Methods
    
    /// Get status summary for display
    func getStatusSummary() -> String {
        let granted = automationTargets.filter { $0.status == .granted }.count
        let total = automationTargets.count
        
        if granted == total {
            return "All permissions granted"
        } else if granted > 0 {
            return "\(granted) of \(total) automation permissions granted"
        } else {
            return "No automation permissions granted"
        }
    }
    
    /// Check if a specific browser has automation permission
    func hasAutomationPermission(for bundleIdentifier: String) -> Bool {
        automationTargets.first { $0.bundleIdentifier == bundleIdentifier }?.status == .granted
    }
}

// MARK: - Permission Instructions

extension PermissionsService {
    
    /// Get instructions for granting a permission
    func getInstructions(for permission: PermissionType) -> [String] {
        switch permission {
        case .automation:
            return [
                "Open System Settings",
                "Go to Privacy & Security → Automation",
                "Find Craig-O-Clean in the list",
                "Enable access for each browser you want to manage",
                "If the app isn't listed, try using a browser feature first"
            ]
        case .accessibility:
            return [
                "Open System Settings",
                "Go to Privacy & Security → Accessibility",
                "Click the lock icon to make changes",
                "Enable Craig-O-Clean",
                "You may need to restart the app"
            ]
        case .fullDiskAccess:
            return [
                "Open System Settings",
                "Go to Privacy & Security → Full Disk Access",
                "Click the lock icon to make changes",
                "Click '+' and add Craig-O-Clean",
                "Restart the app for changes to take effect"
            ]
        }
    }
}
