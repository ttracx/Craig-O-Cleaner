// MARK: - SecurityScopedBookmarkManager.swift
// Craig-O-Clean Sandbox Edition - Security-Scoped Bookmark Management
// Enables persistent access to user-selected folders across app launches

import Foundation
import AppKit
import os.log

// MARK: - Bookmark Data

/// Represents a saved security-scoped bookmark
struct SavedBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let bookmarkData: Data
    let createdAt: Date
    var lastAccessedAt: Date

    /// Whether this is a commonly cleaned cache location
    var isCacheLocation: Bool {
        let cacheIndicators = ["Cache", "Caches", "tmp", "Temp", "Temporary"]
        return cacheIndicators.contains { path.contains($0) }
    }

    /// Display-friendly path (shortened)
    var displayPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }
}

// MARK: - Bookmark Error

enum BookmarkError: LocalizedError {
    case failedToCreateBookmark(String)
    case failedToResolveBookmark(String)
    case bookmarkStale(String)
    case accessDenied(String)
    case notFound(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .failedToCreateBookmark(let path):
            return "Failed to create bookmark for: \(path)"
        case .failedToResolveBookmark(let path):
            return "Failed to resolve bookmark for: \(path)"
        case .bookmarkStale(let path):
            return "Bookmark is stale for: \(path). Please re-select the folder."
        case .accessDenied(let path):
            return "Access denied to: \(path)"
        case .notFound(let name):
            return "Bookmark not found: \(name)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Security-Scoped Bookmark Manager

/// Manages security-scoped bookmarks for persistent access to user-selected folders
/// This is the sandbox-compliant way to maintain access to folders outside the app container
@MainActor
final class SecurityScopedBookmarkManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var savedBookmarks: [SavedBookmark] = []
    @Published private(set) var activeAccessURLs: Set<URL> = []

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.craigoclean.sandbox", category: "Bookmarks")
    private let userDefaultsKey = SandboxConfiguration.UserDefaultsKeys.savedBookmarks

    // MARK: - Initialization

    init() {
        loadBookmarks()
        logger.info("SecurityScopedBookmarkManager initialized with \(self.savedBookmarks.count) bookmarks")
    }

    // MARK: - Public Methods

    /// Present folder picker and save bookmark for the selected folder
    func selectAndSaveFolder(
        message: String = "Select a folder to grant Craig-O-Clean access",
        directoryURL: URL? = nil
    ) async -> SavedBookmark? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = false
                panel.message = message
                panel.prompt = "Select Folder"

                if let directoryURL = directoryURL {
                    panel.directoryURL = directoryURL
                }

                panel.begin { [weak self] response in
                    guard response == .OK,
                          let url = panel.url,
                          let self = self else {
                        continuation.resume(returning: nil)
                        return
                    }

                    Task { @MainActor in
                        do {
                            let bookmark = try await self.createBookmark(for: url)
                            continuation.resume(returning: bookmark)
                        } catch {
                            self.logger.error("Failed to create bookmark: \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }
    }

    /// Create and save a bookmark for a URL
    func createBookmark(for url: URL) async throws -> SavedBookmark {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied(url.path)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Create bookmark data
        let bookmarkData: Data
        do {
            bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.failedToCreateBookmark(url.path)
        }

        // Create bookmark object
        let bookmark = SavedBookmark(
            id: UUID(),
            name: url.lastPathComponent,
            path: url.path,
            bookmarkData: bookmarkData,
            createdAt: Date(),
            lastAccessedAt: Date()
        )

        // Save to list
        savedBookmarks.append(bookmark)
        saveBookmarks()

        logger.info("Created bookmark for: \(url.path)")
        return bookmark
    }

    /// Resolve a bookmark and start accessing the URL
    func startAccessing(bookmark: SavedBookmark) throws -> URL {
        var isStale = false
        let resolvedURL: URL

        do {
            resolvedURL = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw BookmarkError.failedToResolveBookmark(bookmark.path)
        }

        if isStale {
            logger.warning("Bookmark is stale for: \(bookmark.path)")
            // Try to refresh the bookmark
            Task {
                await refreshStaleBookmark(bookmark)
            }
            throw BookmarkError.bookmarkStale(bookmark.path)
        }

        // Start accessing
        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied(bookmark.path)
        }

        activeAccessURLs.insert(resolvedURL)

        // Update last accessed time
        if let index = savedBookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            savedBookmarks[index].lastAccessedAt = Date()
            saveBookmarks()
        }

        logger.info("Started accessing: \(resolvedURL.path)")
        return resolvedURL
    }

    /// Stop accessing a security-scoped URL
    func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
        activeAccessURLs.remove(url)
        logger.info("Stopped accessing: \(url.path)")
    }

    /// Stop accessing all currently active URLs
    func stopAccessingAll() {
        for url in activeAccessURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeAccessURLs.removeAll()
        logger.info("Stopped accessing all security-scoped URLs")
    }

    /// Execute an operation with access to a bookmarked folder
    func withAccess<T>(
        to bookmark: SavedBookmark,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let url = try startAccessing(bookmark: bookmark)
        defer { stopAccessing(url: url) }
        return try await operation(url)
    }

    /// Delete a saved bookmark
    func deleteBookmark(_ bookmark: SavedBookmark) {
        savedBookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
        logger.info("Deleted bookmark: \(bookmark.name)")
    }

    /// Delete a bookmark by ID
    func deleteBookmark(withID id: UUID) {
        if let bookmark = savedBookmarks.first(where: { $0.id == id }) {
            deleteBookmark(bookmark)
        }
    }

    /// Check if a bookmark still provides valid access
    func validateBookmark(_ bookmark: SavedBookmark) -> Bool {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                return false
            }

            // Try to access
            let canAccess = url.startAccessingSecurityScopedResource()
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
            return canAccess
        } catch {
            return false
        }
    }

    /// Get folder info for a bookmark
    func getFolderInfo(for bookmark: SavedBookmark) async throws -> (fileCount: Int, totalSize: Int64) {
        return try await withAccess(to: bookmark) { url in
            let fileManager = FileManager.default
            var fileCount = 0
            var totalSize: Int64 = 0

            if let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    if resourceValues?.isRegularFile == true {
                        fileCount += 1
                        totalSize += Int64(resourceValues?.fileSize ?? 0)
                    }
                }
            }

            return (fileCount, totalSize)
        }
    }

    // MARK: - Private Methods

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            logger.info("No saved bookmarks found")
            return
        }

        do {
            savedBookmarks = try JSONDecoder().decode([SavedBookmark].self, from: data)
            logger.info("Loaded \(self.savedBookmarks.count) bookmarks")
        } catch {
            logger.error("Failed to decode bookmarks: \(error.localizedDescription)")
            savedBookmarks = []
        }
    }

    private func saveBookmarks() {
        do {
            let data = try JSONEncoder().encode(savedBookmarks)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            logger.debug("Saved \(self.savedBookmarks.count) bookmarks")
        } catch {
            logger.error("Failed to encode bookmarks: \(error.localizedDescription)")
        }
    }

    private func refreshStaleBookmark(_ staleBookmark: SavedBookmark) async {
        // Try to recreate the bookmark if the folder still exists
        let url = URL(fileURLWithPath: staleBookmark.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("Cannot refresh bookmark - folder no longer exists: \(staleBookmark.path)")
            return
        }

        // The user would need to re-select the folder
        // We can't automatically refresh without user interaction
        logger.info("Bookmark needs refresh - user must re-select: \(staleBookmark.path)")
    }
}

// MARK: - Common Cache Locations Helper

extension SecurityScopedBookmarkManager {

    /// Suggested cache locations for the user to select
    static var suggestedCacheLocations: [(name: String, path: String)] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            ("User Caches", "\(homeDir)/Library/Caches"),
            ("Safari Cache", "\(homeDir)/Library/Caches/com.apple.Safari"),
            ("Chrome Cache", "\(homeDir)/Library/Caches/Google/Chrome"),
            ("Firefox Cache", "\(homeDir)/Library/Caches/Firefox"),
            ("Downloads", "\(homeDir)/Downloads"),
            ("Temporary Files", NSTemporaryDirectory())
        ]
    }

    /// Check which suggested locations the user has already granted access to
    func grantedSuggestedLocations() -> [String] {
        let suggestedPaths = Set(Self.suggestedCacheLocations.map { $0.path })
        return savedBookmarks
            .map { $0.path }
            .filter { suggestedPaths.contains($0) }
    }
}
