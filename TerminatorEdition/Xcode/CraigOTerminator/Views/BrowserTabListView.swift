import SwiftUI

/// View showing detailed tab list for a browser with selective closing
struct BrowserTabListView: View {
    let browser: BrowsersView.BrowserInfo
    @StateObject private var tabService = BrowserTabService.shared
    @State private var selectedTabs: Set<BrowserTab> = []
    @State private var searchText = ""
    @State private var showOnlyHeavyTabs = false
    @State private var sortBy: SortOption = .index

    enum SortOption: String, CaseIterable {
        case index = "Tab Order"
        case title = "Title"
        case memory = "Memory Usage"
        case url = "URL"
    }

    var filteredTabs: [BrowserTab] {
        let browserTabs = tabService.tabs.filter { $0.browser.rawValue == browser.name }

        var filtered = browserTabs

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply heavy tabs filter
        if showOnlyHeavyTabs {
            filtered = filtered.filter { $0.isHeavy }
        }

        // Apply sort
        switch sortBy {
        case .index:
            filtered.sort { ($0.windowIndex, $0.tabIndex) < ($1.windowIndex, $1.tabIndex) }
        case .title:
            filtered.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .memory:
            filtered.sort { $0.memoryEstimate > $1.memoryEstimate }
        case .url:
            filtered.sort { $0.url.localizedCaseInsensitiveCompare($1.url) == .orderedAscending }
        }

        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            BrowserTabHeader(
                browser: browser,
                totalTabs: filteredTabs.count,
                selectedCount: selectedTabs.count,
                totalMemory: filteredTabs.reduce(0) { $0 + $1.memoryEstimate }
            )

            Divider()

            // Toolbar
            HStack(spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search tabs...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Sort
                Picker("Sort", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                // Filter heavy tabs
                Toggle(isOn: $showOnlyHeavyTabs) {
                    Label("Heavy Tabs", systemImage: "flame")
                }
                .toggleStyle(.button)

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await tabService.fetchAllTabs()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(tabService.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab list
            if tabService.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading tabs...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTabs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No tabs open" : "No matching tabs")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTabs) { tab in
                            BrowserTabRow(
                                tab: tab,
                                isSelected: selectedTabs.contains(tab),
                                onToggle: { toggleTab(tab) }
                            )
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                // Select all/none
                Button(selectedTabs.isEmpty ? "Select All" : "Deselect All") {
                    if selectedTabs.isEmpty {
                        selectedTabs = Set(filteredTabs)
                    } else {
                        selectedTabs.removeAll()
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                // Close selected tabs
                Button {
                    Task {
                        await closeTabs(Array(selectedTabs))
                    }
                } label: {
                    Label("Close Selected (\(selectedTabs.count))", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedTabs.isEmpty || tabService.isLoading)

                // Close heavy tabs
                if !filteredTabs.filter({ $0.isHeavy }).isEmpty {
                    Button {
                        Task {
                            await closeTabs(filteredTabs.filter { $0.isHeavy })
                        }
                    } label: {
                        Label("Close Heavy Tabs", systemImage: "flame")
                    }
                    .buttonStyle(.bordered)
                    .disabled(tabService.isLoading)
                }
            }
            .padding()
        }
        .task {
            await Task.yield()
            await Task.yield()

            await tabService.fetchAllTabs()
        }
    }

    // MARK: - Actions

    private func toggleTab(_ tab: BrowserTab) {
        if selectedTabs.contains(tab) {
            selectedTabs.remove(tab)
        } else {
            selectedTabs.insert(tab)
        }
    }

    private func closeTabs(_ tabs: [BrowserTab]) async {
        guard !tabs.isEmpty else { return }

        let result = await tabService.closeTabs(tabs)

        switch result {
        case .success(let count):
            print("Closed \(count) tabs")
            selectedTabs.removeAll()
            // Refresh tab list
            try? await Task.sleep(nanoseconds: 500_000_000)
            await tabService.fetchAllTabs()

        case .failure(let error):
            print("Failed to close tabs: \(error)")
        }
    }
}

// MARK: - Header

struct BrowserTabHeader: View {
    let browser: BrowsersView.BrowserInfo
    let totalTabs: Int
    let selectedCount: Int
    let totalMemory: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: browser.icon)
                .font(.system(size: 32))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(browser.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label("\(totalTabs) tabs", systemImage: "doc.on.doc")
                    if selectedCount > 0 {
                        Label("\(selectedCount) selected", systemImage: "checkmark.circle")
                            .foregroundStyle(.blue)
                    }
                    Label("~\(totalMemory) MB", systemImage: "memorychip")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Tab Row

struct BrowserTabRow: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)

                // Favicon placeholder
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                // Tab info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(tab.title.isEmpty ? "Untitled" : tab.title)
                            .font(.body)
                            .lineLimit(1)

                        if tab.isHeavy {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(tab.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Memory estimate
                VStack(alignment: .trailing, spacing: 2) {
                    Text("~\(tab.memoryEstimate) MB")
                        .font(.caption)
                        .foregroundStyle(tab.isHeavy ? .orange : .secondary)

                    Text("Window \(tab.windowIndex) • Tab \(tab.tabIndex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

#Preview {
    BrowserTabListView(browser: BrowsersView.BrowserInfo(
        name: "Safari",
        bundleId: "com.apple.Safari",
        isRunning: true,
        tabCount: 12,
        memoryUsage: 1024,
        icon: "safari"
    ))
}
