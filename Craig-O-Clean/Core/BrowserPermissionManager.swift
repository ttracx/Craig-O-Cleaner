// MARK: - BrowserPermissionManager.swift
// Craig-O-Clean - Browser Permission Auto-Enablement Manager
// Automatically detects permission grants and enables browser features

import Foundation
import Combine
import AppKit
import os.log

// MARK: - Permission Grant Notification

struct PermissionGrantNotification: Identifiable {
    let id = UUID()
    let browserName: String
    let timestamp: Date
    var isShown: Bool = false

    var message: String {
        "✅ \(browserName) automation enabled"
    }
}

// MARK: - Permission State

struct BrowserPermissionState: Codable {
    let bundleIdentifier: String
    var isGranted: Bool
    var lastChecked: Date
    var firstGranted: Date?

    mutating func markGranted() {
        isGranted = true
        lastChecked = Date()
        if firstGranted == nil {
            firstGranted = Date()
        }
    }

    mutating func markDenied() {
        isGranted = false
        lastChecked = Date()
    }
}

// MARK: - Browser Permission Manager

@MainActor
final class BrowserPermissionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var permissionStates: [String: BrowserPermissionState] = [:]
    @Published var pendingNotifications: [PermissionGrantNotification] = []
    @Published private(set) var recentlyGrantedPermissions: Set<String> = []

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.CraigOClean", category: "BrowserPermissionManager")
    private let userDefaults = UserDefaults.standard
    private let statesKey = "browserPermissionStates"
    private var cancellables = Set<AnyCancellable>()

    // Callbacks for when permissions are granted
    private var permissionGrantedCallbacks: [(String) -> Void] = []

    // MARK: - Initialization

    init() {
        logger.info("BrowserPermissionManager initialized")
        loadPersistedStates()
    }

    // MARK: - State Persistence

    private func loadPersistedStates() {
        guard let data = userDefaults.data(forKey: statesKey),
              let states = try? JSONDecoder().decode([String: BrowserPermissionState].self, from: data) else {
            logger.info("No persisted permission states found")
            return
        }

        permissionStates = states
        logger.info("Loaded \(states.count) persisted permission states")
    }

    private func persistStates() {
        guard let data = try? JSONEncoder().encode(permissionStates) else {
            logger.error("Failed to encode permission states")
            return
        }

        userDefaults.set(data, forKey: statesKey)
        logger.debug("Persisted \(self.permissionStates.count) permission states")
    }

    // MARK: - Permission Tracking

    /// Update permission state for a browser
    func updatePermissionState(bundleIdentifier: String, browserName: String, isGranted: Bool) {
        let wasGranted = permissionStates[bundleIdentifier]?.isGranted ?? false
        let isNewGrant = !wasGranted && isGranted

        // Update or create state
        if var state = permissionStates[bundleIdentifier] {
            if isGranted {
                state.markGranted()
            } else {
                state.markDenied()
            }
            permissionStates[bundleIdentifier] = state
        } else {
            var state = BrowserPermissionState(
                bundleIdentifier: bundleIdentifier,
                isGranted: isGranted,
                lastChecked: Date()
            )
            if isGranted {
                state.markGranted()
            }
            permissionStates[bundleIdentifier] = state
        }

        // Persist changes
        persistStates()

        // Handle new permission grant
        if isNewGrant {
            handleNewPermissionGrant(bundleIdentifier: bundleIdentifier, browserName: browserName)
        }
    }

    /// Handle when a new permission is granted
    private func handleNewPermissionGrant(bundleIdentifier: String, browserName: String) {
        logger.info("🎉 New permission granted for \(browserName)")

        // Add to recently granted set
        recentlyGrantedPermissions.insert(bundleIdentifier)

        // Create notification
        let notification = PermissionGrantNotification(
            browserName: browserName,
            timestamp: Date()
        )
        pendingNotifications.append(notification)

        // Trigger callbacks
        permissionGrantedCallbacks.forEach { callback in
            callback(bundleIdentifier)
        }

        // Auto-dismiss notification after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            dismissNotification(id: notification.id)
        }

        // Remove from recently granted after 30 seconds
        Task {
            try? await Task.sleep(for: .seconds(30))
            recentlyGrantedPermissions.remove(bundleIdentifier)
        }
    }

    /// Dismiss a notification
    func dismissNotification(id: UUID) {
        pendingNotifications.removeAll { $0.id == id }
    }

    /// Dismiss all notifications
    func dismissAllNotifications() {
        pendingNotifications.removeAll()
    }

    // MARK: - Permission Query

    /// Check if a browser has granted permission (includes persisted state)
    func hasGrantedPermission(bundleIdentifier: String) -> Bool {
        return permissionStates[bundleIdentifier]?.isGranted ?? false
    }

    /// Get all browsers with granted permissions
    var grantedBrowsers: [String] {
        permissionStates.filter { $0.value.isGranted }.map { $0.key }
    }

    /// Check if permission was recently granted (within last 30 seconds)
    func wasRecentlyGranted(bundleIdentifier: String) -> Bool {
        recentlyGrantedPermissions.contains(bundleIdentifier)
    }

    // MARK: - Callback Registration

    /// Register a callback to be called when any browser permission is granted
    func onPermissionGranted(_ callback: @escaping (String) -> Void) {
        permissionGrantedCallbacks.append(callback)
    }

    // MARK: - Bulk Operations

    /// Update multiple permission states at once
    func updateMultipleStates(_ updates: [(bundleIdentifier: String, browserName: String, isGranted: Bool)]) {
        for update in updates {
            updatePermissionState(
                bundleIdentifier: update.bundleIdentifier,
                browserName: update.browserName,
                isGranted: update.isGranted
            )
        }
    }

    /// Clear all permission states (for testing/reset)
    func clearAllStates() {
        logger.warning("Clearing all permission states")
        permissionStates.removeAll()
        pendingNotifications.removeAll()
        recentlyGrantedPermissions.removeAll()
        userDefaults.removeObject(forKey: statesKey)
    }

    // MARK: - Statistics

    var statistics: PermissionStatistics {
        let totalBrowsers = permissionStates.count
        let grantedCount = permissionStates.filter { $0.value.isGranted }.count
        let deniedCount = totalBrowsers - grantedCount
        let recentGrants = permissionStates.filter { state in
            guard let firstGranted = state.value.firstGranted else { return false }
            return Date().timeIntervalSince(firstGranted) < 300 // Last 5 minutes
        }.count

        return PermissionStatistics(
            totalBrowsers: totalBrowsers,
            grantedCount: grantedCount,
            deniedCount: deniedCount,
            recentGrants: recentGrants
        )
    }
}

// MARK: - Permission Statistics

struct PermissionStatistics {
    let totalBrowsers: Int
    let grantedCount: Int
    let deniedCount: Int
    let recentGrants: Int

    var grantedPercentage: Double {
        guard totalBrowsers > 0 else { return 0 }
        return Double(grantedCount) / Double(totalBrowsers) * 100
    }
}
