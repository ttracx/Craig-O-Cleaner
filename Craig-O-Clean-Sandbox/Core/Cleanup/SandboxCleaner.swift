// MARK: - SandboxCleaner.swift
// Craig-O-Clean Sandbox Edition - User-Scoped File Cleanup
// Provides safe, transparent cleanup operations within sandbox constraints

import Foundation
import AppKit
import os.log

// MARK: - Cleanup Item

/// Represents a file or folder that can be cleaned
struct CleanupItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let itemCount: Int
    let type: CleanupItemType
    let isSelected: Bool
    let lastModified: Date?

    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var icon: String {
        switch type {
        case .cacheFolder: return "folder.badge.gearshape"
        case .tempFile: return "doc.badge.clock"
        case .logFile: return "doc.text"
        case .downloadFile: return "arrow.down.doc"
        case .trashItem: return "trash"
        case .browserCache: return "safari"
        case .other: return "doc"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CleanupItem, rhs: CleanupItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum CleanupItemType: String, CaseIterable {
    case cacheFolder = "Cache Folder"
    case tempFile = "Temporary File"
    case logFile = "Log File"
    case downloadFile = "Download"
    case trashItem = "Trash Item"
    case browserCache = "Browser Cache"
    case other = "Other"
}

// MARK: - Cleanup Result

struct CleanupResult {
    let itemsCleaned: Int
    let bytesFreed: Int64
    let errors: [String]
    let timestamp: Date
    let movedToTrash: Bool  // True if items were moved to trash instead of deleted

    var success: Bool {
        return errors.isEmpty
    }

    var formattedBytesFreed: String {
        return ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }
}

// MARK: - Scan Result

struct ScanResult {
    let items: [CleanupItem]
    let totalSize: Int64
    let totalItems: Int
    let scanDuration: TimeInterval
    let bookmarkName: String

    var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Sandbox Cleaner

/// Provides safe, user-scoped cleanup operations
/// All operations require explicit user selection via NSOpenPanel or security-scoped bookmarks
@MainActor
final class SandboxCleaner: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var currentScanResult: ScanResult?
    @Published private(set) var lastCleanupResult: CleanupResult?
    @Published var selectedItems: Set<UUID> = []

    // MARK: - Dependencies

    private(set) var bookmarkManager: SecurityScopedBookmarkManager
    private let logger = Logger(subsystem: "com.craigoclean.sandbox", category: "Cleaner")

    // MARK: - Initialization

    init(bookmarkManager: SecurityScopedBookmarkManager) {
        self.bookmarkManager = bookmarkManager
        logger.info("SandboxCleaner initialized")
    }

    /// Update the bookmark manager reference (used when injected via environment)
    func updateBookmarkManager(_ manager: SecurityScopedBookmarkManager) {
        self.bookmarkManager = manager
    }

    // MARK: - Public Methods

    /// Scan a bookmarked folder for cleanable items
    func scanFolder(bookmark: SavedBookmark) async throws -> ScanResult {
        isScanning = true
        defer { isScanning = false }

        let startTime = Date()
        var items: [CleanupItem] = []
        var totalSize: Int64 = 0

        try await bookmarkManager.withAccess(to: bookmark) { url in
            items = try await self.scanDirectory(url)
            totalSize = items.reduce(0) { $0 + $1.size }
        }

        let result = ScanResult(
            items: items,
            totalSize: totalSize,
            totalItems: items.count,
            scanDuration: Date().timeIntervalSince(startTime),
            bookmarkName: bookmark.name
        )

        currentScanResult = result
        logger.info("Scan complete: \(items.count) items, \(result.formattedTotalSize)")

        return result
    }

    /// Scan a user-selected folder (presents folder picker)
    func scanUserSelectedFolder() async throws -> ScanResult? {
        guard let bookmark = await bookmarkManager.selectAndSaveFolder(
            message: "Select a folder to scan for cleanable files"
        ) else {
            return nil
        }

        return try await scanFolder(bookmark: bookmark)
    }

    /// Clean selected items from the current scan result
    func cleanSelectedItems(moveToTrash: Bool = true) async -> CleanupResult {
        guard let scanResult = currentScanResult else {
            return CleanupResult(
                itemsCleaned: 0,
                bytesFreed: 0,
                errors: ["No scan result available"],
                timestamp: Date(),
                movedToTrash: false
            )
        }

        isCleaning = true
        defer { isCleaning = false }

        let itemsToClean = scanResult.items.filter { selectedItems.contains($0.id) }
        var cleanedCount = 0
        var bytesFreed: Int64 = 0
        var errors: [String] = []

        logger.info("Starting cleanup of \(itemsToClean.count) items")

        for item in itemsToClean {
            do {
                if moveToTrash {
                    try await moveToAppTrash(item.url)
                } else {
                    try FileManager.default.removeItem(at: item.url)
                }

                cleanedCount += 1
                bytesFreed += item.size
                logger.debug("Cleaned: \(item.name)")
            } catch {
                let errorMsg = "Failed to clean \(item.name): \(error.localizedDescription)"
                errors.append(errorMsg)
                logger.error("\(errorMsg)")
            }
        }

        let result = CleanupResult(
            itemsCleaned: cleanedCount,
            bytesFreed: bytesFreed,
            errors: errors,
            timestamp: Date(),
            movedToTrash: moveToTrash
        )

        lastCleanupResult = result
        selectedItems.removeAll()

        // Refresh the scan to show updated state
        if cleanedCount > 0, let bookmark = findBookmarkForScan() {
            try? await scanFolder(bookmark: bookmark)
        }

        logger.info("Cleanup complete: \(cleanedCount) items, \(result.formattedBytesFreed) freed")
        return result
    }

    /// Select all items in current scan
    func selectAll() {
        guard let scanResult = currentScanResult else { return }
        selectedItems = Set(scanResult.items.map { $0.id })
    }

    /// Deselect all items
    func deselectAll() {
        selectedItems.removeAll()
    }

    /// Select items above a certain size threshold
    func selectItemsAbove(size: Int64) {
        guard let scanResult = currentScanResult else { return }
        selectedItems = Set(scanResult.items.filter { $0.size >= size }.map { $0.id })
    }

    /// Get the selected items' total size
    var selectedItemsSize: Int64 {
        guard let scanResult = currentScanResult else { return 0 }
        return scanResult.items
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    /// Format selected items size
    var formattedSelectedSize: String {
        return ByteCountFormatter.string(fromByteCount: selectedItemsSize, countStyle: .file)
    }

    // MARK: - App Container Cleanup

    /// Clean the app's own container (always allowed in sandbox)
    func cleanAppContainer() async -> CleanupResult {
        isCleaning = true
        defer { isCleaning = false }

        var cleanedCount = 0
        var bytesFreed: Int64 = 0
        var errors: [String] = []

        let fileManager = FileManager.default

        // Paths within our container we can clean
        let cleanablePaths = [
            fileManager.temporaryDirectory,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        for baseURL in cleanablePaths {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: baseURL,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for url in contents {
                    do {
                        let attrs = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        let size = Int64(attrs.fileSize ?? 0)

                        try fileManager.removeItem(at: url)
                        cleanedCount += 1
                        bytesFreed += size
                    } catch {
                        errors.append("Failed to clean \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            } catch {
                errors.append("Failed to enumerate \(baseURL.path): \(error.localizedDescription)")
            }
        }

        let result = CleanupResult(
            itemsCleaned: cleanedCount,
            bytesFreed: bytesFreed,
            errors: errors,
            timestamp: Date(),
            movedToTrash: false
        )

        lastCleanupResult = result
        logger.info("App container cleanup: \(cleanedCount) items, \(result.formattedBytesFreed) freed")

        return result
    }

    // MARK: - Private Methods

    private func scanDirectory(_ url: URL) async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw CleanupError.scanFailed("Cannot enumerate directory")
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey,
                    .isDirectoryKey,
                    .contentModificationDateKey
                ])

                let isDirectory = resourceValues.isDirectory ?? false
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                let modDate = resourceValues.contentModificationDate

                // For directories, calculate total size
                var totalSize = fileSize
                var itemCount = 1

                if isDirectory {
                    let (dirSize, count) = calculateDirectorySize(fileURL)
                    totalSize = dirSize
                    itemCount = count
                }

                // Skip very small items (< 1KB)
                guard totalSize >= 1024 else { continue }

                let itemType = determineItemType(url: fileURL)

                let item = CleanupItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: totalSize,
                    itemCount: itemCount,
                    type: itemType,
                    isSelected: false,
                    lastModified: modDate
                )

                items.append(item)
            } catch {
                logger.debug("Skipping \(fileURL.path): \(error.localizedDescription)")
            }
        }

        // Sort by size (largest first)
        return items.sorted { $0.size > $1.size }
    }

    private func calculateDirectorySize(_ url: URL) -> (size: Int64, count: Int) {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        var count = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
                count += 1
            }
        }

        return (totalSize, count)
    }

    private func determineItemType(url: URL) -> CleanupItemType {
        let path = url.path.lowercased()
        let name = url.lastPathComponent.lowercased()

        if path.contains("/caches/") || name.contains("cache") {
            if path.contains("safari") || path.contains("chrome") ||
               path.contains("firefox") || path.contains("edge") {
                return .browserCache
            }
            return .cacheFolder
        }

        if path.contains("/tmp/") || path.contains("/temp/") || name.hasSuffix(".tmp") {
            return .tempFile
        }

        if name.hasSuffix(".log") || path.contains("/logs/") {
            return .logFile
        }

        if path.contains("/downloads/") {
            return .downloadFile
        }

        if path.contains("/.trash/") {
            return .trashItem
        }

        return .other
    }

    private func moveToAppTrash(_ url: URL) async throws {
        let fileManager = FileManager.default

        // Create app's trash directory
        let trashDir = fileManager.temporaryDirectory
            .appendingPathComponent(SandboxConfiguration.Cleanup.trashFolderName, isDirectory: true)

        if !fileManager.fileExists(atPath: trashDir.path) {
            try fileManager.createDirectory(at: trashDir, withIntermediateDirectories: true)
        }

        // Create unique name to avoid conflicts
        let uniqueName = "\(UUID().uuidString)_\(url.lastPathComponent)"
        let destination = trashDir.appendingPathComponent(uniqueName)

        try fileManager.moveItem(at: url, to: destination)
        logger.debug("Moved to app trash: \(url.lastPathComponent)")
    }

    private func findBookmarkForScan() -> SavedBookmark? {
        guard let scanResult = currentScanResult else { return nil }
        return bookmarkManager.savedBookmarks.first { $0.name == scanResult.bookmarkName }
    }
}

// MARK: - Cleanup Error

enum CleanupError: LocalizedError {
    case scanFailed(String)
    case cleanupFailed(String)
    case accessDenied(String)
    case bookmarkRequired

    var errorDescription: String? {
        switch self {
        case .scanFailed(let reason): return "Scan failed: \(reason)"
        case .cleanupFailed(let reason): return "Cleanup failed: \(reason)"
        case .accessDenied(let path): return "Access denied to: \(path)"
        case .bookmarkRequired: return "Please select a folder to grant access"
        }
    }
}

// MARK: - Cleanup Statistics

extension SandboxCleaner {

    /// Get cleanup history summary
    func getCleanupStatistics() -> (totalCleaned: Int64, sessionsCount: Int) {
        // In a real implementation, this would read from persistent storage
        // For now, just return the last cleanup
        if let result = lastCleanupResult {
            return (result.bytesFreed, 1)
        }
        return (0, 0)
    }

    /// Clear the app's internal trash (files moved for safe deletion)
    func emptyAppTrash() async throws {
        let fileManager = FileManager.default
        let trashDir = fileManager.temporaryDirectory
            .appendingPathComponent(SandboxConfiguration.Cleanup.trashFolderName, isDirectory: true)

        if fileManager.fileExists(atPath: trashDir.path) {
            try fileManager.removeItem(at: trashDir)
            logger.info("Emptied app trash")
        }
    }

    /// Restore items from app trash (if still available)
    func restoreFromAppTrash(item: CleanupItem, to destination: URL) async throws {
        // This would require the original path to be stored
        // Implementation depends on how trash metadata is stored
        throw CleanupError.cleanupFailed("Restore not yet implemented")
    }
}
