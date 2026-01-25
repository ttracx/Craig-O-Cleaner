import Foundation
import AppKit

/// Manages system permissions required by Craig-O Terminator
@MainActor
final class PermissionsManager: ObservableObject {

    static let shared = PermissionsManager()

    @Published var hasCheckedPermissions = false
    @Published var showPermissionsSheet = false
    @Published var permissionStatuses: [PermissionType: PermissionStatus] = [:]

    private let userDefaults = UserDefaults.standard
    private let hasLaunchedKey = "has_launched_before"
    private var appActivationObserver: NSObjectProtocol?

    enum PermissionType: String, CaseIterable {
        case accessibility = "Accessibility"
        case fullDiskAccess = "Full Disk Access"
        case automation = "Automation"

        var description: String {
            switch self {
            case .accessibility:
                return "Required to monitor and control processes and browsers"
            case .fullDiskAccess:
                return "Required to clean system caches and temporary files"
            case .automation:
                return "Required to control browsers via AppleScript"
            }
        }

        var icon: String {
            switch self {
            case .accessibility:
                return "hand.tap"
            case .fullDiskAccess:
                return "internaldrive"
            case .automation:
                return "gearshape.2"
            }
        }

        var settingsPath: String {
            switch self {
            case .accessibility:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .fullDiskAccess:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
            case .automation:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            }
        }
    }

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined

        var color: NSColor {
            switch self {
            case .granted:
                return .systemGreen
            case .denied:
                return .systemRed
            case .notDetermined:
                return .systemOrange
            }
        }

        var icon: String {
            switch self {
            case .granted:
                return "checkmark.circle.fill"
            case .denied:
                return "xmark.circle.fill"
            case .notDetermined:
                return "questionmark.circle.fill"
            }
        }

        var statusText: String {
            switch self {
            case .granted:
                return "Granted"
            case .denied:
                return "Denied"
            case .notDetermined:
                return "Not Determined"
            }
        }
    }

    private init() {
        setupAppLifecycleObserver()
    }

    deinit {
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - App Lifecycle

    private func setupAppLifecycleObserver() {
        // Monitor when app becomes active (e.g., returning from System Settings)
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            // Only re-check if we've already shown the permissions sheet
            if self.hasCheckedPermissions {
                print("PermissionsManager: App became active, re-checking permissions...")
                Task { @MainActor in
                    await self.checkAllPermissions()
                }
            }
        }
    }

    // MARK: - First Launch Check

    func checkFirstLaunch() {
        let hasLaunched = userDefaults.bool(forKey: hasLaunchedKey)

        if !hasLaunched {
            // First launch - show permissions sheet
            showPermissionsSheet = true
            userDefaults.set(true, forKey: hasLaunchedKey)
        }

        // Always check current permission statuses
        Task {
            await checkAllPermissions()
        }
    }

    // MARK: - Permission Checks

    func checkAllPermissions() async {
        print("PermissionsManager: Checking all permissions...")
        await checkAccessibility()
        await checkFullDiskAccess()
        await checkAutomation()

        await MainActor.run {
            hasCheckedPermissions = true
        }

        print("PermissionsManager: Permission check complete")
        print("  - Accessibility: \(permissionStatuses[.accessibility]?.statusText ?? "Unknown")")
        print("  - Full Disk Access: \(permissionStatuses[.fullDiskAccess]?.statusText ?? "Unknown")")
        print("  - Automation: \(permissionStatuses[.automation]?.statusText ?? "Unknown")")
    }

    private func checkAccessibility() async {
        let trusted = AXIsProcessTrusted()
        await MainActor.run {
            permissionStatuses[.accessibility] = trusted ? .granted : .denied
        }
    }

    private func checkFullDiskAccess() async {
        // Try to access a protected file to test Full Disk Access
        let testPath = NSHomeDirectory() + "/Library/Safari/CloudTabs.db"
        let hasAccess = FileManager.default.isReadableFile(atPath: testPath)

        await MainActor.run {
            permissionStatuses[.fullDiskAccess] = hasAccess ? .granted : .denied
        }
    }

    private func checkAutomation() async {
        // Check automation by testing AppleScript execution
        let script = """
        tell application "System Events"
            return name
        end tell
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let hasPermission = task.terminationStatus == 0
            await MainActor.run {
                permissionStatuses[.automation] = hasPermission ? .granted : .denied
            }
        } catch {
            await MainActor.run {
                permissionStatuses[.automation] = .denied
            }
        }
    }

    // MARK: - Permission Requests

    func requestAccessibility() {
        // Prompt for accessibility permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)

        // Check again after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await checkAccessibility()
        }
    }

    func openSystemSettings(for permission: PermissionType) {
        if let url = URL(string: permission.settingsPath) {
            NSWorkspace.shared.open(url)
        }

        // Recheck after user returns (approximate)
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await checkAllPermissions()
        }
    }

    // MARK: - Helpers

    var allPermissionsGranted: Bool {
        PermissionType.allCases.allSatisfy { type in
            permissionStatuses[type] == .granted
        }
    }

    var requiredPermissionsCount: Int {
        PermissionType.allCases.filter { type in
            permissionStatuses[type] != .granted
        }.count
    }

    func getStatus(for permission: PermissionType) -> PermissionStatus {
        permissionStatuses[permission] ?? .notDetermined
    }
}
