// MARK: - NotificationService.swift
// Craig-O-Clean - User Notification Service
// Handles memory pressure alerts and cleanup completion notifications

import Foundation
import UserNotifications
import Combine
import os.log

// MARK: - Notification Types

enum CraigNotificationType: String {
    case memoryPressureWarning = "memory.pressure.warning"
    case memoryPressureCritical = "memory.pressure.critical"
    case cleanupComplete = "cleanup.complete"
    case permissionRequired = "permission.required"

    var title: String {
        switch self {
        case .memoryPressureWarning:
            return "Memory Pressure Warning"
        case .memoryPressureCritical:
            return "High Memory Pressure"
        case .cleanupComplete:
            return "Cleanup Complete"
        case .permissionRequired:
            return "Permission Required"
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .memoryPressureWarning, .memoryPressureCritical:
            return "MEMORY_PRESSURE"
        case .cleanupComplete:
            return "CLEANUP"
        case .permissionRequired:
            return "PERMISSION"
        }
    }
}

// MARK: - Notification Actions

enum NotificationAction: String {
    case openApp = "OPEN_APP"
    case viewDetails = "VIEW_DETAILS"
    case quitHeavyApps = "QUIT_HEAVY_APPS"
    case openSettings = "OPEN_SETTINGS"
    case dismiss = "DISMISS"
}

// MARK: - Notification Service

@MainActor
final class NotificationService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var notificationsEnabled = true {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    @Published var memoryPressureAlertsEnabled = true {
        didSet {
            UserDefaults.standard.set(memoryPressureAlertsEnabled, forKey: "memoryPressureAlertsEnabled")
        }
    }
    @Published var cleanupAlertsEnabled = true {
        didSet {
            UserDefaults.standard.set(cleanupAlertsEnabled, forKey: "cleanupAlertsEnabled")
        }
    }

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "Notifications")
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Callbacks

    var onActionReceived: ((NotificationAction, [AnyHashable: Any]?) -> Void)?

    // MARK: - Private Properties

    private var lastMemoryPressureNotification: Date?
    private let memoryPressureCooldown: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    override init() {
        super.init()

        // Load saved preferences
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        memoryPressureAlertsEnabled = UserDefaults.standard.object(forKey: "memoryPressureAlertsEnabled") as? Bool ?? true
        cleanupAlertsEnabled = UserDefaults.standard.object(forKey: "cleanupAlertsEnabled") as? Bool ?? true

        // Set delegate
        notificationCenter.delegate = self

        // Check current authorization
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization

    func checkAuthorization() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized

        logger.info("Notification authorization status: \(String(describing: settings.authorizationStatus))")
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            authorizationStatus = granted ? .authorized : .denied

            if granted {
                await registerCategories()
            }

            logger.info("Notification authorization \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    private func registerCategories() async {
        // Memory Pressure Category
        let quitAppsAction = UNNotificationAction(
            identifier: NotificationAction.quitHeavyApps.rawValue,
            title: "Quit Heavy Apps",
            options: [.foreground]
        )

        let viewDetailsAction = UNNotificationAction(
            identifier: NotificationAction.viewDetails.rawValue,
            title: "View Details",
            options: [.foreground]
        )

        let memoryCategory = UNNotificationCategory(
            identifier: CraigNotificationType.memoryPressureWarning.categoryIdentifier,
            actions: [quitAppsAction, viewDetailsAction],
            intentIdentifiers: [],
            options: []
        )

        // Cleanup Category
        let openAppAction = UNNotificationAction(
            identifier: NotificationAction.openApp.rawValue,
            title: "Open App",
            options: [.foreground]
        )

        let cleanupCategory = UNNotificationCategory(
            identifier: CraigNotificationType.cleanupComplete.categoryIdentifier,
            actions: [openAppAction],
            intentIdentifiers: [],
            options: []
        )

        // Permission Category
        let openSettingsAction = UNNotificationAction(
            identifier: NotificationAction.openSettings.rawValue,
            title: "Open Settings",
            options: [.foreground]
        )

        let permissionCategory = UNNotificationCategory(
            identifier: CraigNotificationType.permissionRequired.categoryIdentifier,
            actions: [openSettingsAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([memoryCategory, cleanupCategory, permissionCategory])
    }

    // MARK: - Send Notifications

    func sendNotification(
        type: CraigNotificationType,
        body: String,
        userInfo: [AnyHashable: Any] = [:]
    ) async {
        guard notificationsEnabled else { return }
        guard isAuthorized else {
            logger.warning("Cannot send notification - not authorized")
            return
        }

        // Check type-specific settings
        switch type {
        case .memoryPressureWarning, .memoryPressureCritical:
            guard memoryPressureAlertsEnabled else { return }
        case .cleanupComplete:
            guard cleanupAlertsEnabled else { return }
        case .permissionRequired:
            break // Always allow permission notifications
        }

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = type.categoryIdentifier
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "\(type.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await notificationCenter.add(request)
            logger.info("Sent notification: \(type.rawValue)")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Memory Pressure Notifications

    func sendMemoryPressureAlert(level: MemoryPressureLevel, usedPercentage: Double) async {
        // Check cooldown
        if let lastNotification = lastMemoryPressureNotification,
           Date().timeIntervalSince(lastNotification) < memoryPressureCooldown {
            return
        }

        let type: CraigNotificationType
        let body: String

        switch level {
        case .warning:
            type = .memoryPressureWarning
            body = "Memory usage is at \(String(format: "%.0f%%", usedPercentage)). Consider closing some applications."
        case .critical:
            type = .memoryPressureCritical
            body = "Memory is critically low (\(String(format: "%.0f%%", usedPercentage)) used). Close applications to prevent slowdowns."
        case .normal:
            return // Don't notify for normal
        }

        await sendNotification(type: type, body: body, userInfo: [
            "memoryUsage": usedPercentage,
            "pressureLevel": level.rawValue
        ])

        lastMemoryPressureNotification = Date()
    }

    // MARK: - Cleanup Notifications

    func sendCleanupCompleteNotification(deletedCount: Int, freedSpace: UInt64) async {
        let formattedSpace = ByteCountFormatter.string(fromByteCount: Int64(freedSpace), countStyle: .file)

        let body = "Deleted \(deletedCount) files and freed \(formattedSpace) of space."

        await sendNotification(type: .cleanupComplete, body: body, userInfo: [
            "deletedCount": deletedCount,
            "freedSpace": freedSpace
        ])
    }

    // MARK: - Permission Notifications

    func sendPermissionRequiredNotification(for feature: String, permission: String) async {
        let body = "\(feature) requires \(permission) permission. Tap to open settings."

        await sendNotification(type: .permissionRequired, body: body, userInfo: [
            "feature": feature,
            "permission": permission
        ])
    }

    // MARK: - Remove Notifications

    func removeAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        // Map system actions to our enum
        let action: NotificationAction
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            action = .openApp
        case UNNotificationDismissActionIdentifier:
            action = .dismiss
        default:
            action = NotificationAction(rawValue: actionIdentifier) ?? .openApp
        }

        await MainActor.run {
            onActionReceived?(action, userInfo)
        }
    }
}

// MARK: - Memory Pressure Source

@MainActor
final class MemoryPressureMonitor: ObservableObject {

    @Published private(set) var currentPressure: MemoryPressureLevel = .normal
    @Published private(set) var isMonitoring = false

    private var pressureSource: DispatchSourceMemoryPressure?
    private let notificationService: NotificationService?
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "MemoryPressure")

    var onPressureChange: ((MemoryPressureLevel) -> Void)?

    init(notificationService: NotificationService? = nil) {
        self.notificationService = notificationService
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        pressureSource?.setEventHandler { [weak self] in
            guard let self = self, let source = self.pressureSource else { return }

            let event = source.data
            let newPressure: MemoryPressureLevel

            if event.contains(.critical) {
                newPressure = .critical
            } else if event.contains(.warning) {
                newPressure = .warning
            } else {
                newPressure = .normal
            }

            Task { @MainActor in
                if newPressure != self.currentPressure {
                    self.currentPressure = newPressure
                    self.onPressureChange?(newPressure)
                    self.logger.info("Memory pressure changed to: \(newPressure.rawValue)")

                    // Send notification if configured
                    if let notificationService = self.notificationService {
                        // Get current memory usage for notification
                        let usage = self.getCurrentMemoryUsage()
                        await notificationService.sendMemoryPressureAlert(
                            level: newPressure,
                            usedPercentage: usage
                        )
                    }
                }
            }
        }

        pressureSource?.resume()
        isMonitoring = true
        logger.info("Memory pressure monitoring started")
    }

    func stopMonitoring() {
        pressureSource?.cancel()
        pressureSource = nil
        isMonitoring = false
        logger.info("Memory pressure monitoring stopped")
    }

    private func getCurrentMemoryUsage() -> Double {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let totalRAM = UInt64(ProcessInfo.processInfo.physicalMemory)
        let pageSize = UInt64(vm_kernel_page_size)

        let activeRAM = UInt64(vmStats.active_count) * pageSize
        let wiredRAM = UInt64(vmStats.wire_count) * pageSize
        let compressedRAM = UInt64(vmStats.compressor_page_count) * pageSize
        let usedRAM = activeRAM + wiredRAM + compressedRAM

        return Double(usedRAM) / Double(totalRAM) * 100
    }
}
