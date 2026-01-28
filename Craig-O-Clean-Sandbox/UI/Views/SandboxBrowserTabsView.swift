// MARK: - SandboxBrowserTabsView.swift
// Craig-O-Clean Sandbox Edition - Browser Tab Management View
// Displays and manages browser tabs with proper permission handling

import SwiftUI

struct SandboxBrowserTabsView: View {
    @EnvironmentObject var browserAutomation: SandboxBrowserAutomation
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager

    @State private var selectedBrowser: SandboxSupportedBrowser?
    @State private var selectedTabs: Set<String> = []
    @State private var showingCloseConfirmation = false
    @State private var searchText = ""

    var body: some View {
        HSplitView {
            // Left: Browser list
            browserListView
                .frame(minWidth: 200, maxWidth: 250)

            // Right: Tabs list
            tabsListView
        }
        .navigationTitle("Browser Tabs")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task {
                        await browserAutomation.fetchAllTabs()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                if !selectedTabs.isEmpty {
                    Button {
                        showingCloseConfirmation = true
                    } label: {
                        Label("Close Selected", systemImage: "xmark.circle")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            Task {
                await browserAutomation.fetchAllTabs()
            }
        }
        .alert("Close \(selectedTabs.count) Tab(s)?", isPresented: $showingCloseConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Close", role: .destructive) {
                Task {
                    await closeSelectedTabs()
                }
            }
        }
    }

    // MARK: - Browser List View

    private var browserListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Browsers")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Browser list
            List {
                // All browsers option
                BrowserRow(
                    browser: nil,
                    tabCount: browserAutomation.totalTabCount,
                    isSelected: selectedBrowser == nil,
                    permissionStatus: true
                )
                .onTapGesture {
                    selectedBrowser = nil
                }

                Divider()
                    .padding(.vertical, 4)

                // Individual browsers
                ForEach(browserAutomation.installedBrowsers) { browser in
                    let tabCount = browserAutomation.browserTabs[browser]?.reduce(0) { $0 + $1.tabCount } ?? 0
                    let hasPermission = browserAutomation.permissionStatus[browser] ?? false

                    BrowserRow(
                        browser: browser,
                        tabCount: tabCount,
                        isSelected: selectedBrowser == browser,
                        permissionStatus: hasPermission
                    )
                    .onTapGesture {
                        selectedBrowser = browser
                    }
                    .contextMenu {
                        if !hasPermission {
                            Button("Grant Permission") {
                                Task {
                                    _ = await browserAutomation.requestPermission(for: browser)
                                    await browserAutomation.fetchAllTabs()
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                let stats = browserAutomation.getTabStatistics()

                HStack {
                    Text("Total Tabs:")
                    Spacer()
                    Text("\(stats.total)")
                        .fontWeight(.semibold)
                }

                if !browserAutomation.heavyTabs.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(browserAutomation.heavyTabs.count) heavy tabs")
                            .font(.caption)
                    }

                    Button("Close Heavy Tabs") {
                        Task {
                            try? await browserAutomation.closeHeavyTabs()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .font(.caption)
        }
    }

    // MARK: - Tabs List View

    private var tabsListView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tabs...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding()

            Divider()

            // Tabs list
            if browserAutomation.isLoading {
                loadingView
            } else if filteredTabs.isEmpty {
                emptyView
            } else {
                tabsList
            }
        }
    }

    // MARK: - Tabs List

    private var tabsList: some View {
        List {
            // Group by domain
            ForEach(groupedTabs.keys.sorted(), id: \.self) { domain in
                Section {
                    ForEach(groupedTabs[domain] ?? []) { tab in
                        TabRow(
                            tab: tab,
                            isSelected: selectedTabs.contains(tab.id),
                            onToggle: {
                                toggleSelection(tab)
                            },
                            onClose: {
                                Task {
                                    try? await browserAutomation.closeTab(tab)
                                }
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text(domain.isEmpty ? "Unknown" : domain)
                            .font(.headline)
                        Spacer()
                        Text("\(groupedTabs[domain]?.count ?? 0) tabs")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Close All") {
                            Task {
                                try? await browserAutomation.closeTabsByDomain(domain)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading tabs...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No tabs found")
                .font(.headline)

            if browserAutomation.permissionStatus.values.contains(false) {
                Text("Some browsers may need permission")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Check Permissions") {
                    Task {
                        await permissionsManager.refreshAllPermissions()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredTabs: [SandboxBrowserTab] {
        var tabs = browserAutomation.allTabs

        // Filter by browser if selected
        if let browser = selectedBrowser {
            tabs = tabs.filter { $0.browser == browser }
        }

        // Filter by search
        if !searchText.isEmpty {
            tabs = tabs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText) ||
                $0.domain.localizedCaseInsensitiveContains(searchText)
            }
        }

        return tabs
    }

    private var groupedTabs: [String: [SandboxBrowserTab]] {
        Dictionary(grouping: filteredTabs, by: { $0.domain })
    }

    // MARK: - Actions

    private func toggleSelection(_ tab: SandboxBrowserTab) {
        if selectedTabs.contains(tab.id) {
            selectedTabs.remove(tab.id)
        } else {
            selectedTabs.insert(tab.id)
        }
    }

    private func closeSelectedTabs() async {
        let tabsToClose = filteredTabs.filter { selectedTabs.contains($0.id) }
        try? await browserAutomation.closeTabs(tabsToClose)
        selectedTabs.removeAll()
    }
}

// MARK: - Browser Row

struct BrowserRow: View {
    let browser: SandboxSupportedBrowser?
    let tabCount: Int
    let isSelected: Bool
    let permissionStatus: Bool

    var body: some View {
        HStack {
            Image(systemName: browser?.icon ?? "globe")
                .foregroundColor(permissionStatus ? .accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(browser?.rawValue ?? "All Browsers")
                    .fontWeight(isSelected ? .semibold : .regular)

                if !permissionStatus && browser != nil {
                    Text("Permission needed")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Text("\(tabCount)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Tab Row

struct TabRow: View {
    let tab: SandboxBrowserTab
    let isSelected: Bool
    let onToggle: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Browser icon
            Image(systemName: tab.browser.icon)
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(tab.title.isEmpty ? "Untitled" : tab.title)
                        .lineLimit(1)

                    if tab.isHeavyTab {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if tab.isActive {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                Text(tab.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(isHovered ? 1 : 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview {
    SandboxBrowserTabsView()
        .environmentObject(SandboxBrowserAutomation(permissionsManager: SandboxPermissionsManager()))
        .environmentObject(SandboxPermissionsManager())
        .frame(width: 800, height: 600)
}
