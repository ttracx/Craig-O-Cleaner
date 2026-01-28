// MARK: - SandboxPermissionsManager.swift
// Craig-O-Clean Sandbox Edition - Permission Management
// Handles TCC permissions for Accessibility, Automation, and File Access

import Foundation
import AppKit
import os.log

// MARK: - Permission Types

/// Types of permissions the app may request
enum SandboxPermissionType: String, CaseIterable, Identifiable {
    case accessibility = "Accessibility"
    case automationSafari = "Safari Automation"
    case automationChrome = "Chrome Automation"
    case automationEdge = "Edge Automation"
    case automationBrave = "Brave Automation"
    case automationArc = "Arc Automation"
    case automationSystemEvents = "System Events"

    var id: String { rawValue }

    var bundleIdentifier: String? {
        switch self {
        case .accessibility: return nil
        case .automationSafari: return "com.apple.Safari"
        case .automationChrome: return "com.google.Chrome"
        case .automationEdge: return "com.microsoft.edgemac"
        case .automationBrave: return "com.brave.Browser"
        case .automationArc: return "company.thebrowser.Browser"
        case .automationSystemEvents: return "com.apple.systemevents"
        }
    }

    var description: String {
        switch self {
        case .accessibility:
            return "Required for advanced window management and UI automation"
        case .automationSafari:
            return "View and manage Safari tabs and windows"
        case .automationChrome:
            return "View and manage Chrome tabs and windows"
        case .automationEdge:
            return "View and manage Microsoft Edge tabs and windows"
        case .automationBrave:
            return "View and manage Brave tabs and windows"
        case .automationArc:
            return "View and manage Arc tabs and windows"
        case .automationSystemEvents:
            return "Required for some system automation features"
        }
    }

    var systemSettingsPath: String {
        switch self {
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        default:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }
    }

    var icon: String {
        switch self {
        case .accessibility: return "hand.raised.fill"
        case .automationSafari: return "safari"
        case .automationChrome, .automationEdge, .automationBrave, .automationArc: return "globe"
        case .automationSystemEvents: return "gearshape.2"
        }
    }
}

/// Permission status
enum PermissionStatus: Equatable {
    case unknown
    case notDetermined
    case authorized
    case denied
    case restricted
    case notInstalled  // For browser automation when browser isn't installed

    var isGranted: Bool {
        return self == .authorized
    }

    var displayText: String {
        switch self {
        case .unknown: return "Unknown"
        case .notDetermined: return "Not Requested"
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notInstalled: return "App Not Installed"
        }
    }

    var statusColor: String {
        switch self {
        case .authorized: return "green"
        case .denied, .restricted: return "red"
        case .notInstalled: return "gray"
        default: return "yellow"
        }
    }
}

// MARK: - Sandbox Permissions Manager

/// Manages all TCC (Transparency, Consent, and Control) permissions for the sandboxed app
@MainActor
final class SandboxPermissionsManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var accessibilityStatus: PermissionStatus = .unknown
    @Published private(set) var automationStatus: [SandboxPermissionType: PermissionStatus] = [:]
    @Published private(set) var isCheckingPermissions = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.craigoclean.sandbox", category: "Permissions")

    /// Callback when a permission is granted
    var onPermissionGranted: ((String) -> Void)?

    // MARK: - Initialization

    init() {
        logger.info("SandboxPermissionsManager initialized")

        // Initialize all automation statuses
        for type in SandboxPermissionType.allCases where type != .accessibility {
            automationStatus[type] = .unknown
        }

        // Check permissions on init
        Task {
            await refreshAllPermissions()
        }

        // Set up periodic permission monitoring
        startPermissionMonitoring()
    }

    // MARK: - Public Methods

    /// Refresh all permission statuses
    func refreshAllPermissions() async {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        // Check accessibility
        let accessibilityGranted = checkAccessibilityPermission()
        accessibilityStatus = accessibilityGranted ? .authorized : .denied

        // Check automation permissions for each browser
        for type in SandboxPermissionType.allCases where type != .accessibility {
            let status = await checkAutomationPermission(for: type)
            automationStatus[type] = status
        }

        logger.info("Permission refresh complete. Accessibility: \(self.accessibilityStatus.displayText)")
    }

    /// Check accessibility permission status
    func checkAccessibilityPermission() -> Bool {
        // AXIsProcessTrustedWithOptions returns true if accessibility is enabled
        // Pass nil to just check without prompting
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission (will show system prompt)
    func requestAccessibilityPermission() {
        logger.info("Requesting accessibility permission")

        // This will show the system prompt asking user to grant accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Open System Preferences to the right pane
        openSystemSettings(for: .accessibility)
    }

    /// Check automation permission for a specific target
    func checkAutomationPermission(for type: SandboxPermissionType) async -> PermissionStatus {
        guard let bundleId = type.bundleIdentifier else {
            return .unknown
        }

        // Check if the target app is installed
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
            return .notInstalled
        }

        // Try a simple AppleScript to check permission
        // This will trigger the permission prompt if not yet determined
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let appName = self.getAppName(for: bundleId)
                let script = """
                tell application "\(appName)"
                    get name
                end tell
                """

                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(returning: .unknown)
                    return
                }

                var error: NSDictionary?
                _ = appleScript.executeAndReturnError(&error)

                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0

                    // Error codes that indicate permission denied
                    // -1743 = "Not authorized to send Apple events"
                    // -10004 = "A privilege violation occurred"
                    if errorNumber == -1743 || errorNumber == -10004 {
                        continuation.resume(returning: .denied)
                    } else if errorNumber == -600 {
                        // -600 = Application isn't running (but permission might be granted)
                        continuation.resume(returning: .notDetermined)
                    } else {
                        continuation.resume(returning: .denied)
                    }
                } else {
                    continuation.resume(returning: .authorized)
                }
            }
        }
    }

    /// Request automation permission for a specific app
    func requestAutomationPermission(for type: SandboxPermissionType) async -> Bool {
        guard let bundleId = type.bundleIdentifier else { return false }

        logger.info("Requesting automation permission for \(bundleId)")

        // Check if app is installed
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
            logger.warning("\(bundleId) is not installed")
            return false
        }

        // Launch the app if not running (required for permission prompt)
        let appName = getAppName(for: bundleId)
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleId
        }

        if !isRunning {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                configuration.hides = true

                do {
                    try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
                    // Wait for app to launch
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    logger.error("Failed to launch \(appName): \(error.localizedDescription)")
                }
            }
        }

        // Execute a script to trigger the permission prompt
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let script = """
                tell application "\(appName)"
                    get name
                end tell
                """

                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(returning: false)
                    return
                }

                var error: NSDictionary?
                _ = appleScript.executeAndReturnError(&error)

                if error == nil {
                    self.logger.info("Automation permission granted for \(bundleId)")
                    self.automationStatus[type] = .authorized
                    self.onPermissionGranted?(bundleId)
                    continuation.resume(returning: true)
                } else {
                    self.logger.warning("Automation permission denied or pending for \(bundleId)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Open System Settings to the appropriate privacy pane
    func openSystemSettings(for type: SandboxPermissionType) {
        let urlString = type.systemSettingsPath
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Get combined permission status summary
    var permissionSummary: (granted: Int, total: Int, criticalMissing: Bool) {
        var granted = 0
        var total = 1  // Start with accessibility
        var criticalMissing = false

        if accessibilityStatus.isGranted {
            granted += 1
        }

        for (type, status) in automationStatus {
            // Only count installed browsers
            if status != .notInstalled {
                total += 1
                if status.isGranted {
                    granted += 1
                } else if type == .automationSafari {
                    criticalMissing = true  // Safari automation is important
                }
            }
        }

        return (granted, total, criticalMissing)
    }

    // MARK: - Private Methods

    private func getAppName(for bundleId: String) -> String {
        switch bundleId {
        case "com.apple.Safari": return "Safari"
        case "com.google.Chrome": return "Google Chrome"
        case "com.microsoft.edgemac": return "Microsoft Edge"
        case "com.brave.Browser": return "Brave Browser"
        case "company.thebrowser.Browser": return "Arc"
        case "com.apple.systemevents": return "System Events"
        default: return bundleId
        }
    }

    private func startPermissionMonitoring() {
        // Check permissions periodically in case user grants them in System Settings
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Quick check of accessibility (doesn't require async)
                let accessibilityGranted = self?.checkAccessibilityPermission() ?? false
                let previousStatus = self?.accessibilityStatus
                self?.accessibilityStatus = accessibilityGranted ? .authorized : .denied

                // Notify if permission was just granted
                if accessibilityGranted && previousStatus != .authorized {
                    self?.logger.info("Accessibility permission was granted")
                }
            }
        }
    }
}

// MARK: - Permission Onboarding Helper

/// Helper for guiding users through permission setup
struct PermissionOnboardingStep: Identifiable {
    let id = UUID()
    let type: SandboxPermissionType
    let title: String
    let description: String
    let isRequired: Bool
    let instructions: [String]

    static var allSteps: [PermissionOnboardingStep] {
        return [
            PermissionOnboardingStep(
                type: .accessibility,
                title: "Accessibility Access",
                description: "Enables advanced app management features",
                isRequired: false,
                instructions: [
                    "Open System Settings",
                    "Go to Privacy & Security > Accessibility",
                    "Find Craig-O-Clean and enable it",
                    "You may need to unlock the settings first"
                ]
            ),
            PermissionOnboardingStep(
                type: .automationSafari,
                title: "Safari Automation",
                description: "View and manage Safari tabs to free up memory",
                isRequired: false,
                instructions: [
                    "When prompted, click 'OK' to allow",
                    "Or go to System Settings > Privacy & Security > Automation",
                    "Enable Safari under Craig-O-Clean"
                ]
            ),
            PermissionOnboardingStep(
                type: .automationChrome,
                title: "Chrome Automation",
                description: "View and manage Chrome tabs",
                isRequired: false,
                instructions: [
                    "When prompted, click 'OK' to allow",
                    "Or go to System Settings > Privacy & Security > Automation",
                    "Enable Google Chrome under Craig-O-Clean"
                ]
            )
        ]
    }
}
