import Foundation
import AppKit
import UserNotifications

/// Background monitor that checks permissions and prompts user when needed
@MainActor
final class PermissionMonitor: ObservableObject {

    static let shared = PermissionMonitor()

    @Published var isMonitoring = false

    private var monitorTimer: Timer?
    private let checkInterval: TimeInterval = 60.0 // Check every 60 seconds
    private var lastPromptTime: [PermissionsManager.PermissionType: Date] = [:]
    private let promptCooldown: TimeInterval = 300.0 // Don't prompt more than once per 5 minutes for same permission

    private init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("PermissionMonitor: Failed to request notification permission: \(error)")
            }
        }
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }

        print("PermissionMonitor: Starting background monitoring...")
        isMonitoring = true

        // Initial check after a delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds after app launch
            await checkAndPromptForPermissions()
        }

        // Set up periodic checks
        monitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndPromptForPermissions()
            }
        }
    }

    func stopMonitoring() {
        print("PermissionMonitor: Stopping background monitoring...")
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    // MARK: - Permission Checking

    private func checkAndPromptForPermissions() async {
        // Defer to avoid any view update conflicts
        await Task.yield()
        await Task.yield()

        let permissionsManager = PermissionsManager.shared

        // Check each permission type
        for permissionType in PermissionsManager.PermissionType.allCases {
            let status = permissionsManager.getStatus(for: permissionType)

            // If permission is not granted, consider prompting
            if status != .granted {
                await promptForPermissionIfNeeded(permissionType)
            }
        }
    }

    private func promptForPermissionIfNeeded(_ permission: PermissionsManager.PermissionType) async {
        // Check cooldown - don't prompt too frequently
        if let lastPrompt = lastPromptTime[permission] {
            let timeSinceLastPrompt = Date().timeIntervalSince(lastPrompt)
            if timeSinceLastPrompt < promptCooldown {
                return // Too soon to prompt again
            }
        }

        // Update last prompt time
        lastPromptTime[permission] = Date()

        // Show prompt on main thread
        await MainActor.run {
            showPermissionPrompt(for: permission)
        }
    }

    // MARK: - UI Prompts

    private func showPermissionPrompt(for permission: PermissionsManager.PermissionType) {
        let alert = NSAlert()
        alert.messageText = "\(permission.rawValue) Required"
        alert.informativeText = "Craig-O Terminator needs \(permission.rawValue) permission to function properly.\n\n\(permission.description)\n\nWould you like to open System Settings to grant this permission?"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "exclamationmark.shield.fill", accessibilityDescription: nil)

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Don't Ask Again")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Open System Settings
            openSystemSettings(for: permission)

        case .alertThirdButtonReturn:
            // Don't ask again - set cooldown to far future
            lastPromptTime[permission] = Date().addingTimeInterval(86400 * 365) // 1 year

        default:
            // Not now - will ask again after cooldown
            break
        }
    }

    private func openSystemSettings(for permission: PermissionsManager.PermissionType) {
        guard let url = URL(string: permission.settingsPath) else {
            print("PermissionMonitor: Invalid settings URL for \(permission.rawValue)")
            return
        }

        // Open System Settings
        NSWorkspace.shared.open(url)

        // Show follow-up notification
        showFollowUpNotification(for: permission)

        // Schedule recheck after user returns
        Task { @MainActor in
            // Wait for user to potentially grant permission
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

            // Recheck permissions
            await PermissionsManager.shared.checkAllPermissions()

            // Verify permission was granted
            let status = PermissionsManager.shared.getStatus(for: permission)
            if status == .granted {
                showPermissionGrantedNotification(for: permission)
            }
        }
    }

    // MARK: - User Notifications

    private func showFollowUpNotification(for permission: PermissionsManager.PermissionType) {
        let content = UNMutableNotificationContent()
        content.title = "Grant \(permission.rawValue)"
        content.body = "Please enable \(permission.rawValue) for Craig-O Terminator in System Settings, then return to the app."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "permission-followup-\(permission.rawValue)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("PermissionMonitor: Failed to show notification: \(error)")
            }
        }
    }

    private func showPermissionGrantedNotification(for permission: PermissionsManager.PermissionType) {
        let content = UNMutableNotificationContent()
        content.title = "Permission Granted"
        content.body = "\(permission.rawValue) has been enabled. Craig-O Terminator now has full functionality."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "permission-granted-\(permission.rawValue)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("PermissionMonitor: Failed to show notification: \(error)")
            }
        }
    }

    // MARK: - Manual Permission Request

    func requestPermission(_ permission: PermissionsManager.PermissionType) async {
        // Bypass cooldown for manual requests
        await MainActor.run {
            showPermissionPrompt(for: permission)
        }
    }

    // MARK: - Utility

    func resetCooldowns() {
        lastPromptTime.removeAll()
    }
}
