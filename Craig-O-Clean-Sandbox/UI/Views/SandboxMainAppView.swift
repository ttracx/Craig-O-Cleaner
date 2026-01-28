// MARK: - SandboxMainAppView.swift
// Craig-O-Clean Sandbox Edition - Main Application View
// Primary navigation and content container

import SwiftUI

struct SandboxMainAppView: View {
    @EnvironmentObject var metricsProvider: SandboxMetricsProvider
    @EnvironmentObject var processManager: SandboxProcessManager
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager
    @EnvironmentObject var bookmarkManager: SecurityScopedBookmarkManager
    @EnvironmentObject var browserAutomation: SandboxBrowserAutomation

    @State private var selectedTab: SidebarTab = .dashboard
    @State private var showingOnboarding = false

    enum SidebarTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case processes = "Processes"
        case browserTabs = "Browser Tabs"
        case cleanup = "Cleanup"
        case permissions = "Permissions"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.33percent"
            case .processes: return "list.bullet.rectangle"
            case .browserTabs: return "safari"
            case .cleanup: return "trash"
            case .permissions: return "hand.raised"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarView
        } detail: {
            // Content
            contentView
        }
        .navigationTitle(selectedTab.rawValue)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Refresh button
                Button {
                    refreshCurrentView()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Permission status indicator
                if permissionsManager.permissionSummary.criticalMissing {
                    Button {
                        selectedTab = .permissions
                    } label: {
                        Label("Permissions", systemImage: "exclamationmark.triangle.fill")
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            checkFirstLaunch()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(onComplete: {
                showingOnboarding = false
            })
            .environmentObject(permissionsManager)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .dashboard:
            SandboxDashboardView()
                .environmentObject(metricsProvider)
                .environmentObject(processManager)
                .environmentObject(browserAutomation)
                .environmentObject(permissionsManager)

        case .processes:
            SandboxProcessListView()
                .environmentObject(processManager)

        case .browserTabs:
            SandboxBrowserTabsView()
                .environmentObject(browserAutomation)
                .environmentObject(permissionsManager)

        case .cleanup:
            SandboxCleanupView()
                .environmentObject(bookmarkManager)

        case .permissions:
            SandboxPermissionsView()
                .environmentObject(permissionsManager)
        }
    }

    // MARK: - Actions

    private func refreshCurrentView() {
        Task {
            switch selectedTab {
            case .dashboard:
                await metricsProvider.refreshAllMetrics()
                processManager.updateProcessList()
            case .processes:
                processManager.updateProcessList()
            case .browserTabs:
                await browserAutomation.fetchAllTabs()
            case .cleanup:
                // Cleanup view handles its own refresh
                break
            case .permissions:
                await permissionsManager.refreshAllPermissions()
            }
        }
    }

    private func checkFirstLaunch() {
        let hasShownOnboarding = UserDefaults.standard.bool(
            forKey: SandboxConfiguration.UserDefaultsKeys.hasShownPermissionOnboarding
        )

        if !hasShownOnboarding {
            showingOnboarding = true
            UserDefaults.standard.set(true, forKey: SandboxConfiguration.UserDefaultsKeys.hasShownPermissionOnboarding)
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [(title: String, description: String, icon: String)] = [
        (
            "Welcome to Craig-O-Clean",
            "A Mac App Store compliant utility for monitoring and optimizing your Mac's performance.",
            "sparkles"
        ),
        (
            "Monitor Your System",
            "Track CPU, memory, and disk usage in real-time using native macOS APIs.",
            "gauge.with.dots.needle.33percent"
        ),
        (
            "Manage Browser Tabs",
            "View and close heavy browser tabs to free up memory. Requires automation permission.",
            "safari"
        ),
        (
            "Safe File Cleanup",
            "Clean caches in folders you select. You always control what gets deleted.",
            "trash.circle"
        ),
        (
            "Privacy First",
            "We only access what you explicitly allow. No hidden actions, no surprises.",
            "hand.raised.fill"
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Page content
            VStack(spacing: 16) {
                Image(systemName: pages[currentPage].icon)
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text(pages[currentPage].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(pages[currentPage].description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .frame(width: 500, height: 450)
    }
}

// MARK: - Settings View

struct SandboxSettingsView: View {
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager
    @EnvironmentObject var bookmarkManager: SecurityScopedBookmarkManager

    var body: some View {
        TabView {
            // Permissions Tab
            SandboxPermissionsView()
                .environmentObject(permissionsManager)
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised")
                }

            // Bookmarks Tab
            BookmarksSettingsView()
                .environmentObject(bookmarkManager)
                .tabItem {
                    Label("Folders", systemImage: "folder")
                }

            // About Tab
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - Permissions View

struct SandboxPermissionsView: View {
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager

    var body: some View {
        Form {
            Section("Accessibility") {
                PermissionRow(
                    title: "Accessibility",
                    description: "Enables advanced app management",
                    status: permissionsManager.accessibilityStatus,
                    icon: "hand.raised.fill"
                ) {
                    permissionsManager.requestAccessibilityPermission()
                }
            }

            Section("Browser Automation") {
                ForEach(SandboxPermissionType.allCases.filter { $0 != .accessibility }) { type in
                    if let status = permissionsManager.automationStatus[type] {
                        PermissionRow(
                            title: type.rawValue,
                            description: type.description,
                            status: status,
                            icon: type.icon
                        ) {
                            Task {
                                _ = await permissionsManager.requestAutomationPermission(for: type)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Refresh All Permissions") {
                    Task {
                        await permissionsManager.refreshAllPermissions()
                    }
                }

                Button("Open System Settings") {
                    permissionsManager.openSystemSettings(for: .accessibility)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Permissions")
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let icon: String
    let onRequest: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(status.isGranted ? .green : .secondary)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if status.isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if status == .notInstalled {
                Text("Not Installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("Enable") {
                    onRequest()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Bookmarks Settings View

struct BookmarksSettingsView: View {
    @EnvironmentObject var bookmarkManager: SecurityScopedBookmarkManager

    var body: some View {
        Form {
            Section("Saved Folders") {
                if bookmarkManager.savedBookmarks.isEmpty {
                    Text("No folders added yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(bookmarkManager.savedBookmarks) { bookmark in
                        HStack {
                            Image(systemName: "folder")
                            VStack(alignment: .leading) {
                                Text(bookmark.name)
                                Text(bookmark.displayPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                bookmarkManager.deleteBookmark(bookmark)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button("Add Folder...") {
                    Task {
                        _ = await bookmarkManager.selectAndSaveFolder()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Folders")
    }
}

// MARK: - About Settings View

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Craig-O-Clean")
                .font(.title)
                .fontWeight(.bold)

            Text("Sandbox Edition")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Version \(SandboxConfiguration.appVersion)")
                .font(.caption)

            Divider()

            Text("""
            A Mac App Store compliant system utility for:

            • Monitoring CPU, memory, and disk usage
            • Managing running applications
            • Browser tab optimization
            • User-scoped file cleanup

            All operations respect Apple's App Sandbox
            and require explicit user permission.
            """)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)

            Spacer()

            Text("© 2026 CraigOClean.com")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    SandboxMainAppView()
        .environmentObject(SandboxMetricsProvider())
        .environmentObject(SandboxProcessManager())
        .environmentObject(SandboxPermissionsManager())
        .environmentObject(SecurityScopedBookmarkManager())
        .environmentObject(SandboxBrowserAutomation(permissionsManager: SandboxPermissionsManager()))
        .frame(width: 1000, height: 700)
}
