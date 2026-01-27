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
    private var appActivationObserver: NSObjectProtocol?
    private let hasShownOnboarding = "hasShownPermissionsOnboarding"

    // Permission manager for auto-enablement
    let permissionManager = BrowserPermissionManager()
    
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
        setupAppActivationObserver()

        // Check if we should show onboarding
        let hasShown = UserDefaults.standard.bool(forKey: hasShownOnboarding)
        shouldShowPermissionsOnboarding = !hasShown

        Task {
            await checkAllPermissions()

            // Note: Disabled auto-request to prevent System Settings from opening on launch
            // User can manually grant permissions from the Settings view
            // if shouldShowPermissionsOnboarding {
            //     await autoRequestPermissions()
            // }
        }
        
        // Start periodic checks for permission changes
        startPeriodicCheck(interval: 5.0)
    }
    
    deinit {
        checkTimer?.invalidate()
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - App Activation Observer
    
    private func setupAppActivationObserver() {
        // Re-check permissions when app becomes active (user returns from System Settings)
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("App became active, refreshing permissions")
                await self?.checkAllPermissions()
            }
        }
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
            let previousStatus = automationTargets[i].status
            let newStatus = await checkAutomationPermission(for: automationTargets[i])
            automationTargets[i].status = newStatus

            // Report status changes to permission manager
            let isGranted = newStatus == .granted
            permissionManager.updatePermissionState(
                bundleIdentifier: automationTargets[i].bundleIdentifier,
                browserName: automationTargets[i].name,
                isGranted: isGranted
            )

            // Log status changes
            if previousStatus != newStatus {
                logger.info("Permission status changed for \(self.automationTargets[i].name): \(previousStatus.rawValue) → \(newStatus.rawValue)")
            }
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
        // Log app info for debugging
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let executablePath = Bundle.main.executablePath ?? "unknown"

        // First try the standard check without prompting
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        logger.info("Accessibility check - Bundle: \(bundleID), Path: \(executablePath), Trusted: \(trusted)")

        if trusted {
            logger.info("Accessibility permission: GRANTED")
            return .granted
        }

        // Also try the simpler AXIsProcessTrusted() as a fallback
        let simpleTrusted = AXIsProcessTrusted()
        logger.info("Accessibility fallback check - AXIsProcessTrusted: \(simpleTrusted)")

        if simpleTrusted {
            logger.info("Accessibility permission: GRANTED (via fallback)")
            return .granted
        }

        logger.warning("Accessibility permission: DENIED or NOT DETERMINED")
        return .denied
    }
    
    /// Request accessibility permission (opens System Settings)
    func requestAccessibilityPermission() {
        logger.info("Requesting Accessibility permission - will trigger system prompt and open Settings")

        // First trigger the system prompt - this will add the app to the TCC database
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Force the system to register our app by attempting an actual accessibility API call
        // This ensures the app appears in System Settings even if permission is denied
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Try to get the list of running applications using Accessibility API
            // This will fail if permission is not granted, but it forces macOS to add us to the list
            let systemWideElement = AXUIElementCreateSystemWide()
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                systemWideElement,
                kAXFocusedApplicationAttribute as CFString,
                &value
            )

            if result == .success {
                self?.logger.info("Accessibility API call successful - app should appear in Settings")
            } else {
                self?.logger.info("Accessibility API call failed (expected if permission not granted) - app registered with system")
            }

            // Open System Settings to the Accessibility pane
            // This ensures the user is taken directly to where they need to grant permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openSystemSettings(for: .accessibility)
            }
        }
    }

    /// Check Full Disk Access permission
    func checkFullDiskAccessPermission() -> PermissionStatus {
        // Try multiple methods to detect Full Disk Access

        // Method 1: Try to access Safari's history database (most reliable if it exists)
        let safariHistoryPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Safari/History.db")

        if FileManager.default.fileExists(atPath: safariHistoryPath.path) {
            // File exists, try to read attributes
            if let attributes = try? FileManager.default.attributesOfItem(atPath: safariHistoryPath.path),
               attributes[.type] != nil {
                logger.info("Full Disk Access granted: Safari history accessible")
                return .granted
            }
        }

        // Method 2: Try to access Mail directory (widely present)
        let mailDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mail")

        if FileManager.default.fileExists(atPath: mailDir.path) {
            // Directory exists, try to enumerate contents
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: mailDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) {
                // If we can read any contents, we have Full Disk Access
                if !contents.isEmpty {
                    logger.info("Full Disk Access granted: Mail directory accessible")
                    return .granted
                }
            }
        }

        // Method 3: Try to read from /Library/Application Support (system-wide protected location)
        let appSupportPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/com.apple.TCC")

        if FileManager.default.fileExists(atPath: appSupportPath.path) {
            if let _ = try? FileManager.default.contentsOfDirectory(
                at: appSupportPath,
                includingPropertiesForKeys: nil,
                options: []
            ) {
                logger.info("Full Disk Access granted: TCC directory accessible")
                return .granted
            }
        }

        // Method 4: Check if we can access the TCC database itself (most reliable indicator)
        let tccDbPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        if FileManager.default.isReadableFile(atPath: tccDbPath) {
            logger.info("Full Disk Access granted: TCC database readable")
            return .granted
        }

        // Method 5: Try accessing user's Desktop (less protected but still requires some access)
        let desktopPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop")

        // Check if we can enumerate Desktop - if we can't even do this, definitely no Full Disk Access
        if FileManager.default.fileExists(atPath: desktopPath.path) {
            if let _ = try? FileManager.default.contentsOfDirectory(
                at: desktopPath,
                includingPropertiesForKeys: nil,
                options: []
            ) {
                // We can access Desktop, but couldn't access more protected locations
                // This suggests limited access, not Full Disk Access
                logger.info("Full Disk Access denied: Can access Desktop but not protected locations")
                return .denied
            }
        }

        // If we reached here, we couldn't verify Full Disk Access
        logger.warning("Full Disk Access check inconclusive, defaulting to denied")
        return .denied
    }

    /// Request Full Disk Access permission (opens System Settings)
    func requestFullDiskAccessPermission() {
        // Can't programmatically request Full Disk Access, must guide user to System Settings
        // Note: Only open when user explicitly clicks "Grant" button
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
            // If browser isn't running, check persisted permission state
            if permissionManager.hasGrantedPermission(bundleIdentifier: target.bundleIdentifier) {
                logger.debug("\(target.name) not running, using persisted permission state: granted")
                return .granted
            }
            logger.debug("\(target.name) not running, no persisted state available")
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
        logger.info("Requesting automation permission for \(target.name) - will add Craig-O-Clean to Automation list")

        // Check if target app is running - if not, try to launch it briefly
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == target.bundleIdentifier
        }

        if !isRunning {
            logger.info("\(target.name) is not running - attempting to launch for permission request")
            // Try to launch the app to ensure it's available for the permission request
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                NSWorkspace.shared.open(appURL, configuration: configuration) { _, _ in }
                // Give the app a moment to launch
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // Trigger the permission prompt by attempting to use AppleScript
        // This will automatically add Craig-O-Clean to the Automation permissions list
        let script = """
        tell application id "\(target.bundleIdentifier)"
            try
                return name
            on error errMsg
                return "Permission request sent"
            end try
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(&error)

            if let error = error {
                let errorCode = error[NSAppleScript.errorNumber] as? Int ?? 0
                if errorCode == -1743 {
                    // -1743 means "not authorized" - this is expected and means the prompt was shown
                    self.logger.info("Permission prompt triggered for \(target.name) - app added to Automation list")
                } else {
                    self.logger.warning("AppleScript error \(errorCode) for \(target.name): \(error[NSAppleScript.errorMessage] as? String ?? "unknown")")
                }
            } else if let result = result {
                self.logger.info("AppleScript succeeded for \(target.name): \(result.stringValue ?? "no result")")
            }

            // After triggering the prompt, open System Settings to Automation pane
            // User can now see Craig-O-Clean in the list and toggle it on
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSystemSettings(for: .automation)
            }
        }
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
