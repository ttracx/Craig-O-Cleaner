// MARK: - SandboxAppEnvironment.swift
// Craig-O-Clean - App Environment for Sandbox-Compliant Services
// Provides dependency injection container for all services

import Foundation
import Combine
import os.log

// MARK: - App Environment

/// Central dependency container for all sandbox-compliant services
@MainActor
final class SandboxAppEnvironment: ObservableObject {

    // MARK: - Services

    /// Audit logging service - logs all actions
    let auditLog: AuditLogService

    /// Permission management - handles TCC permissions
    let permissionManager: PermissionManager

    /// File access management - security-scoped bookmarks
    let fileAccessManager: FileAccessManager

    /// Actions service - safe process termination
    let actionsService: ActionsService

    /// Process manager - sandbox-safe process listing
    let processManager: SandboxProcessManager

    /// Browser service - tab management with permission integration
    let browserService: SandboxBrowserService

    /// Cleaner service - user-scoped file cleanup
    let cleanerService: CleanerService

    /// Notification service - user notifications
    let notificationService: NotificationService

    /// Memory pressure monitor - background monitoring
    let memoryPressureMonitor: MemoryPressureMonitor

    // MARK: - State

    @Published private(set) var isInitialized = false
    @Published private(set) var initializationError: Error?

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "AppEnvironment")

    // MARK: - Initialization

    init() {
        logger.info("Initializing SandboxAppEnvironment")

        // Create services in dependency order

        // 1. Audit log (no dependencies)
        self.auditLog = AuditLogService()

        // 2. Permission manager (depends on audit log for logging)
        self.permissionManager = PermissionManager(auditLog: auditLog)

        // 3. File access manager (depends on audit log)
        self.fileAccessManager = FileAccessManager(auditLog: auditLog)

        // 4. Actions service (depends on audit log, permission manager)
        self.actionsService = ActionsService(auditLog: auditLog, permissions: permissionManager)

        // 5. Process manager (depends on actions service, audit log)
        self.processManager = SandboxProcessManager(actionsService: actionsService, auditLog: auditLog)

        // 6. Browser service (depends on permission manager, audit log)
        self.browserService = SandboxBrowserService(permissionManager: permissionManager, auditLog: auditLog)

        // 7. Cleaner service (depends on file access manager, audit log)
        self.cleanerService = CleanerService(fileAccessManager: fileAccessManager, auditLog: auditLog)

        // 8. Notification service (no dependencies)
        self.notificationService = NotificationService()

        // 9. Memory pressure monitor (depends on notification service)
        self.memoryPressureMonitor = MemoryPressureMonitor(notificationService: notificationService)

        // Set up cross-service connections
        setupServiceConnections()

        isInitialized = true
        logger.info("SandboxAppEnvironment initialized successfully")
    }

    // MARK: - Service Setup

    private func setupServiceConnections() {
        // Connect notification action handler
        notificationService.onActionReceived = { [weak self] action, userInfo in
            self?.handleNotificationAction(action, userInfo: userInfo)
        }

        // Connect memory pressure callbacks
        memoryPressureMonitor.onPressureChange = { [weak self] level in
            self?.handleMemoryPressureChange(level)
        }
    }

    // MARK: - Lifecycle

    /// Start all background services
    func startServices() {
        logger.info("Starting background services")

        // Start process manager auto-update
        processManager.startAutoUpdate()

        // Start memory pressure monitoring if notifications are authorized
        if notificationService.isAuthorized && notificationService.memoryPressureAlertsEnabled {
            memoryPressureMonitor.startMonitoring()
        }

        // Refresh permissions
        Task {
            await permissionManager.refreshAllPermissions()
        }
    }

    /// Stop all background services
    func stopServices() {
        logger.info("Stopping background services")

        processManager.stopAutoUpdate()
        memoryPressureMonitor.stopMonitoring()
    }

    /// Refresh all data
    func refreshAll() async {
        logger.info("Refreshing all data")

        processManager.refreshApps()
        await browserService.fetchAllTabs()
        await permissionManager.refreshAllPermissions()
    }

    // MARK: - Event Handlers

    private func handleNotificationAction(_ action: NotificationAction, userInfo: [AnyHashable: Any]?) {
        logger.info("Handling notification action: \(action.rawValue)")

        switch action {
        case .quitHeavyApps:
            Task {
                _ = await processManager.quitHeavyApps()
            }
        case .openSettings:
            permissionManager.openAutomationSettings()
        case .viewDetails, .openApp:
            // App should handle this by bringing window to front
            NSApp.activate(ignoringOtherApps: true)
        case .dismiss:
            break
        }
    }

    private func handleMemoryPressureChange(_ level: MemoryPressureLevel) {
        logger.info("Memory pressure changed to: \(level.rawValue)")

        // Refresh process list to show updated memory info
        processManager.refreshApps()
    }

    // MARK: - Cleanup

    /// Perform any cleanup needed before termination
    func cleanup() {
        logger.info("Performing environment cleanup")

        stopServices()
        fileAccessManager.stopAccessingAll()
        notificationService.removeAllNotifications()
    }
}

// MARK: - Environment Key

import SwiftUI

private struct SandboxAppEnvironmentKey: EnvironmentKey {
    static let defaultValue: SandboxAppEnvironment? = nil
}

extension EnvironmentValues {
    var sandboxEnvironment: SandboxAppEnvironment? {
        get { self[SandboxAppEnvironmentKey.self] }
        set { self[SandboxAppEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Modifier

extension View {
    func sandboxEnvironment(_ environment: SandboxAppEnvironment) -> some View {
        self
            .environment(\.sandboxEnvironment, environment)
            .environmentObject(environment.auditLog)
            .environmentObject(environment.permissionManager)
            .environmentObject(environment.processManager)
            .environmentObject(environment.browserService)
            .environmentObject(environment.cleanerService)
            .environmentObject(environment.notificationService)
    }
}

// MARK: - Feature Flags

/// Feature availability based on build configuration
struct SandboxFeatureFlags {
    /// Whether memory purge is available (Developer ID only)
    static var memoryPurgeEnabled: Bool {
        #if DEVELOPER_ID_BUILD
        return true
        #else
        return false
        #endif
    }

    /// Whether system service restarts are available (Developer ID only)
    static var systemRestartEnabled: Bool {
        #if DEVELOPER_ID_BUILD
        return true
        #else
        return false
        #endif
    }

    /// Whether advanced process termination is available (Developer ID only)
    static var advancedTerminationEnabled: Bool {
        #if DEVELOPER_ID_BUILD
        return true
        #else
        return false
        #endif
    }

    /// Whether all features are sandbox-compliant (MAS build)
    static var isSandboxBuild: Bool {
        #if DEVELOPER_ID_BUILD
        return false
        #else
        return true
        #endif
    }
}

// MARK: - App Configuration

struct SandboxAppConfiguration {
    /// Process refresh interval
    var processRefreshInterval: TimeInterval = 2.0

    /// Browser tab refresh interval
    var browserRefreshInterval: TimeInterval = 10.0

    /// Memory pressure notification cooldown
    var memoryPressureCooldown: TimeInterval = 300.0

    /// Maximum files to scan in cleanup
    var maxScanFiles: Int = 10000

    /// Auto-cleanup enabled
    var autoCleanupEnabled: Bool = false

    /// Auto-cleanup interval (hours)
    var autoCleanupInterval: Int = 24

    /// Launch at login
    var launchAtLogin: Bool = false

    static let `default` = SandboxAppConfiguration()

    // MARK: - Persistence

    private static let key = "SandboxAppConfiguration"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func load() -> SandboxAppConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(SandboxAppConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
}

extension SandboxAppConfiguration: Codable {}
