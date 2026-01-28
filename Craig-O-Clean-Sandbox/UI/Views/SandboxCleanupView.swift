// MARK: - SandboxCleanupView.swift
// Craig-O-Clean Sandbox Edition - User-Scoped Cleanup View
// Provides safe, transparent file cleanup within user-selected folders

import SwiftUI

struct SandboxCleanupView: View {
    @EnvironmentObject var bookmarkManager: SecurityScopedBookmarkManager
    @StateObject private var cleaner = SandboxCleaner(bookmarkManager: SecurityScopedBookmarkManager())

    @State private var selectedBookmark: SavedBookmark?
    @State private var isScanning = false
    @State private var showingFolderPicker = false
    @State private var showingCleanupConfirmation = false
    @State private var moveToTrash = true

    var body: some View {
        HSplitView {
            // Left: Folder list
            folderListView
                .frame(minWidth: 200, maxWidth: 300)

            // Right: Scan results
            scanResultsView
        }
        .navigationTitle("Cleanup")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingFolderPicker = true
                } label: {
                    Label("Add Folder", systemImage: "plus")
                }

                if cleaner.currentScanResult != nil {
                    Button {
                        showingCleanupConfirmation = true
                    } label: {
                        Label("Clean Selected", systemImage: "trash")
                    }
                    .disabled(cleaner.selectedItems.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            AddFolderSheet(bookmarkManager: bookmarkManager) { bookmark in
                selectedBookmark = bookmark
                Task {
                    try? await cleaner.scanFolder(bookmark: bookmark)
                }
            }
        }
        .alert("Clean Selected Items?", isPresented: $showingCleanupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                Task {
                    _ = await cleaner.cleanSelectedItems(moveToTrash: moveToTrash)
                }
            }
        } message: {
            Text("This will delete \(cleaner.selectedItems.count) items (\(cleaner.formattedSelectedSize)).\n\n\(moveToTrash ? "Items will be moved to app trash for safe deletion." : "Items will be permanently deleted.")")
        }
        .onAppear {
            // Update cleaner with the proper bookmark manager from environment
            cleaner.updateBookmarkManager(bookmarkManager)
        }
    }

    // MARK: - Folder List View

    private var folderListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Saved Folders")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Folder list
            if bookmarkManager.savedBookmarks.isEmpty {
                emptyFolderList
            } else {
                List(bookmarkManager.savedBookmarks, selection: $selectedBookmark) { bookmark in
                    FolderRow(bookmark: bookmark, isSelected: selectedBookmark?.id == bookmark.id)
                        .tag(bookmark)
                        .onTapGesture {
                            selectedBookmark = bookmark
                            Task {
                                try? await cleaner.scanFolder(bookmark: bookmark)
                            }
                        }
                        .contextMenu {
                            Button("Scan") {
                                Task {
                                    try? await cleaner.scanFolder(bookmark: bookmark)
                                }
                            }
                            Button("Remove", role: .destructive) {
                                bookmarkManager.deleteBookmark(bookmark)
                            }
                        }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Quick actions
            VStack(spacing: 8) {
                Button {
                    Task {
                        _ = await cleaner.cleanAppContainer()
                    }
                } label: {
                    Label("Clean App Cache", systemImage: "trash.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    // MARK: - Scan Results View

    private var scanResultsView: some View {
        VStack(spacing: 0) {
            if cleaner.isScanning {
                scanningView
            } else if let result = cleaner.currentScanResult {
                scanResultsList(result)
            } else {
                noScanView
            }
        }
    }

    // MARK: - Empty Folder List

    private var emptyFolderList: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No folders added")
                .font(.headline)

            Text("Add a folder to scan for cleanable files")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Add Folder") {
                showingFolderPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning folder...")
                .font(.headline)

            Text("This may take a moment for large folders")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Scan View

    private var noScanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("Select a folder to scan")
                .font(.headline)

            Text("Choose a folder from the list or add a new one")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scan Results List

    private func scanResultsList(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            // Summary header
            HStack {
                VStack(alignment: .leading) {
                    Text(result.bookmarkName)
                        .font(.headline)
                    Text("\(result.totalItems) items • \(result.formattedTotalSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection controls
                HStack(spacing: 12) {
                    Button("Select All") {
                        cleaner.selectAll()
                    }
                    Button("Clear") {
                        cleaner.deselectAll()
                    }
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Items list
            List {
                ForEach(result.items) { item in
                    CleanupItemRow(
                        item: item,
                        isSelected: cleaner.selectedItems.contains(item.id),
                        onToggle: {
                            if cleaner.selectedItems.contains(item.id) {
                                cleaner.selectedItems.remove(item.id)
                            } else {
                                cleaner.selectedItems.insert(item.id)
                            }
                        }
                    )
                }
            }
            .listStyle(.inset)

            Divider()

            // Footer with cleanup options
            HStack {
                Toggle("Move to app trash (safer)", isOn: $moveToTrash)
                    .toggleStyle(.checkbox)

                Spacer()

                if !cleaner.selectedItems.isEmpty {
                    Text("\(cleaner.selectedItems.count) selected • \(cleaner.formattedSelectedSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let bookmark: SavedBookmark
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: bookmark.isCacheLocation ? "folder.badge.gearshape" : "folder")
                .foregroundColor(bookmark.isCacheLocation ? .orange : .accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.name)
                    .lineLimit(1)

                Text(bookmark.displayPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Cleanup Item Row

struct CleanupItemRow: View {
    let item: CleanupItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: item.icon)
                .foregroundColor(typeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.1))
                        .foregroundColor(typeColor)
                        .cornerRadius(4)

                    if item.itemCount > 1 {
                        Text("\(item.itemCount) items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    private var typeColor: Color {
        switch item.type {
        case .cacheFolder: return .orange
        case .tempFile: return .yellow
        case .logFile: return .blue
        case .downloadFile: return .green
        case .trashItem: return .red
        case .browserCache: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - Add Folder Sheet

struct AddFolderSheet: View {
    let bookmarkManager: SecurityScopedBookmarkManager
    let onFolderAdded: (SavedBookmark) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSelecting = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Folder")
                .font(.title2)
                .fontWeight(.bold)

            Text("Select a folder to grant Craig-O-Clean access for cleanup scanning")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Suggested locations
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested Locations")
                    .font(.headline)

                ForEach(SecurityScopedBookmarkManager.suggestedCacheLocations, id: \.path) { location in
                    Button {
                        selectFolder(at: URL(fileURLWithPath: location.path))
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(location.name)
                            Spacer()
                            Text(location.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.textBackgroundColor))
            .cornerRadius(10)

            Divider()

            HStack {
                Button("Choose Other...") {
                    selectCustomFolder()
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 450, height: 400)
    }

    private func selectFolder(at url: URL) {
        Task {
            if let bookmark = await bookmarkManager.selectAndSaveFolder(
                message: "Confirm access to this folder",
                directoryURL: url.deletingLastPathComponent()
            ) {
                onFolderAdded(bookmark)
                dismiss()
            }
        }
    }

    private func selectCustomFolder() {
        Task {
            if let bookmark = await bookmarkManager.selectAndSaveFolder() {
                onFolderAdded(bookmark)
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SandboxCleanupView()
        .environmentObject(SecurityScopedBookmarkManager())
        .frame(width: 800, height: 600)
}
