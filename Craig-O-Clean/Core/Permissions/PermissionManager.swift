// MARK: - PermissionManager.swift
// Craig-O-Clean - Central Permission Management
// Provides unified permission checking and requesting for all TCC permissions

import Foundation
import Combine
import AppKit
import os.log

/// Central manager for all permission states and requests
@MainActor
final class PermissionManager: ObservableObject {

    // MARK: - Published Properties

    /// Automation permission status per bundle ID
    @Published private(set) var automationStatus: [String: PermissionState] = [:]

    /// Accessibility permission status
    @Published private(set) var accessibilityStatus: PermissionState = .unknown

    /// Full Disk Access permission status
    @Published private(set) var fullDiskAccessStatus: PermissionState = .unknown

    /// Notification permission status
    @Published private(set) var notificationStatus: PermissionState = .unknown

    /// Last permission check time
    @Published private(set) var lastCheckTime: Date?

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "Permissions")
    private var auditLog: AuditLogService?

    // MARK: - Known Bundle IDs

    /// Known browser bundle IDs for automation
    static let browserBundleIds: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "org.mozilla.firefox"
    ]

    /// System bundle IDs that may need automation
    static let systemBundleIds: [String] = [
        "com.apple.systemevents",
        "com.apple.finder"
    ]

    // MARK: - Initialization

    init(auditLog: AuditLogService? = nil) {
        self.auditLog = auditLog
    }

    /// Connect to audit log service after initialization
    func setAuditLog(_ auditLog: AuditLogService) {
        self.auditLog = auditLog
    }

    // MARK: - Refresh All

    /// Refresh all permission states
    func refreshAllPermissions() async {
        logger.info("Refreshing all permission states")

        // Check accessibility
        _ = checkAccessibility()

        // Check Full Disk Access
        _ = checkFullDiskAccess()

        // Check automation for known browsers
        for bundleId in Self.browserBundleIds {
            _ = await checkAutomation(for: bundleId)
        }

        lastCheckTime = Date()
    }

    // MARK: - Automation Permissions

    /// Check automation permission for a specific app
    @discardableResult
    func checkAutomation(for bundleId: String) async -> PermissionState {
        // If app isn't installed, return unknown
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
            automationStatus[bundleId] = .unknown
            return .unknown
        }

        // Execute minimal AppleScript to test permission
        let script = "tell application id \"\(bundleId)\" to return name"

        let result = await executeAppleScriptCheck(script)

        switch result {
        case .success:
            automationStatus[bundleId] = .granted
            return .granted

        case .permissionDenied:
            automationStatus[bundleId] = .denied
            return .denied

        case .error:
            // Could be app not running or other issue - don't change state
            return automationStatus[bundleId] ?? .unknown
        }
    }

    /// Request automation permission for a specific app
    /// This triggers the system permission prompt
    @discardableResult
    func requestAutomation(for bundleId: String) async -> PermissionState {
        logger.info("Requesting automation permission for \(bundleId)")

        auditLog?.log(.permissionRequested, target: bundleId, metadata: ["type": "automation"])

        // First check current state
        let currentState = await checkAutomation(for: bundleId)
        if currentState == .granted {
            return .granted
        }

        // Execute a script that will trigger the system prompt
        // The app must be running for this to work
        let launchScript = "tell application id \"\(bundleId)\" to activate"
        _ = await executeAppleScriptCheck(launchScript)

        // Give the system a moment to show the prompt
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Re-check after prompt
        let newState = await checkAutomation(for: bundleId)

        // Log result
        if newState == .granted {
            auditLog?.log(.permissionGranted, target: bundleId, metadata: ["type": "automation"])
        } else {
            auditLog?.log(.permissionDenied, target: bundleId, metadata: ["type": "automation"])
        }

        return newState
    }

    /// Get human-readable app name for bundle ID
    func appName(for bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return FileManager.default.displayName(atPath: url.path)
        }

        // Fallback to known names
        let knownNames: [String: String] = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Google Chrome",
            "com.microsoft.edgemac": "Microsoft Edge",
            "com.brave.Browser": "Brave Browser",
            "company.thebrowser.Browser": "Arc",
            "org.mozilla.firefox": "Firefox",
            "com.apple.systemevents": "System Events",
            "com.apple.finder": "Finder"
        ]

        return knownNames[bundleId] ?? bundleId
    }

    // MARK: - Accessibility Permission

    /// Check if app is trusted for accessibility
    @discardableResult
    func checkAccessibility() -> PermissionState {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .granted : .denied
        logger.info("Accessibility permission: \(trusted ? "granted" : "denied")")
        return accessibilityStatus
    }

    /// Request accessibility permission (opens System Settings with prompt)
    func requestAccessibility() {
        logger.info("Requesting accessibility permission")
        auditLog?.log(.permissionRequested, target: "accessibility", metadata: ["type": "accessibility"])

        // This will trigger the system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if trusted {
            accessibilityStatus = .granted
            auditLog?.log(.permissionGranted, target: "accessibility", metadata: ["type": "accessibility"])
        } else {
            // User may need to enable manually
            accessibilityStatus = .denied
        }
    }

    // MARK: - Full Disk Access Permission

    /// Check Full Disk Access (heuristic-based, not 100% reliable)
    @discardableResult
    func checkFullDiskAccess() -> PermissionState {
        // Try multiple protected paths to increase accuracy

        // Method 1: Try Safari History database
        let safariHistoryPath = NSHomeDirectory() + "/Library/Safari/History.db"
        if FileManager.default.isReadableFile(atPath: safariHistoryPath) {
            fullDiskAccessStatus = .granted
            logger.info("Full Disk Access: granted (Safari history readable)")
            return .granted
        }

        // Method 2: Try Mail directory
        let mailPath = NSHomeDirectory() + "/Library/Mail"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: mailPath), !contents.isEmpty {
            fullDiskAccessStatus = .granted
            logger.info("Full Disk Access: granted (Mail directory readable)")
            return .granted
        }

        // Method 3: Try TCC database directory
        let tccPath = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC"
        if FileManager.default.fileExists(atPath: tccPath) {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: tccPath), !contents.isEmpty {
                fullDiskAccessStatus = .granted
                logger.info("Full Disk Access: granted (TCC directory readable)")
                return .granted
            }
        }

        fullDiskAccessStatus = .denied
        logger.info("Full Disk Access: denied or not determined")
        return .denied
    }

    /// Open Full Disk Access settings
    func requestFullDiskAccess() {
        logger.info("Opening Full Disk Access settings")
        auditLog?.log(.permissionRequested, target: "full_disk_access", metadata: ["type": "fullDiskAccess"])
        openSystemSettings(for: .fullDiskAccess)
    }

    // MARK: - System Settings URLs

    /// Open the appropriate System Settings pane for a permission type
    func openSystemSettings(for permission: PermissionType) {
        let urlString: String

        switch permission {
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .fileAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
        case .notifications:
            urlString = "x-apple.systempreferences:com.apple.preference.notifications"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open Automation settings for a specific app
    func openAutomationSettings() {
        openSystemSettings(for: .automation(bundleId: ""))
    }

    /// Open Accessibility settings
    func openAccessibilitySettings() {
        openSystemSettings(for: .accessibility)
    }

    /// Open Full Disk Access settings
    func openFullDiskAccessSettings() {
        openSystemSettings(for: .fullDiskAccess)
    }

    // MARK: - Convenience Methods

    /// Check if any browser has automation permission
    func hasAnyBrowserAutomation() -> Bool {
        Self.browserBundleIds.contains { bundleId in
            automationStatus[bundleId] == .granted
        }
    }

    /// Get list of browsers with automation permission
    func browsersWithAutomation() -> [String] {
        Self.browserBundleIds.filter { bundleId in
            automationStatus[bundleId] == .granted
        }
    }

    /// Get list of installed browsers
    func installedBrowsers() -> [String] {
        Self.browserBundleIds.filter { bundleId in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        }
    }

    // MARK: - Private Helpers

    private enum AppleScriptCheckResult {
        case success
        case permissionDenied
        case error
    }

    private func executeAppleScriptCheck(_ source: String) async -> AppleScriptCheckResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: .error)
                    return
                }

                var error: NSDictionary?
                script.executeAndReturnError(&error)

                if let error = error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0

                    // Error -1743: "Not authorized to send Apple events"
                    // Error -10004: "A privilege violation occurred"
                    // Error -1728: "Can't get object" (often permission-related)
                    if code == -1743 || code == -10004 || code == -1728 {
                        continuation.resume(returning: .permissionDenied)
                        return
                    }

                    continuation.resume(returning: .error)
                    return
                }

                continuation.resume(returning: .success)
            }
        }
    }
}

// MARK: - Permission Summary

extension PermissionManager {
    /// Get a summary of all permission states
    struct PermissionSummary {
        let accessibility: PermissionState
        let fullDiskAccess: PermissionState
        let automationBrowsers: [(bundleId: String, name: String, state: PermissionState)]
        let lastChecked: Date?

        var allGranted: Bool {
            accessibility == .granted &&
            fullDiskAccess == .granted &&
            automationBrowsers.allSatisfy { $0.state == .granted }
        }

        var anyDenied: Bool {
            accessibility == .denied ||
            fullDiskAccess == .denied ||
            automationBrowsers.contains { $0.state == .denied }
        }
    }

    func getSummary() -> PermissionSummary {
        let browserSummary = Self.browserBundleIds.compactMap { bundleId -> (String, String, PermissionState)? in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
                return nil
            }
            return (bundleId, appName(for: bundleId), automationStatus[bundleId] ?? .unknown)
        }

        return PermissionSummary(
            accessibility: accessibilityStatus,
            fullDiskAccess: fullDiskAccessStatus,
            automationBrowsers: browserSummary,
            lastChecked: lastCheckTime
        )
    }
}
