// MARK: - BrowserTabsView.swift
// CraigOClean Control Center - Browser Tab Management View
// Lists and manages tabs across Safari, Chrome, Edge, and other browsers

import SwiftUI
import AppKit

struct BrowserTabsView: View {
    @EnvironmentObject var browserAutomation: BrowserAutomationService
    @EnvironmentObject var permissions: PermissionsService
    
    @State private var selectedBrowser: SupportedBrowser?
    @State private var searchText = ""
    @State private var selectedTabs: Set<BrowserTab> = []
    @State private var showingCloseConfirmation = false
    @State private var showingPermissionsHelp = false
    @State private var isRefreshing = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var filteredTabs: [BrowserTab] {
        var tabs = browserAutomation.allTabs
        
        // Filter by browser
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Check for permissions first
            if !permissions.hasRequiredPermissions {
                permissionsRequiredView
            } else {
                // Toolbar
                toolbarSection
                
                Divider()
                
                if browserAutomation.runningBrowsers.isEmpty {
                    noBrowsersRunningView
                } else if browserAutomation.isLoading {
                    loadingView
                } else if browserAutomation.allTabs.isEmpty {
                    noTabsView
                } else {
                    // Main content
                    HStack(spacing: 0) {
                        // Browser sidebar
                        browserSidebar
                        
                        Divider()
                        
                        // Tab list
                        tabListSection
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Browser Tabs")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        isRefreshing = true
                        await browserAutomation.fetchAllTabs()
                        isRefreshing = false
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
                
                if !selectedTabs.isEmpty {
                    Button {
                        showingCloseConfirmation = true
                    } label: {
                        Label("Close Selected", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await browserAutomation.fetchAllTabs()
            }
        }
        .alert("Close Tabs", isPresented: $showingCloseConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Close \(selectedTabs.count) Tabs", role: .destructive) {
                Task {
                    for tab in selectedTabs {
                        try? await browserAutomation.closeTab(tab)
                    }
                    selectedTabs.removeAll()
                }
            }
        } message: {
            Text("Are you sure you want to close \(selectedTabs.count) selected tabs?")
        }
        .alert("Browser Tabs", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingPermissionsHelp) {
            PermissionsHelpSheet()
        }
    }
    
    // MARK: - Permissions Required View
    
    private var permissionsRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Automation Permission Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("To manage browser tabs, CraigOClean needs permission to control your browsers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How to enable:")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                        .fontWeight(.bold)
                    Text("Open System Settings → Privacy & Security → Automation")
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                        .fontWeight(.bold)
                    Text("Find CraigOClean Control Center and enable access for your browsers")
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                        .fontWeight(.bold)
                    Text("Click the refresh button above to try again")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            HStack(spacing: 16) {
                Button("Open System Settings") {
                    permissions.openSystemSettings(for: .automation)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Learn More") {
                    showingPermissionsHelp = true
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - No Browsers Running View
    
    private var noBrowsersRunningView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "safari")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Browsers Running")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Open Safari, Chrome, Edge, or another supported browser to manage tabs.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                ForEach(browserAutomation.installedBrowsers) { browser in
                    Button {
                        openBrowser(browser)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: browser.icon)
                                .font(.title)
                            Text(browser.rawValue)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading browser tabs...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Tabs View

    private var noTabsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No tabs found")
                .font(.title3)
                .fontWeight(.medium)
            Text("Open some tabs in your browsers to manage them here")
                .foregroundColor(.secondary)

            // Diagnostic info
            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostic Info:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("Running browsers: \(browserAutomation.runningBrowsers.map { $0.rawValue }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Installed browsers: \(browserAutomation.installedBrowsers.map { $0.rawValue }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let error = browserAutomation.lastError {
                    Text("Last error: \(error.localizedDescription)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Section
    
    private var toolbarSection: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tabs...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 300)
            
            Spacer()
            
            // Stats
            HStack(spacing: 16) {
                Label("\(browserAutomation.totalTabCount) tabs", systemImage: "square.stack")
                    .font(.caption)
                
                if !selectedTabs.isEmpty {
                    Label("\(selectedTabs.count) selected", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Browser Sidebar

    private var browserSidebar: some View {
        VStack(spacing: 0) {
            allBrowsersItem
            Divider().padding(.vertical, 8)
            individualBrowsersList
            Spacer()
            
            Divider()
            
            // Quick actions
            VStack(spacing: 8) {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Close Duplicate Tabs") {
                    closeDuplicateTabs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                
                Button("Consolidate Tabs") {
                    consolidateDomainTabs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .help("Close excess tabs from domains with more than 3 tabs (keeps 3 per domain)")
            }
            .padding()
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Tab List Section
    
    private var tabListSection: some View {
        VStack(spacing: 0) {
            // Group tabs by domain
            if filteredTabs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No matching tabs")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Header
                HStack {
                    Button {
                        if selectedTabs.count == filteredTabs.count {
                            selectedTabs.removeAll()
                        } else {
                            selectedTabs = Set(filteredTabs)
                        }
                    } label: {
                        Image(systemName: selectedTabs.count == filteredTabs.count ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)
                    
                    Text("Tab")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Domain")
                        .frame(width: 150)
                    Text("Browser")
                        .frame(width: 100)
                    Text("Action")
                        .frame(width: 80)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Tab list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTabs) { tab in
                            TabRowItem(
                                tab: tab,
                                isSelected: selectedTabs.contains(tab),
                                onToggle: {
                                    if selectedTabs.contains(tab) {
                                        selectedTabs.remove(tab)
                                    } else {
                                        selectedTabs.insert(tab)
                                    }
                                },
                                onClose: {
                                    Task {
                                        try? await browserAutomation.closeTab(tab)
                                    }
                                }
                            )
                            
                            Divider()
                        }
                    }
                }
                
                // Bottom bar with domain summary
                domainSummaryBar
            }
        }
    }
    
    // MARK: - Domain Summary Bar
    
    private var domainSummaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Top domains:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(browserAutomation.getTopDomains(limit: 5), id: \.domain) { item in
                    Button {
                        searchText = item.domain
                    } label: {
                        HStack(spacing: 4) {
                            Text(item.domain)
                                .lineLimit(1)
                            Text("(\(item.count))")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func browserColor(_ browser: SupportedBrowser) -> Color {
        switch browser {
        case .safari: return .blue
        case .chrome: return .green
        case .edge: return .cyan
        case .brave: return .orange
        case .arc: return .purple
        case .firefox: return .orange
        }
    }
    
    private func openBrowser(_ browser: SupportedBrowser) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
    
    private func closeDuplicateTabs() {
        // Find duplicate URLs
        var seenURLs: Set<String> = []
        var duplicates: [BrowserTab] = []
        
        for tab in browserAutomation.allTabs {
            if seenURLs.contains(tab.url) {
                duplicates.append(tab)
            } else {
                seenURLs.insert(tab.url)
            }
        }
        
        if duplicates.isEmpty {
            alertMessage = "No duplicate tabs found"
            showingAlert = true
        } else {
            Task {
                for tab in duplicates {
                    try? await browserAutomation.closeTab(tab)
                }
                alertMessage = "Closed \(duplicates.count) duplicate tabs"
                showingAlert = true
            }
        }
    }
    
    /// Consolidate tabs by closing excess tabs from domains with more than 3 tabs
    private func consolidateDomainTabs() {
        let maxTabsPerDomain = 3
        
        // Group tabs by domain
        var tabsByDomain: [String: [BrowserTab]] = [:]
        for tab in browserAutomation.allTabs {
            let domain = tab.domain
            tabsByDomain[domain, default: []].append(tab)
        }
        
        // Find tabs to close (excess tabs per domain)
        var tabsToClose: [BrowserTab] = []
        for (_, tabs) in tabsByDomain {
            if tabs.count > maxTabsPerDomain {
                // Keep the first N tabs (assumed to be more recent/important)
                // Close the rest
                let excessTabs = Array(tabs.dropFirst(maxTabsPerDomain))
                tabsToClose.append(contentsOf: excessTabs)
            }
        }
        
        if tabsToClose.isEmpty {
            alertMessage = "No domains have more than \(maxTabsPerDomain) tabs"
            showingAlert = true
        } else {
            Task {
                for tab in tabsToClose {
                    try? await browserAutomation.closeTab(tab)
                }
                alertMessage = "Closed \(tabsToClose.count) excess tabs from high-tab domains"
                showingAlert = true
            }
        }
    }

    private var allBrowsersItem: some View {
        BrowserSidebarItem(
            name: "All Browsers",
            icon: "globe",
            count: browserAutomation.totalTabCount,
            isSelected: selectedBrowser == nil,
            color: .accentColor
        ) {
            selectedBrowser = nil
        }
    }

    private var individualBrowsersList: some View {
        ForEach(browserAutomation.runningBrowsers) { browser in
            let windows = browserAutomation.browserTabs[browser] ?? []
            let count = windows.reduce(0) { $0 + $1.tabs.count }

            BrowserSidebarItem(
                name: browser.rawValue,
                icon: browser.icon,
                count: count,
                isSelected: selectedBrowser == browser,
                color: browserColor(browser)
            ) {
                selectedBrowser = browser
            }
        }
    }
}

// MARK: - Supporting Views

struct BrowserSidebarItem: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? color : .secondary)
                    .frame(width: 20)
                
                Text(name)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

struct TabRowItem: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onToggle: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            // Tab info
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .lineLimit(1)
                
                Text(tab.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Domain
            Text(tab.domain)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)
            
            // Browser
            HStack(spacing: 4) {
                Image(systemName: tab.browser.icon)
                    .font(.caption)
                Text(shortBrowserName(tab.browser))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .frame(width: 100)
            
            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.3)
            .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Group {
                if isSelected {
                    Color.accentColor.opacity(0.1)
                } else if isHovered {
                    Color.secondary.opacity(0.05)
                } else {
                    Color.clear
                }
            }
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func shortBrowserName(_ browser: SupportedBrowser) -> String {
        switch browser {
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .edge: return "Edge"
        case .brave: return "Brave"
        case .arc: return "Arc"
        case .firefox: return "Firefox"
        }
    }
}

struct PermissionsHelpSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Setting Up Automation Permissions")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why is this needed?")
                            .font(.headline)
                        
                        Text("CraigOClean uses AppleScript to communicate with browsers. macOS requires your explicit permission for apps to control other apps, ensuring your privacy and security.")
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step-by-Step Instructions")
                            .font(.headline)
                        
                        InstructionStep(number: 1, title: "Open System Settings", detail: "Click the Apple menu () → System Settings")
                        
                        InstructionStep(number: 2, title: "Navigate to Privacy & Security", detail: "In the sidebar, click Privacy & Security")
                        
                        InstructionStep(number: 3, title: "Find Automation", detail: "Scroll down and click Automation")
                        
                        InstructionStep(number: 4, title: "Enable CraigOClean", detail: "Find CraigOClean Control Center in the list and enable access for each browser you want to manage (Safari, Chrome, Edge, etc.)")
                        
                        InstructionStep(number: 5, title: "Restart if needed", detail: "If the permission doesn't take effect immediately, try closing and reopening your browser")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Troubleshooting")
                            .font(.headline)
                        
                        Text("• If CraigOClean isn't listed, try using the Browser Tabs feature first - this will trigger the permission prompt")
                        
                        Text("• Make sure the browser is running when you try to grant permission")
                        
                        Text("• Some browsers may require a restart after granting permission")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BrowserTabsView()
        .environmentObject(BrowserAutomationService())
        .environmentObject(PermissionsService())
        .frame(width: 900, height: 600)
}
