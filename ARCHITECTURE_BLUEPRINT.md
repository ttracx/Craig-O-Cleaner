# Craig-O-Clean Sandbox Architecture Blueprint

**Version:** 1.0
**Date:** 2026-01-28
**Target:** Mac App Store Primary, Developer ID Extended

---

## Overview

This document describes the target architecture for Craig-O-Clean after the sandbox-compliant refactor. The design follows these principles:

1. **Least Privilege** - Request only necessary permissions
2. **User Mediation** - All destructive actions require explicit user consent
3. **Graceful Degradation** - Features disable cleanly when permissions denied
4. **MAS First** - Design for App Store, extend for Developer ID
5. **Native APIs** - Prefer Darwin/Mach APIs over shell commands

---

## C1. App Layer (UI)

### Module Structure

```
Craig-O-Clean/
├── App/
│   ├── Craig_O_CleanApp.swift      # @main entry, AppDelegate
│   ├── AppEnvironment.swift        # Environment configuration
│   └── AppState.swift              # Global app state (new)
├── UI/
│   ├── MenuBar/
│   │   ├── MenuBarManager.swift    # Menu bar lifecycle
│   │   ├── MenuBarContentView.swift
│   │   └── MenuBarStatsView.swift  # Compact stats display
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── CPUMetricsCard.swift
│   │   ├── MemoryMetricsCard.swift
│   │   ├── DiskMetricsCard.swift
│   │   └── NetworkMetricsCard.swift
│   ├── Actions/
│   │   ├── ActionPanelView.swift      # Action execution UI
│   │   ├── DryRunPreviewView.swift    # Preview before destructive ops
│   │   ├── ConfirmationDialog.swift   # User confirmation
│   │   └── ActionProgressView.swift   # Execution progress
│   ├── Processes/
│   │   ├── ProcessManagerView.swift
│   │   └── ProcessRowView.swift
│   ├── Browser/
│   │   ├── BrowserTabsView.swift
│   │   └── TabRowView.swift
│   ├── Cleanup/
│   │   ├── CleanupView.swift          # Main cleanup UI
│   │   ├── FolderSelectionView.swift  # Security-scoped bookmark UI
│   │   └── CleanupResultsView.swift
│   ├── Permissions/
│   │   ├── PermissionStatusView.swift
│   │   ├── PermissionExplanationView.swift
│   │   └── PermissionGuideView.swift  # Step-by-step enable guide
│   └── Settings/
│       ├── SettingsView.swift
│       ├── SettingsPermissionsView.swift
│       └── SettingsAboutView.swift
└── Features/
    ├── ActivityLog/
    │   ├── ActivityLogView.swift
    │   └── LogEntryRowView.swift
    └── Onboarding/
        └── OnboardingView.swift       # First-run permission setup
```

### Key UI Principles

1. **Permission Status Always Visible**
   - Traffic light indicators (green/yellow/red) in settings
   - "Learn how to enable" CTA for each denied permission

2. **Destructive Operation Flow**
   ```
   User Taps Action → Dry-Run Preview → Confirmation Dialog → Execute → Result + Audit Log
   ```

3. **Permission Request Flow**
   ```
   Explanation Screen → System Prompt → Result Handling → Feature Enable/Disable
   ```

---

## C2. Core Services

### Service Registry

All services are `@MainActor` and observable, injected via `@EnvironmentObject`.

```swift
// AppEnvironment.swift
@MainActor
final class AppEnvironment: ObservableObject {
    let metricsService: MetricsService
    let actionsService: ActionsService
    let browserService: BrowserService
    let cleanerService: CleanerService
    let auditLogService: AuditLogService
    let permissionManager: PermissionManager
    let fileAccessManager: FileAccessManager

    init() {
        self.metricsService = MetricsService()
        self.actionsService = ActionsService()
        self.browserService = BrowserService()
        self.cleanerService = CleanerService()
        self.auditLogService = AuditLogService()
        self.permissionManager = PermissionManager()
        self.fileAccessManager = FileAccessManager()
    }
}
```

### MetricsService

**Purpose:** System and per-process metrics using native APIs only.

```swift
// Core/Services/MetricsService.swift

@MainActor
final class MetricsService: ObservableObject {

    // MARK: - Published State
    @Published private(set) var cpuMetrics: CPUMetrics?
    @Published private(set) var memoryMetrics: MemoryMetrics?
    @Published private(set) var diskMetrics: DiskMetrics?
    @Published private(set) var networkMetrics: NetworkMetrics?
    @Published private(set) var memoryPressure: MemoryPressureLevel = .normal
    @Published private(set) var runningApps: [AppInfo] = []

    // MARK: - Native API Implementation

    /// CPU metrics via host_processor_info
    func fetchCPUMetrics() async -> CPUMetrics

    /// Memory metrics via vm_statistics64 + sysctl
    func fetchMemoryMetrics() async -> MemoryMetrics

    /// Disk metrics via FileManager.attributesOfFileSystem
    func fetchDiskMetrics() async -> DiskMetrics

    /// Network metrics via getifaddrs
    func fetchNetworkMetrics() async -> NetworkMetrics

    /// Memory pressure via DispatchSource.makeMemoryPressureSource
    func startMemoryPressureMonitoring()

    /// Running apps via NSWorkspace.shared.runningApplications
    func fetchRunningApps() -> [AppInfo]

    /// Per-process resource usage via proc_pid_rusage (where available)
    func fetchProcessResourceUsage(pid: pid_t) -> ProcessResourceUsage?
}
```

**Native APIs Used:**
| API | Purpose | Sandbox Safe |
|-----|---------|--------------|
| `host_processor_info()` | CPU metrics | Yes |
| `host_statistics64()` | Memory stats | Yes |
| `sysctl()` | System info | Yes |
| `getifaddrs()` | Network stats | Yes |
| `FileManager.attributesOfFileSystem()` | Disk stats | Yes |
| `DispatchSource.makeMemoryPressureSource()` | Pressure events | Yes |
| `NSWorkspace.shared.runningApplications` | App list | Yes |
| `proc_pid_rusage()` | Process resources | Partial |

### ActionsService

**Purpose:** Execute user actions with proper permission checks and audit logging.

```swift
// Core/Services/ActionsService.swift

@MainActor
final class ActionsService: ObservableObject {

    private let auditLog: AuditLogService
    private let permissions: PermissionManager

    // MARK: - App Lifecycle Actions

    /// Terminate app gracefully via NSRunningApplication
    func quitApp(_ app: NSRunningApplication) async -> ActionResult {
        auditLog.log(.appQuit, target: app.localizedName ?? "Unknown")

        let success = app.terminate()
        return ActionResult(success: success, action: .appQuit)
    }

    /// Force terminate via NSRunningApplication (no shell)
    func forceQuitApp(_ app: NSRunningApplication) async -> ActionResult {
        auditLog.log(.appForceQuit, target: app.localizedName ?? "Unknown")

        let success = app.forceTerminate()
        return ActionResult(success: success, action: .appForceQuit)
    }

    /// Quit app via AppleScript (requires Automation permission)
    func quitAppViaScript(_ bundleId: String) async -> ActionResult {
        guard await permissions.checkAutomation(for: bundleId) == .granted else {
            return ActionResult(success: false, error: .permissionDenied)
        }

        // Execute AppleScript quit command
        let script = "tell application id \"\(bundleId)\" to quit"
        return await executeAppleScript(script, action: .appQuit)
    }

    // MARK: - System Actions

    /// Open Activity Monitor
    func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    /// Open Force Quit dialog
    func openForceQuitDialog() {
        // Cmd+Opt+Esc equivalent
        let script = "tell application \"System Events\" to key code 53 using {command down, option down}"
        // Note: Requires System Events automation permission
    }

    /// Show instructions for terminal command (DevID features)
    func showTerminalInstructions(for command: String) -> InstructionSet
}
```

### BrowserService

**Purpose:** Browser tab management via Apple Events.

```swift
// Core/Services/BrowserService.swift

@MainActor
final class BrowserService: ObservableObject {

    @Published private(set) var installedBrowsers: [Browser] = []
    @Published private(set) var runningBrowsers: [Browser] = []
    @Published private(set) var tabsByBrowser: [Browser: [BrowserTab]] = [:]
    @Published private(set) var permissionStatus: [Browser: PermissionState] = [:]

    private let permissions: PermissionManager
    private let auditLog: AuditLogService

    // MARK: - Browser Detection

    /// Detect installed browsers via NSWorkspace
    func detectInstalledBrowsers() {
        let browserBundleIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser",
            "org.mozilla.firefox"
        ]

        installedBrowsers = browserBundleIds.compactMap { bundleId in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
                .map { Browser(bundleId: bundleId, url: $0) }
        }
    }

    /// Check which browsers are running
    func updateRunningBrowsers() {
        runningBrowsers = installedBrowsers.filter { browser in
            NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == browser.bundleId
            }
        }
    }

    // MARK: - Tab Operations (Automation Permission Required)

    /// Fetch tabs for a browser
    /// Returns .permissionRequired if automation not granted
    func fetchTabs(for browser: Browser) async -> Result<[BrowserTab], BrowserError> {
        guard await permissions.checkAutomation(for: browser.bundleId) == .granted else {
            return .failure(.permissionRequired(browser))
        }

        // Execute browser-specific AppleScript
        let script = tabEnumerationScript(for: browser)
        return await executeTabScript(script, browser: browser)
    }

    /// Close a specific tab
    func closeTab(_ tab: BrowserTab) async -> Result<Void, BrowserError> {
        guard await permissions.checkAutomation(for: tab.browser.bundleId) == .granted else {
            return .failure(.permissionRequired(tab.browser))
        }

        auditLog.log(.tabClosed, target: "\(tab.browser.name): \(tab.title)")

        let script = tabCloseScript(for: tab)
        return await executeTabScript(script, browser: tab.browser).map { _ in () }
    }

    /// Close tabs by domain
    func closeTabsByDomain(_ domain: String, in browser: Browser) async -> Result<Int, BrowserError>

    /// Close all tabs (with confirmation)
    func closeAllTabs(in browser: Browser, confirmed: Bool) async -> Result<Int, BrowserError>

    // MARK: - Permission Handling

    /// Request automation permission with UI explanation
    func requestPermission(for browser: Browser) async -> PermissionState {
        // Show explanation first
        // Then trigger permission prompt
        return await permissions.requestAutomation(for: browser.bundleId)
    }
}
```

### CleanerService

**Purpose:** User-scoped cleaning with security-scoped bookmarks.

```swift
// Core/Services/CleanerService.swift

@MainActor
final class CleanerService: ObservableObject {

    @Published private(set) var authorizedFolders: [AuthorizedFolder] = []
    @Published private(set) var lastScanResults: ScanResults?

    private let fileAccess: FileAccessManager
    private let auditLog: AuditLogService

    // MARK: - Folder Authorization

    /// Present folder picker and store security-scoped bookmark
    func authorizeFolder(suggestedPath: String? = nil) async -> AuthorizedFolder? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to enable cleanup"

        if let suggestedPath = suggestedPath {
            panel.directoryURL = URL(fileURLWithPath: suggestedPath)
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        // Create and store security-scoped bookmark
        return await fileAccess.createBookmark(for: url)
    }

    /// Remove authorization for a folder
    func revokeAuthorization(for folder: AuthorizedFolder) {
        fileAccess.removeBookmark(for: folder)
        authorizedFolders.removeAll { $0.id == folder.id }
    }

    // MARK: - Dry Run (Preview)

    /// Scan folder and calculate what would be cleaned
    /// Does NOT delete anything
    func dryRun(in folder: AuthorizedFolder, options: CleanOptions) async -> ScanResults {
        guard fileAccess.startAccessing(folder) else {
            return ScanResults(error: .accessDenied)
        }
        defer { fileAccess.stopAccessing(folder) }

        var results = ScanResults()
        let fileManager = FileManager.default

        // Enumerate files matching options
        if let enumerator = fileManager.enumerator(at: folder.url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if shouldInclude(fileURL, options: options) {
                    let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    results.files.append(FileInfo(url: fileURL, size: UInt64(size ?? 0)))
                    results.totalSize += UInt64(size ?? 0)
                }
            }
        }

        lastScanResults = results
        return results
    }

    // MARK: - Cleanup Execution

    /// Execute cleanup after user confirmation
    /// Requires prior dryRun results
    func executeCleanup(results: ScanResults, confirmed: Bool) async -> CleanupResult {
        guard confirmed else {
            return CleanupResult(error: .notConfirmed)
        }

        guard let folder = results.folder else {
            return CleanupResult(error: .noFolder)
        }

        guard fileAccess.startAccessing(folder) else {
            return CleanupResult(error: .accessDenied)
        }
        defer { fileAccess.stopAccessing(folder) }

        auditLog.log(.cleanupStarted, target: folder.url.path, metadata: [
            "fileCount": "\(results.files.count)",
            "totalSize": "\(results.totalSize)"
        ])

        var deleted = 0
        var failed = 0
        var errors: [CleanupError] = []

        for file in results.files {
            do {
                try FileManager.default.removeItem(at: file.url)
                deleted += 1
            } catch {
                failed += 1
                errors.append(.deleteFailed(file.url, error))
            }
        }

        let result = CleanupResult(
            deletedCount: deleted,
            failedCount: failed,
            freedSpace: results.totalSize,
            errors: errors
        )

        auditLog.log(.cleanupCompleted, target: folder.url.path, metadata: [
            "deleted": "\(deleted)",
            "failed": "\(failed)",
            "freedSpace": "\(results.totalSize)"
        ])

        return result
    }

    // MARK: - Preset Cleanup Targets

    /// Suggested folders for common cleanup scenarios
    static let presetTargets: [CleanupPreset] = [
        CleanupPreset(
            name: "User Caches",
            suggestedPath: "~/Library/Caches",
            description: "Application cache files",
            estimatedSavings: "1-10 GB typical"
        ),
        CleanupPreset(
            name: "User Logs",
            suggestedPath: "~/Library/Logs",
            description: "Application log files",
            estimatedSavings: "100 MB - 1 GB typical"
        ),
        CleanupPreset(
            name: "Xcode Derived Data",
            suggestedPath: "~/Library/Developer/Xcode/DerivedData",
            description: "Xcode build caches",
            estimatedSavings: "5-50 GB typical for developers"
        ),
        CleanupPreset(
            name: "Downloads",
            suggestedPath: "~/Downloads",
            description: "Downloaded files",
            estimatedSavings: "Varies"
        )
    ]
}
```

### AuditLogService

**Purpose:** Append-only audit log for all actions.

```swift
// Core/Services/AuditLogService.swift

@MainActor
final class AuditLogService: ObservableObject {

    @Published private(set) var recentEntries: [AuditEntry] = []

    private let store: LogStore
    private let maxRecentEntries = 100

    init(store: LogStore = SQLiteLogStore()) {
        self.store = store
    }

    // MARK: - Logging

    /// Log an action with optional metadata
    func log(_ action: AuditAction, target: String, metadata: [String: String] = [:]) {
        let entry = AuditEntry(
            id: UUID(),
            timestamp: Date(),
            action: action,
            target: target,
            metadata: metadata,
            success: true
        )

        Task {
            await store.append(entry)
        }

        recentEntries.insert(entry, at: 0)
        if recentEntries.count > maxRecentEntries {
            recentEntries.removeLast()
        }
    }

    /// Log an error
    func logError(_ action: AuditAction, target: String, error: Error) {
        let entry = AuditEntry(
            id: UUID(),
            timestamp: Date(),
            action: action,
            target: target,
            metadata: ["error": error.localizedDescription],
            success: false
        )

        Task {
            await store.append(entry)
        }

        recentEntries.insert(entry, at: 0)
    }

    // MARK: - Export

    /// Export log as JSON for user review
    func exportLog(from startDate: Date? = nil) async -> Data? {
        let entries = await store.fetch(from: startDate)
        return try? JSONEncoder().encode(entries)
    }
}

// MARK: - Audit Types

enum AuditAction: String, Codable {
    case appQuit = "app.quit"
    case appForceQuit = "app.force_quit"
    case tabClosed = "browser.tab.closed"
    case tabsClosedByDomain = "browser.tabs.closed_by_domain"
    case cleanupStarted = "cleanup.started"
    case cleanupCompleted = "cleanup.completed"
    case permissionRequested = "permission.requested"
    case permissionGranted = "permission.granted"
    case permissionDenied = "permission.denied"
    case folderAuthorized = "folder.authorized"
    case folderRevoked = "folder.revoked"
    case settingChanged = "setting.changed"
}

struct AuditEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let action: AuditAction
    let target: String
    let metadata: [String: String]
    let success: Bool
}
```

---

## C3. Permission Gateways

### PermissionManager

**Purpose:** Central permission state management.

```swift
// Core/Permissions/PermissionManager.swift

@MainActor
final class PermissionManager: ObservableObject {

    @Published private(set) var automationStatus: [String: PermissionState] = [:]
    @Published private(set) var accessibilityStatus: PermissionState = .unknown
    @Published private(set) var fullDiskAccessStatus: PermissionState = .unknown

    // MARK: - Automation Permissions

    /// Check automation permission for a specific app
    func checkAutomation(for bundleId: String) async -> PermissionState {
        // Execute minimal AppleScript to test permission
        let script = "tell application id \"\(bundleId)\" to return name"

        guard let appleScript = NSAppleScript(source: script) else {
            return .unknown
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error = error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 || code == -10004 {
                automationStatus[bundleId] = .denied
                return .denied
            }
        }

        automationStatus[bundleId] = .granted
        return .granted
    }

    /// Request automation permission (triggers system prompt)
    func requestAutomation(for bundleId: String) async -> PermissionState {
        // First, check if already granted
        let current = await checkAutomation(for: bundleId)
        if current == .granted {
            return .granted
        }

        // Execute a script that will trigger the system prompt
        let script = "tell application id \"\(bundleId)\" to return name"
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)

        // Re-check after prompt
        return await checkAutomation(for: bundleId)
    }

    // MARK: - Accessibility Permission

    /// Check if app is trusted for accessibility
    func checkAccessibility() -> PermissionState {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .granted : .denied
        return accessibilityStatus
    }

    /// Request accessibility permission (opens System Settings)
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Full Disk Access

    /// Check Full Disk Access (heuristic-based)
    func checkFullDiskAccess() -> PermissionState {
        // Try to read a protected file
        let testPath = NSHomeDirectory() + "/Library/Safari/History.db"
        let accessible = FileManager.default.isReadableFile(atPath: testPath)
        fullDiskAccessStatus = accessible ? .granted : .denied
        return fullDiskAccessStatus
    }

    // MARK: - Settings URLs

    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}

enum PermissionState: String {
    case unknown
    case granted
    case denied
    case notDetermined
}
```

### FileAccessManager

**Purpose:** Security-scoped bookmark management.

```swift
// Core/Permissions/FileAccessManager.swift

@MainActor
final class FileAccessManager: ObservableObject {

    @Published private(set) var authorizedFolders: [AuthorizedFolder] = []

    private let bookmarkKey = "SecurityScopedBookmarks"
    private var activeAccess: Set<UUID> = []

    init() {
        loadBookmarks()
    }

    // MARK: - Bookmark Management

    /// Create and store a security-scoped bookmark
    func createBookmark(for url: URL) async -> AuthorizedFolder? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let folder = AuthorizedFolder(
                id: UUID(),
                url: url,
                bookmarkData: bookmarkData,
                createdAt: Date()
            )

            authorizedFolders.append(folder)
            saveBookmarks()

            return folder
        } catch {
            return nil
        }
    }

    /// Remove a bookmark
    func removeBookmark(for folder: AuthorizedFolder) {
        stopAccessing(folder)
        authorizedFolders.removeAll { $0.id == folder.id }
        saveBookmarks()
    }

    // MARK: - Access Control

    /// Start accessing a security-scoped resource
    func startAccessing(_ folder: AuthorizedFolder) -> Bool {
        guard !activeAccess.contains(folder.id) else { return true }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }

        if isStale {
            // Bookmark is stale, need to re-authorize
            return false
        }

        if url.startAccessingSecurityScopedResource() {
            activeAccess.insert(folder.id)
            return true
        }

        return false
    }

    /// Stop accessing a security-scoped resource
    func stopAccessing(_ folder: AuthorizedFolder) {
        guard activeAccess.contains(folder.id) else { return }

        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            url.stopAccessingSecurityScopedResource()
        }

        activeAccess.remove(folder.id)
    }

    // MARK: - Persistence

    private func saveBookmarks() {
        let data = authorizedFolders.compactMap { folder -> [String: Any]? in
            return [
                "id": folder.id.uuidString,
                "bookmark": folder.bookmarkData,
                "createdAt": folder.createdAt
            ]
        }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.array(forKey: bookmarkKey) as? [[String: Any]] else {
            return
        }

        authorizedFolders = data.compactMap { dict -> AuthorizedFolder? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let bookmarkData = dict["bookmark"] as? Data,
                  let createdAt = dict["createdAt"] as? Date else {
                return nil
            }

            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale else {
                return nil
            }

            return AuthorizedFolder(
                id: id,
                url: url,
                bookmarkData: bookmarkData,
                createdAt: createdAt
            )
        }
    }
}

struct AuthorizedFolder: Identifiable {
    let id: UUID
    let url: URL
    let bookmarkData: Data
    let createdAt: Date

    var name: String { url.lastPathComponent }
    var path: String { url.path }
}
```

---

## C4. Command Abstraction (Minimized)

For MAS, we eliminate most shell command execution. For Developer ID builds, we maintain a restricted command engine.

### Restricted Command Engine (Developer ID Only)

```swift
// Core/Execution/RestrictedCommandEngine.swift
// ONLY included in Developer ID builds

#if DEVELOPER_ID_BUILD

@MainActor
final class RestrictedCommandEngine {

    /// Whitelist of allowed commands with absolute paths
    private static let allowedCommands: [String: CommandSpec] = [
        "sync": CommandSpec(path: "/bin/sync", requiresAuth: false),
        "purge": CommandSpec(path: "/usr/bin/purge", requiresAuth: true),
        // Note: kill/killall removed - use NSRunningApplication instead
    ]

    /// Execute a whitelisted command
    func execute(_ commandId: String, arguments: [String] = []) async -> CommandResult {
        guard let spec = Self.allowedCommands[commandId] else {
            return CommandResult(success: false, error: .commandNotAllowed)
        }

        // Verify binary exists
        guard FileManager.default.fileExists(atPath: spec.path) else {
            return CommandResult(success: false, error: .binaryNotFound)
        }

        // Validate arguments (no injection)
        guard arguments.allSatisfy({ isValidArgument($0) }) else {
            return CommandResult(success: false, error: .invalidArguments)
        }

        if spec.requiresAuth {
            return await executeWithAuthorization(spec, arguments: arguments)
        } else {
            return await executeDirectly(spec, arguments: arguments)
        }
    }

    private func isValidArgument(_ arg: String) -> Bool {
        // Reject shell metacharacters
        let forbidden: CharacterSet = CharacterSet(charactersIn: ";|&`$(){}[]<>\\\"'")
        return arg.rangeOfCharacter(from: forbidden) == nil
    }

    private func executeDirectly(_ spec: CommandSpec, arguments: [String]) async -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: spec.path)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            return CommandResult(
                success: process.terminationStatus == 0,
                output: output,
                errorOutput: errorOutput,
                exitCode: process.terminationStatus
            )
        } catch {
            return CommandResult(success: false, error: .executionFailed(error))
        }
    }

    private func executeWithAuthorization(_ spec: CommandSpec, arguments: [String]) async -> CommandResult {
        // Use Authorization Services for elevated execution
        // This is Developer ID only - not available in MAS
        // Implementation details in PrivilegeService
        fatalError("Not implemented - use PrivilegeService for authorized execution")
    }
}

struct CommandSpec {
    let path: String
    let requiresAuth: Bool
}

struct CommandResult {
    let success: Bool
    var output: String = ""
    var errorOutput: String = ""
    var exitCode: Int32 = 0
    var error: CommandError?
}

enum CommandError: Error {
    case commandNotAllowed
    case binaryNotFound
    case invalidArguments
    case executionFailed(Error)
    case authorizationDenied
}

#endif
```

---

## Module Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                       UI Layer                              │
│  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌──────────────────┐ │
│  │Dashboard│ │ Process  │ │ Browser │ │     Cleanup      │ │
│  │  View   │ │  View    │ │  View   │ │      View        │ │
│  └────┬────┘ └────┬─────┘ └────┬────┘ └────────┬─────────┘ │
└───────┼───────────┼────────────┼───────────────┼───────────┘
        │           │            │               │
        ▼           ▼            ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                            │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │ Metrics │ │ Actions │ │ Browser │ │ Cleaner │           │
│  │ Service │ │ Service │ │ Service │ │ Service │           │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘           │
└───────┼───────────┼────────────┼───────────┼───────────────┘
        │           │            │           │
        │           ▼            ▼           │
        │     ┌───────────────────────┐      │
        │     │   PermissionManager   │◄─────┤
        │     └───────────────────────┘      │
        │           │            │           │
        ▼           ▼            ▼           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Foundation Layer                           │
│  ┌──────────────┐ ┌─────────────────┐ ┌──────────────────┐ │
│  │ AuditLog     │ │ FileAccess      │ │ Native APIs      │ │
│  │ Service      │ │ Manager         │ │ (Mach/Darwin)    │ │
│  └──────────────┘ └─────────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Build Configuration

### MAS Build

```swift
// In project settings or Package.swift
#if MAS_BUILD
    // Exclude: RestrictedCommandEngine, PrivilegeService, CraigOCleanHelper
    // Include: All sandbox-compatible services
#endif
```

### Developer ID Build

```swift
#if DEVELOPER_ID_BUILD
    // Include: All MAS features + RestrictedCommandEngine + PrivilegeService
    // Optionally include: CraigOCleanHelper for elevated operations
#endif
```

### Feature Flags

```swift
struct FeatureFlags {
    static let memoryPurgeEnabled: Bool = {
        #if DEVELOPER_ID_BUILD
        return true
        #else
        return false
        #endif
    }()

    static let systemRestartEnabled: Bool = {
        #if DEVELOPER_ID_BUILD
        return true
        #else
        return false
        #endif
    }()

    static let advancedCleanupEnabled: Bool = {
        #if DEVELOPER_ID_BUILD
        return true
        #else
        return false
        #endif
    }()
}
```

---

## Next Steps

1. Review Implementation Plan (IMPLEMENTATION_PLAN.md)
2. Begin Slice 1 implementation
3. Set up test infrastructure
