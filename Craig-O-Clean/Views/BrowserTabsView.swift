// BrowserTabsView.swift
// ClearMind Control Center
//
// View for managing browser tabs across Safari, Chrome, Edge, and other browsers
// Allows viewing, filtering, and closing browser tabs

import SwiftUI

struct BrowserTabsView: View {
    @StateObject private var browserService = BrowserAutomationService()
    @State private var selectedBrowser: BrowserType?
    @State private var searchText = ""
    @State private var showingPermissionAlert = false
    @State private var selectedTabs: Set<String> = []
    @State private var filterByDomain = ""
    @State private var showDomainFilter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar
            headerToolbar
            
            Divider()
            
            if browserService.runningBrowsers.isEmpty {
                noBrowsersView
            } else if browserService.allTabs.isEmpty && !browserService.isLoading {
                noTabsView
            } else {
                // Main content
                HSplitView {
                    // Browser sidebar
                    browserSidebar
                        .frame(minWidth: 200, maxWidth: 250)
                    
                    // Tab list
                    tabListView
                }
            }
            
            Divider()
            
            // Footer with actions
            footerView
        }
        .onAppear {
            Task {
                await browserService.fetchAllTabs()
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                browserService.openAutomationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("ClearMind Control Center needs Automation permission to manage browser tabs. Please grant access in System Settings.")
        }
    }
    
    // MARK: - Header Toolbar
    
    private var headerToolbar: some View {
        HStack(spacing: 12) {
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
            
            // Domain filter
            if showDomainFilter {
                HStack {
                    Text("Domain:")
                        .font(.caption)
                    TextField("e.g., youtube.com", text: $filterByDomain)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    
                    Button {
                        filterByDomain = ""
                        showDomainFilter = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showDomainFilter = true
                } label: {
                    Label("Filter by Domain", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.bordered)
            }
            
            // Refresh
            Button {
                Task {
                    await browserService.fetchAllTabs()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(browserService.isLoading)
            
            // Stats
            Text("\(browserService.totalTabCount) tabs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Browser Sidebar
    
    private var browserSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("BROWSERS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top)
            
            // All tabs option
            Button {
                selectedBrowser = nil
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .frame(width: 20)
                    Text("All Browsers")
                    Spacer()
                    Text("\(browserService.totalTabCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(selectedBrowser == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            
            Divider()
                .padding(.vertical, 8)
            
            // Browser list
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(browserService.runningBrowsers) { browser in
                        BrowserRowView(
                            browser: browser,
                            tabCount: browserService.tabsPerBrowser[browser] ?? 0,
                            permissionGranted: browserService.permissionStatus[browser] ?? false,
                            isSelected: selectedBrowser == browser
                        ) {
                            selectedBrowser = browser
                        }
                    }
                    
                    // Installed but not running
                    let notRunning = browserService.installedBrowsers.filter { !browserService.runningBrowsers.contains($0) }
                    
                    if !notRunning.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("NOT RUNNING")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(notRunning) { browser in
                            HStack {
                                if let icon = browser.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "globe")
                                        .frame(width: 20)
                                }
                                
                                Text(browser.rawValue)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            // Domains summary
            if !browserService.uniqueDomains.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOP DOMAINS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(topDomains, id: \.0) { domain, count in
                        HStack {
                            Text(domain)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Tab List View
    
    private var tabListView: some View {
        VStack(spacing: 0) {
            // Selection toolbar
            if !selectedTabs.isEmpty {
                HStack {
                    Text("\(selectedTabs.count) selected")
                        .font(.caption)
                    
                    Spacer()
                    
                    Button("Deselect All") {
                        selectedTabs.removeAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    
                    Button("Close Selected") {
                        Task {
                            await closeSelectedTabs()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
            }
            
            // Tab list
            if browserService.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading tabs...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedTabs) {
                    ForEach(filteredTabs) { tab in
                        TabRowView(tab: tab) {
                            Task {
                                await closeTab(tab)
                            }
                        }
                        .tag(tab.id)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    // MARK: - No Browsers View
    
    private var noBrowsersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Browsers Running")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Open Safari, Chrome, Edge, or Brave to manage tabs")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                browserService.updateRunningBrowsers()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Tabs View
    
    private var noTabsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Tabs Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            if browserService.deniedAutomationApps.isEmpty {
                Text("Open some tabs in your browser, then refresh")
                    .foregroundColor(.secondary)
            } else {
                Text("ClearMind needs permission to access browser tabs")
                    .foregroundColor(.secondary)
                
                Button("Grant Permission") {
                    browserService.openAutomationSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button("Refresh") {
                Task {
                    await browserService.fetchAllTabs()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            // Permission status
            if !browserService.permissionStatus.isEmpty {
                HStack(spacing: 4) {
                    let granted = browserService.permissionStatus.values.filter { $0 }.count
                    let total = browserService.permissionStatus.count
                    
                    if granted == total {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All permissions granted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(granted)/\(total) permissions granted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Fix") {
                            browserService.openAutomationSettings()
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }
            }
            
            Spacer()
            
            // Quick actions
            Menu {
                Button("Close All Tabs in Domain...") {
                    showDomainFilter = true
                }
                
                Button("Close Duplicate Tabs") {
                    Task {
                        await closeDuplicateTabs()
                    }
                }
                
                Divider()
                
                if let browser = selectedBrowser {
                    Button("Close Other Tabs in \(browser.rawValue)") {
                        Task {
                            let result = await browserService.closeOtherTabs(in: browser)
                            handleResult(result)
                        }
                    }
                }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            
            // Close domain button
            if !filterByDomain.isEmpty {
                Button("Close \(filteredTabs.count) Tabs") {
                    Task {
                        let result = await browserService.closeTabsByDomain(filterByDomain)
                        handleResult(result)
                        filterByDomain = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(filteredTabs.isEmpty)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var filteredTabs: [BrowserTab] {
        var tabs = browserService.allTabs
        
        // Filter by browser
        if let browser = selectedBrowser {
            tabs = tabs.filter { $0.browser == browser }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            tabs = tabs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by domain
        if !filterByDomain.isEmpty {
            tabs = tabs.filter { $0.domain.contains(filterByDomain) }
        }
        
        return tabs
    }
    
    private var topDomains: [(String, Int)] {
        let counts = Dictionary(grouping: browserService.allTabs, by: { $0.domain })
            .filter { !$0.key.isEmpty }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(counts.prefix(5))
    }
    
    // MARK: - Actions
    
    private func closeTab(_ tab: BrowserTab) async {
        let result = await browserService.closeTab(tab)
        handleResult(result)
    }
    
    private func closeSelectedTabs() async {
        for tabId in selectedTabs {
            if let tab = browserService.allTabs.first(where: { $0.id == tabId }) {
                _ = await browserService.closeTab(tab)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        selectedTabs.removeAll()
    }
    
    private func closeDuplicateTabs() async {
        var seenUrls: Set<String> = []
        var duplicates: [BrowserTab] = []
        
        for tab in browserService.allTabs {
            if seenUrls.contains(tab.url) {
                duplicates.append(tab)
            } else {
                seenUrls.insert(tab.url)
            }
        }
        
        for tab in duplicates {
            _ = await browserService.closeTab(tab)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    private func handleResult(_ result: BrowserOperationResult) {
        switch result {
        case .permissionDenied:
            showingPermissionAlert = true
        case .scriptError(let error):
            print("Script error: \(error)")
        default:
            break
        }
    }
}

// MARK: - Supporting Views

struct BrowserRowView: View {
    let browser: BrowserType
    let tabCount: Int
    let permissionGranted: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = browser.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "globe")
                        .frame(width: 20)
                }
                
                Text(browser.rawValue)
                    .lineLimit(1)
                
                Spacer()
                
                if !permissionGranted {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Text("\(tabCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct TabRowView: View {
    let tab: BrowserTab
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Browser icon
            if let icon = tab.browser.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            
            // Tab info
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .lineLimit(1)
                
                Text(tab.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Domain badge
            if !tab.domain.isEmpty {
                Text(tab.domain)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.3)
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    BrowserTabsView()
        .frame(width: 900, height: 600)
}
