// File: CraigOClean-vNext/CraigOClean/UI/Components/LogConsoleView.swift
// Craig-O-Clean - Log Console View
// Displays application logs with filtering

import SwiftUI

struct LogConsoleView: View {

    // MARK: - Properties

    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var container: DIContainer

    @State private var searchText = ""
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var selectedCategories: Set<LogCategory> = Set(LogCategory.allCases)
    @State private var autoScroll = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            filterToolbar

            Divider()

            // Log list
            logList
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $autoScroll) {
                    Image(systemName: autoScroll ? "arrow.down.to.line" : "arrow.down.to.line.compact")
                }
                .help("Auto-scroll to new entries")

                Button {
                    exportLogs()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export logs")

                Button {
                    logStore.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear logs")
            }
        }
    }

    // MARK: - Filter Toolbar

    private var filterToolbar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
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
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 300)

            Spacer()

            // Level filter
            Menu {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Button {
                        toggleLevel(level)
                    } label: {
                        HStack {
                            if selectedLevels.contains(level) {
                                Image(systemName: "checkmark")
                            }
                            Text(level.rawValue.capitalized)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Level")
                }
            }

            // Category filter
            Menu {
                ForEach(LogCategory.allCases, id: \.self) { category in
                    Button {
                        toggleCategory(category)
                    } label: {
                        HStack {
                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                            }
                            Text(category.displayName)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "tag")
                    Text("Category")
                }
            }

            // Stats
            Text("\(filteredEntries.count) entries")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            List(filteredEntries) { entry in
                LogEntryRow(entry: entry)
                    .id(entry.id)
            }
            .listStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .onChange(of: logStore.entries.count) { _ in
                if autoScroll, let lastEntry = filteredEntries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredEntries: [AppLogEntry] {
        logStore.entries.filter { entry in
            // Level filter
            guard selectedLevels.contains(entry.level) else { return false }

            // Category filter
            guard selectedCategories.contains(entry.category) else { return false }

            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let messageMatch = entry.message.lowercased().contains(searchLower)
                let sourceMatch = entry.source?.lowercased().contains(searchLower) ?? false
                if !messageMatch && !sourceMatch {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Actions

    private func toggleLevel(_ level: LogLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    private func toggleCategory(_ category: LogCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "CraigOClean-Logs-\(Date().ISO8601Format()).log"

        if panel.runModal() == .OK, let url = panel.url {
            let content = filteredEntries.map { $0.logLine }.joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: AppLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.formattedTimestamp)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            // Level indicator
            levelIndicator

            // Category
            Text(entry.category.rawValue)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            // Message
            Text(entry.message)
                .foregroundColor(entry.level == .error ? .red : .primary)
                .lineLimit(3)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var levelIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(levelColor)
                .frame(width: 8, height: 8)

            Text(entry.level.rawValue.prefix(1).uppercased())
                .fontWeight(.medium)
                .foregroundColor(levelColor)
        }
        .frame(width: 30)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LogConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        let store = LogStore()
        store.add(AppLogEntry(level: .info, category: .app, message: "Application started"))
        store.add(AppLogEntry(level: .debug, category: .cleanup, message: "Scanning user caches"))
        store.add(AppLogEntry(level: .warning, category: .permissions, message: "Full Disk Access not granted"))
        store.add(AppLogEntry(level: .error, category: .cleanup, message: "Failed to delete file"))

        return NavigationStack {
            LogConsoleView()
        }
        .environmentObject(store)
        .environmentObject(DIContainer.shared)
    }
}
#endif
