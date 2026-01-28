//
//  AutoPermissionHandler.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import AppKit
import UserNotifications
import os.log

/// Handles automatic remediation of missing permissions
@Observable
final class AutoPermissionHandler {

    // MARK: - Singleton

    static let shared = AutoPermissionHandler()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "AutoPermissionHandler")
    private let permissionCenter: PermissionCenter

    /// Whether auto-remediation is enabled
    var autoRemediationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoRemediationEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoRemediationEnabled") }
    }

    /// Track which permissions we've already auto-opened to avoid spam
    private var autoOpenedPermissions: Set<String> = []
    private let autoOpenTrackingKey = "autoOpenedPermissions"

    // MARK: - Initialization

    init(permissionCenter: PermissionCenter = .shared) {
        self.permissionCenter = permissionCenter

        // Enable auto-remediation by default
        if !UserDefaults.standard.bool(forKey: "hasSetAutoRemediation") {
            autoRemediationEnabled = true
            UserDefaults.standard.set(true, forKey: "hasSetAutoRemediation")
        }

        // Load tracking state
        if let savedPermissions = UserDefaults.standard.array(forKey: autoOpenTrackingKey) as? [String] {
            autoOpenedPermissions = Set(savedPermissions)
        }
    }

    // MARK: - Auto-Remediation

    /// Handle missing permissions with automatic remediation
    @MainActor
    func handleMissingPermissions(_ permissions: [PermissionType], for capability: Capability) async {
        guard !permissions.isEmpty else { return }

        logger.info("Handling \(permissions.count) missing permissions for \(capability.id)")

        // Check if auto-remediation is enabled
        guard autoRemediationEnabled else {
            logger.debug("Auto-remediation is disabled")
            await showManualRemediationAlert(permissions, for: capability)
            return
        }

        // Show alert explaining what we're about to do
        let shouldProceed = await showAutoRemediationAlert(permissions, for: capability)
        guard shouldProceed else {
            logger.info("User cancelled auto-remediation")
            return
        }

        // Open System Settings for each missing permission
        for permission in permissions {
            await openSettingsForPermission(permission)

            // Small delay between opening multiple permission panes
            if permissions.count > 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }

    /// Open System Settings for a specific permission
    @MainActor
    private func openSettingsForPermission(_ permission: PermissionType) async {
        let permissionKey = permission.displayName

        // Check if we've already auto-opened this permission in this session
        guard !autoOpenedPermissions.contains(permissionKey) else {
            logger.debug("Already auto-opened \(permissionKey) in this session, skipping")
            return
        }

        logger.info("Auto-opening System Settings for \(permissionKey)")

        // Mark as opened
        autoOpenedPermissions.insert(permissionKey)
        saveAutoOpenedPermissions()

        // Open System Settings
        permissionCenter.openSystemSettings(for: permission)

        // Show instruction notification
        await showInstructionNotification(for: permission)
    }

    // MARK: - Alerts

    @MainActor
    private func showAutoRemediationAlert(_ permissions: [PermissionType], for capability: Capability) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"

        let permissionList = permissions.map { "• \($0.displayName)" }.joined(separator: "\n")
        alert.informativeText = """
        \(capability.id) requires the following permissions:

        \(permissionList)

        System Settings will open automatically to the correct permission panes. Please grant the requested permissions and return to Craig-O-Clean.

        You can disable automatic opening in Settings.
        """

        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        // Add checkbox to disable auto-remediation
        let checkbox = NSButton(checkboxWithTitle: "Don't ask again (open manually from Settings)", target: nil, action: nil)
        alert.accessoryView = checkbox

        let response = alert.runModal()

        // Update auto-remediation setting if checkbox is checked
        if checkbox.state == .on {
            autoRemediationEnabled = false
            logger.info("Auto-remediation disabled by user")
        }

        return response == .alertFirstButtonReturn
    }

    @MainActor
    private func showManualRemediationAlert(_ permissions: [PermissionType], for capability: Capability) async {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"

        let permissionList = permissions.map { "• \($0.displayName)" }.joined(separator: "\n")
        alert.informativeText = """
        \(capability.id) requires the following permissions:

        \(permissionList)

        Please grant these permissions in System Settings > Privacy & Security, then try again.

        Tip: You can enable automatic opening in Craig-O-Clean Settings.
        """

        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Open settings for first permission
            if let firstPermission = permissions.first {
                permissionCenter.openSystemSettings(for: firstPermission)
            }
        }
    }

    @MainActor
    private func showInstructionNotification(for permission: PermissionType) async {
        // Use modern UserNotifications framework
        let center = UNUserNotificationCenter.current()

        // Request authorization if needed
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Grant Permission"
        content.body = "Please enable '\(permission.displayName)' for Craig-O-Clean in System Settings"
        content.sound = .default

        // Create and schedule notification
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        try? await center.add(request)
    }

    // MARK: - Permission Tracking

    private func saveAutoOpenedPermissions() {
        UserDefaults.standard.set(Array(autoOpenedPermissions), forKey: autoOpenTrackingKey)
    }

    /// Reset tracking (useful when app restarts or permissions are revoked)
    func resetAutoOpenTracking() {
        autoOpenedPermissions.removeAll()
        saveAutoOpenedPermissions()
        logger.info("Reset auto-open tracking")
    }

    /// Clear tracking for specific permission (if user manually fixed it)
    func clearTracking(for permission: PermissionType) {
        autoOpenedPermissions.remove(permission.displayName)
        saveAutoOpenedPermissions()
        logger.debug("Cleared tracking for \(permission.displayName)")
    }

    // MARK: - Session Management

    /// Call this when app becomes active to reset session tracking
    func handleAppBecameActive() {
        // Reset tracking when app becomes active again (user may have granted permissions)
        resetAutoOpenTracking()
    }
}
