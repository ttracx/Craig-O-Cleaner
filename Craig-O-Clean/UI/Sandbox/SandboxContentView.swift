// MARK: - SandboxContentView.swift
// Craig-O-Clean - Main Content View for Sandbox-Compliant App
// Integrates all sandbox services with the UI

import SwiftUI

/// Main content view for the sandbox-compliant Craig-O-Clean app
struct SandboxContentView: View {
    @EnvironmentObject var environment: SandboxAppEnvironment

    @State private var selectedTab: SandboxTab = .dashboard
    @State private var showingPermissions = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                Section("Overview") {
                    Label("Dashboard", systemImage: "gauge.medium")
                        .tag(SandboxTab.dashboard)
                }

                Section("Management") {
                    Label("Processes", systemImage: "cpu")
                        .tag(SandboxTab.processes)

                    Label("Browser Tabs", systemImage: "safari")
                        .tag(SandboxTab.browser)

                    Label("Cleanup", systemImage: "trash")
                        .tag(SandboxTab.cleanup)
                }

                Section("Settings") {
                    Label("Permissions", systemImage: "lock.shield")
                        .tag(SandboxTab.permissions)

                    Label("Activity Log", systemImage: "list.bullet.rectangle")
                        .tag(SandboxTab.activityLog)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            // Main content
            switch selectedTab {
            case .dashboard:
                SandboxDashboardView()
                    .environmentObject(environment.processManager)
                    .environmentObject(environment.permissionManager)
                    .environmentObject(environment.notificationService)

            case .processes:
                SandboxProcessListView()
                    .environmentObject(environment.processManager)
                    .environmentObject(environment.actionsService)
                    .environmentObject(environment.auditLog)

            case .browser:
                SandboxBrowserTabsView()
                    .environmentObject(environment.browserService)
                    .environmentObject(environment.permissionManager)
                    .environmentObject(environment.auditLog)

            case .cleanup:
                SandboxCleanupView()
                    .environmentObject(environment.cleanerService)
                    .environmentObject(environment.fileAccessManager)
                    .environmentObject(environment.auditLog)

            case .permissions:
                PermissionStatusView(permissionManager: environment.permissionManager)

            case .activityLog:
                SandboxActivityLogView()
                    .environmentObject(environment.auditLog)
            }
        }
        .navigationTitle(selectedTab.title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingPermissions.toggle() }) {
                    Image(systemName: permissionStatusIcon)
                        .foregroundColor(permissionStatusColor)
                }
                .help("Permission Status")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: refreshAll) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh All")
            }
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionStatusView(permissionManager: environment.permissionManager)
                .frame(width: 450, height: 500)
        }
        .onAppear {
            environment.startServices()
        }
        .onDisappear {
            environment.stopServices()
        }
    }

    // MARK: - Computed Properties

    private var permissionStatusIcon: String {
        let summary = environment.permissionManager.getSummary()
        if summary.anyDenied {
            return "exclamationmark.shield"
        } else if summary.allGranted {
            return "checkmark.shield"
        } else {
            return "questionmark.shield"
        }
    }

    private var permissionStatusColor: Color {
        let summary = environment.permissionManager.getSummary()
        if summary.anyDenied {
            return .red
        } else if summary.allGranted {
            return .green
        } else {
            return .yellow
        }
    }

    // MARK: - Actions

    private func refreshAll() {
        Task {
            await environment.refreshAll()
        }
    }
}

// MARK: - Tab Enum

enum SandboxTab: String, Hashable, CaseIterable {
    case dashboard
    case processes
    case browser
    case cleanup
    case permissions
    case activityLog

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .processes: return "Process Manager"
        case .browser: return "Browser Tabs"
        case .cleanup: return "Cleanup"
        case .permissions: return "Permissions"
        case .activityLog: return "Activity Log"
        }
    }
}

// MARK: - Dashboard View

struct SandboxDashboardView: View {
    @EnvironmentObject var processManager: SandboxProcessManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Running Apps",
                        value: "\(processManager.runningApps.count)",
                        icon: "app.badge",
                        color: .blue
                    )

                    StatCard(
                        title: "Memory Heavy",
                        value: "\(processManager.heavyApps.count)",
                        icon: "memorychip",
                        color: processManager.heavyApps.isEmpty ? .green : .orange
                    )

                    StatCard(
                        title: "Permissions",
                        value: permissionStatusText,
                        icon: "shield.checkered",
                        color: permissionStatusColor
                    )
                }
                .padding(.horizontal)

                // Quick actions
                GroupBox("Quick Actions") {
                    HStack(spacing: 16) {
                        QuickActionButton(
                            title: "Close Heavy Apps",
                            icon: "xmark.app",
                            color: .orange
                        ) {
                            Task {
                                _ = await processManager.quitHeavyApps()
                            }
                        }
                        .disabled(processManager.heavyApps.isEmpty)

                        QuickActionButton(
                            title: "Refresh All",
                            icon: "arrow.clockwise",
                            color: .blue
                        ) {
                            processManager.refreshApps()
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)

                // Heavy apps list
                if !processManager.heavyApps.isEmpty {
                    GroupBox("Memory Heavy Apps") {
                        VStack(spacing: 8) {
                            ForEach(processManager.heavyApps.prefix(5)) { app in
                                HStack {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    }

                                    Text(app.name)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(app.formattedMemory)
                                        .foregroundColor(.secondary)

                                    Button("Quit") {
                                        Task {
                                            _ = await processManager.quitApp(app)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
    }

    private var permissionStatusText: String {
        let summary = permissionManager.getSummary()
        let granted = summary.automationBrowsers.filter { $0.state == .granted }.count
        let total = summary.automationBrowsers.count
        return "\(granted)/\(total + 2)" // +2 for accessibility and FDA
    }

    private var permissionStatusColor: Color {
        let summary = permissionManager.getSummary()
        if summary.anyDenied {
            return .red
        } else if summary.allGranted {
            return .green
        } else {
            return .yellow
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
}

// MARK: - Process List View

struct SandboxProcessListView: View {
    @EnvironmentObject var processManager: SandboxProcessManager
    @EnvironmentObject var actionsService: ActionsService
    @EnvironmentObject var auditLog: AuditLogService

    @State private var searchText = ""
    @State private var sortOrder: ProcessSortOrder = .memory
    @State private var showingConfirmation = false
    @State private var selectedApp: AppInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Picker("Sort by", selection: $sortOrder) {
                    Text("Memory").tag(ProcessSortOrder.memory)
                    Text("Name").tag(ProcessSortOrder.name)
                    Text("CPU").tag(ProcessSortOrder.cpu)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer()

                Button(action: { processManager.refreshApps() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding()

            Divider()

            // Process list
            List(filteredAndSortedApps) { app in
                ProcessRowView(app: app) {
                    selectedApp = app
                    showingConfirmation = true
                }
            }
            .listStyle(.inset)
        }
        .confirmationDialog(
            "Quit \(selectedApp?.name ?? "app")?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Quit") {
                if let app = selectedApp {
                    Task {
                        _ = await processManager.quitApp(app)
                    }
                }
            }
            Button("Force Quit", role: .destructive) {
                if let app = selectedApp {
                    Task {
                        _ = await processManager.forceQuitApp(app)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unsaved changes will be lost.")
        }
    }

    private var filteredAndSortedApps: [AppInfo] {
        var apps = processManager.runningApps

        if !searchText.isEmpty {
            apps = apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOrder {
        case .memory:
            apps.sort { $0.memoryUsage > $1.memoryUsage }
        case .name:
            apps.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .cpu:
            apps.sort { $0.cpuUsage > $1.cpuUsage }
        }

        return apps
    }
}

enum ProcessSortOrder: String, CaseIterable {
    case memory, name, cpu
}

struct ProcessRowView: View {
    let app: AppInfo
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app")
                    .font(.title)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)

                Text(app.bundleIdentifier ?? "Unknown bundle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(app.formattedMemory)
                    .font(.system(.body, design: .monospaced))

                if app.cpuUsage > 0 {
                    Text(String(format: "%.1f%% CPU", app.cpuUsage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button("Quit", action: onQuit)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Browser Tabs View

struct SandboxBrowserTabsView: View {
    @EnvironmentObject var browserService: SandboxBrowserService
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var auditLog: AuditLogService

    @State private var selectedBrowser: Browser?

    var body: some View {
        VStack(spacing: 0) {
            // Browser selector
            HStack {
                ForEach(browserService.installedBrowsers, id: \.self) { browser in
                    BrowserPillButton(
                        browser: browser,
                        isSelected: selectedBrowser == browser,
                        hasPermission: browserService.permissionStatus[browser] == .granted,
                        tabCount: browserService.tabs[browser]?.count ?? 0
                    ) {
                        selectedBrowser = browser
                    }
                }

                Spacer()

                Button(action: refreshTabs) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh tabs")
            }
            .padding()

            Divider()

            if let browser = selectedBrowser {
                if browserService.permissionStatus[browser] == .granted {
                    // Tab list
                    if let tabs = browserService.tabs[browser], !tabs.isEmpty {
                        List(tabs) { tab in
                            TabRowView(tab: tab) {
                                Task {
                                    _ = await browserService.closeTab(tab)
                                }
                            }
                        }
                        .listStyle(.inset)
                    } else {
                        ContentUnavailableView(
                            "No Tabs",
                            systemImage: "rectangle.on.rectangle.slash",
                            description: Text("No tabs found in \(browser.displayName)")
                        )
                    }
                } else {
                    // Permission needed
                    ContentUnavailableView(
                        "Permission Required",
                        systemImage: "lock.shield",
                        description: Text("Enable automation permission for \(browser.displayName) to manage tabs")
                    )
                    .overlay(alignment: .bottom) {
                        Button("Request Permission") {
                            Task {
                                _ = await browserService.requestPermission(for: browser)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Browser",
                    systemImage: "safari",
                    description: Text("Choose a browser above to view and manage tabs")
                )
            }
        }
        .onAppear {
            if selectedBrowser == nil, let first = browserService.installedBrowsers.first {
                selectedBrowser = first
            }
        }
    }

    private func refreshTabs() {
        Task {
            await browserService.fetchAllTabs()
        }
    }
}

struct BrowserPillButton: View {
    let browser: Browser
    let isSelected: Bool
    let hasPermission: Bool
    let tabCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: browser.iconName)

                Text(browser.displayName)

                if hasPermission {
                    Text("\(tabCount)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Image(systemName: "lock")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
    }
}

struct TabRowView: View {
    let tab: Tab
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .lineLimit(1)

                Text(tab.urlHost)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cleanup View

struct SandboxCleanupView: View {
    @EnvironmentObject var cleanerService: CleanerService
    @EnvironmentObject var fileAccessManager: FileAccessManager
    @EnvironmentObject var auditLog: AuditLogService

    @State private var selectedPreset: CleanupPreset?
    @State private var showingScanResults = false

    var body: some View {
        HSplitView {
            // Presets list
            VStack(alignment: .leading, spacing: 0) {
                Text("Cleanup Presets")
                    .font(.headline)
                    .padding()

                List(FileAccessManager.defaultPresets) { preset in
                    PresetRowView(
                        preset: preset,
                        isAuthorized: cleanerService.isPresetAuthorized(preset) != nil,
                        isSelected: selectedPreset?.id == preset.id
                    ) {
                        selectedPreset = preset
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 250, maxWidth: 300)

            // Preset details / scan results
            if let preset = selectedPreset {
                PresetDetailView(
                    preset: preset,
                    authorizedFolder: cleanerService.isPresetAuthorized(preset),
                    scanResults: cleanerService.lastScanResults,
                    isScanning: cleanerService.isScanning,
                    isCleaning: cleanerService.isCleaning,
                    onAuthorize: {
                        Task {
                            _ = await cleanerService.authorizePreset(preset)
                        }
                    },
                    onScan: { folder in
                        Task {
                            _ = await cleanerService.dryRun(folder: folder)
                        }
                    },
                    onClean: { results in
                        Task {
                            _ = await cleanerService.executeCleanup(scanResults: results, confirmed: true)
                        }
                    }
                )
            } else {
                ContentUnavailableView(
                    "Select a Preset",
                    systemImage: "folder.badge.gearshape",
                    description: Text("Choose a cleanup preset from the list")
                )
            }
        }
    }
}

struct PresetRowView: View {
    let preset: CleanupPreset
    let isAuthorized: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .foregroundColor(riskColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .fontWeight(isSelected ? .semibold : .regular)

                    Text(preset.estimatedSavings)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var riskColor: Color {
        switch preset.riskLevel {
        case .safe: return .green
        case .moderate: return .yellow
        case .caution: return .orange
        }
    }
}

struct PresetDetailView: View {
    let preset: CleanupPreset
    let authorizedFolder: AuthorizedFolder?
    let scanResults: ScanResults?
    let isScanning: Bool
    let isCleaning: Bool
    let onAuthorize: () -> Void
    let onScan: (AuthorizedFolder) -> Void
    let onClean: (ScanResults) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: preset.icon)
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading) {
                        Text(preset.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(preset.description)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Path info
                GroupBox("Location") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(preset.expandedPath, systemImage: "folder")
                            .font(.system(.body, design: .monospaced))

                        if authorizedFolder != nil {
                            Label("Authorized", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Not Authorized", systemImage: "lock.shield")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                // Actions
                if let folder = authorizedFolder {
                    if let results = scanResults, results.folder?.id == folder.id {
                        // Show scan results
                        GroupBox("Scan Results") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("\(results.fileCount) files", systemImage: "doc.on.doc")
                                    Spacer()
                                    Text(formatBytes(results.totalSize))
                                        .fontWeight(.semibold)
                                }

                                if !results.files.isEmpty {
                                    Divider()

                                    ForEach(results.files.prefix(10)) { file in
                                        HStack {
                                            Text(file.name)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(formatBytes(file.size))
                                                .foregroundColor(.secondary)
                                        }
                                        .font(.caption)
                                    }

                                    if results.files.count > 10 {
                                        Text("... and \(results.files.count - 10) more files")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                        }

                        HStack {
                            Button("Scan Again") {
                                onScan(folder)
                            }
                            .disabled(isScanning)

                            Spacer()

                            Button("Delete \(results.fileCount) Files") {
                                onClean(results)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(results.files.isEmpty || isCleaning)
                        }
                    } else {
                        // Ready to scan
                        Button("Scan for Files") {
                            onScan(folder)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isScanning)

                        if isScanning {
                            ProgressView("Scanning...")
                        }
                    }
                } else {
                    // Need authorization
                    Button("Authorize Access") {
                        onAuthorize()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Activity Log View

struct SandboxActivityLogView: View {
    @EnvironmentObject var auditLog: AuditLogService

    @State private var filterAction: AuditAction?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Picker("Filter", selection: $filterAction) {
                    Text("All Actions").tag(nil as AuditAction?)
                    Divider()
                    ForEach(AuditAction.allCases, id: \.self) { action in
                        Text(action.rawValue).tag(action as AuditAction?)
                    }
                }
                .frame(maxWidth: 150)

                Spacer()

                Button("Export") {
                    exportLogs()
                }
            }
            .padding()

            Divider()

            // Log entries
            if auditLog.recentEntries.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Actions will appear here as you use the app")
                )
            } else {
                List(filteredEntries) { entry in
                    LogEntryRowView(entry: entry)
                }
                .listStyle(.inset)
            }
        }
    }

    private var filteredEntries: [AuditEntry] {
        var entries = auditLog.recentEntries

        if let filter = filterAction {
            entries = entries.filter { $0.action == filter }
        }

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.target?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.action.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    private func exportLogs() {
        Task {
            if let url = await auditLog.exportLogToFile() {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}

struct LogEntryRowView: View {
    let entry: AuditEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.success ? "checkmark.circle" : "xmark.circle")
                .foregroundColor(entry.success ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.action.rawValue)
                    .fontWeight(.medium)

                if let target = entry.target {
                    Text(target)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct SandboxContentView_Previews: PreviewProvider {
    static var previews: some View {
        SandboxContentView()
            .environmentObject(SandboxAppEnvironment())
            .frame(width: 1000, height: 700)
    }
}
#endif
