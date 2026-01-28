// MARK: - FileAccessManager.swift
// Craig-O-Clean - Security-Scoped Bookmark Manager
// Manages persistent file access permissions via security-scoped bookmarks

import Foundation
import AppKit
import Combine
import os.log

/// Manages security-scoped bookmarks for persistent file/folder access
@MainActor
final class FileAccessManager: ObservableObject {

    // MARK: - Published Properties

    /// Currently authorized folders
    @Published private(set) var authorizedFolders: [AuthorizedFolder] = []

    /// Folders currently being accessed
    @Published private(set) var activeFolders: Set<UUID> = []

    /// Last error encountered
    @Published private(set) var lastError: CraigOCleanError?

    // MARK: - Private Properties

    private let bookmarkKey = "com.craigoclean.security-scoped-bookmarks"
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "FileAccess")
    private var auditLog: AuditLogService?

    // MARK: - Initialization

    init(auditLog: AuditLogService? = nil) {
        self.auditLog = auditLog
        loadBookmarks()
    }

    /// Connect to audit log service after initialization
    func setAuditLog(_ auditLog: AuditLogService) {
        self.auditLog = auditLog
    }

    // MARK: - Folder Authorization

    /// Present folder picker and create security-scoped bookmark
    /// - Parameter suggestedPath: Optional path to initially display (will be expanded)
    /// - Parameter message: Custom message for the open panel
    /// - Returns: The authorized folder, or nil if cancelled/failed
    func authorizeFolder(
        suggestedPath: String? = nil,
        message: String = "Select a folder to authorize for cleanup"
    ) async -> AuthorizedFolder? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = message
        panel.prompt = "Authorize"

        // Set initial directory if suggested
        if let suggestedPath = suggestedPath {
            let expandedPath = NSString(string: suggestedPath).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            if FileManager.default.fileExists(atPath: expandedPath) {
                panel.directoryURL = url
            }
        }

        // Show panel
        let response = await panel.begin()

        guard response == .OK, let url = panel.url else {
            logger.info("Folder authorization cancelled")
            return nil
        }

        // Create bookmark
        return await createBookmark(for: url)
    }

    /// Create a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The authorized folder, or nil if failed
    func createBookmark(for url: URL) async -> AuthorizedFolder? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let folder = AuthorizedFolder(
                id: UUID(),
                url: url,
                bookmarkData: bookmarkData,
                createdAt: Date()
            )

            // Add to list and persist
            authorizedFolders.append(folder)
            saveBookmarks()

            logger.info("Created bookmark for: \(url.path)")
            auditLog?.log(.folderAuthorized, target: url.path)

            return folder

        } catch {
            logger.error("Failed to create bookmark for \(url.path): \(error.localizedDescription)")
            lastError = .bookmarkCreationFailed(url, underlying: error)
            auditLog?.logError(.folderAuthorized, target: url.path, error: error)
            return nil
        }
    }

    /// Remove authorization for a folder
    /// - Parameter folder: The folder to remove
    func removeAuthorization(for folder: AuthorizedFolder) {
        // Stop accessing if currently active
        stopAccessing(folder)

        // Remove from list
        authorizedFolders.removeAll { $0.id == folder.id }
        saveBookmarks()

        logger.info("Removed authorization for: \(folder.path)")
        auditLog?.log(.folderRevoked, target: folder.path)
    }

    /// Remove authorization by URL
    /// - Parameter url: The URL to remove authorization for
    func removeAuthorization(for url: URL) {
        if let folder = authorizedFolders.first(where: { $0.url == url }) {
            removeAuthorization(for: folder)
        }
    }

    // MARK: - Access Control

    /// Start accessing a security-scoped resource
    /// Must be called before any file operations within the folder
    /// - Parameter folder: The folder to access
    /// - Returns: true if access was started successfully
    @discardableResult
    func startAccessing(_ folder: AuthorizedFolder) -> Bool {
        // Already accessing?
        if activeFolders.contains(folder.id) {
            return true
        }

        // Resolve bookmark
        var isStale = false
        guard let url = resolveBookmark(folder.bookmarkData, isStale: &isStale) else {
            logger.error("Failed to resolve bookmark for: \(folder.path)")
            lastError = .bookmarkStale(folder.url)
            return false
        }

        // Handle stale bookmark
        if isStale {
            logger.warning("Bookmark is stale for: \(folder.path)")
            // Try to refresh the bookmark
            if let refreshed = refreshStaleBookmark(folder, newURL: url) {
                return startAccessing(refreshed)
            }
            lastError = .bookmarkStale(folder.url)
            return false
        }

        // Start accessing
        if url.startAccessingSecurityScopedResource() {
            activeFolders.insert(folder.id)
            logger.debug("Started accessing: \(folder.path)")
            auditLog?.log(.folderAccessStarted, target: folder.path)
            return true
        }

        logger.error("Failed to start accessing: \(folder.path)")
        lastError = .accessDenied(folder.url)
        return false
    }

    /// Stop accessing a security-scoped resource
    /// Should be called when done with file operations
    /// - Parameter folder: The folder to stop accessing
    func stopAccessing(_ folder: AuthorizedFolder) {
        guard activeFolders.contains(folder.id) else { return }

        var isStale = false
        if let url = resolveBookmark(folder.bookmarkData, isStale: &isStale), !isStale {
            url.stopAccessingSecurityScopedResource()
        }

        activeFolders.remove(folder.id)
        logger.debug("Stopped accessing: \(folder.path)")
        auditLog?.log(.folderAccessStopped, target: folder.path)
    }

    /// Stop accessing all folders
    func stopAccessingAll() {
        for folder in authorizedFolders {
            stopAccessing(folder)
        }
    }

    /// Check if a folder is currently being accessed
    func isAccessing(_ folder: AuthorizedFolder) -> Bool {
        activeFolders.contains(folder.id)
    }

    // MARK: - Scoped Access Helper

    /// Execute a block with scoped access to a folder
    /// Automatically starts and stops access
    /// - Parameters:
    ///   - folder: The folder to access
    ///   - block: The block to execute with access
    /// - Returns: The result of the block
    func withAccess<T>(to folder: AuthorizedFolder, block: () throws -> T) rethrows -> T? {
        guard startAccessing(folder) else { return nil }
        defer { stopAccessing(folder) }
        return try block()
    }

    /// Execute an async block with scoped access to a folder
    func withAccess<T>(to folder: AuthorizedFolder, block: () async throws -> T) async rethrows -> T? {
        guard startAccessing(folder) else { return nil }
        defer { stopAccessing(folder) }
        return try await block()
    }

    // MARK: - Query Methods

    /// Check if a path is within an authorized folder
    func isPathAuthorized(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return authorizedFolders.contains { folder in
            url.path.hasPrefix(folder.url.path)
        }
    }

    /// Get the authorized folder containing a path
    func getAuthorizedFolder(for path: String) -> AuthorizedFolder? {
        let url = URL(fileURLWithPath: path)
        return authorizedFolders.first { folder in
            url.path.hasPrefix(folder.url.path)
        }
    }

    /// Check if a folder is already authorized
    func isAuthorized(_ url: URL) -> Bool {
        authorizedFolders.contains { $0.url == url }
    }

    // MARK: - Persistence

    private func saveBookmarks() {
        let data = authorizedFolders.map { folder -> [String: Any] in
            [
                "id": folder.id.uuidString,
                "bookmark": folder.bookmarkData,
                "createdAt": folder.createdAt.timeIntervalSince1970,
                "displayName": folder.displayName as Any
            ]
        }

        UserDefaults.standard.set(data, forKey: bookmarkKey)
        logger.info("Saved \(self.authorizedFolders.count) bookmarks")
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.array(forKey: bookmarkKey) as? [[String: Any]] else {
            logger.info("No saved bookmarks found")
            return
        }

        var loadedFolders: [AuthorizedFolder] = []
        var staleFolders: [String] = []

        for dict in data {
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let bookmarkData = dict["bookmark"] as? Data,
                  let createdAtInterval = dict["createdAt"] as? TimeInterval else {
                continue
            }

            // Try to resolve the bookmark
            var isStale = false
            guard let url = resolveBookmark(bookmarkData, isStale: &isStale) else {
                staleFolders.append(idString)
                continue
            }

            if isStale {
                // Try to refresh
                if let newBookmarkData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    let folder = AuthorizedFolder(
                        id: id,
                        url: url,
                        bookmarkData: newBookmarkData,
                        createdAt: Date(timeIntervalSince1970: createdAtInterval),
                        displayName: dict["displayName"] as? String
                    )
                    loadedFolders.append(folder)
                    logger.info("Refreshed stale bookmark: \(url.path)")
                } else {
                    staleFolders.append(idString)
                }
            } else {
                let folder = AuthorizedFolder(
                    id: id,
                    url: url,
                    bookmarkData: bookmarkData,
                    createdAt: Date(timeIntervalSince1970: createdAtInterval),
                    displayName: dict["displayName"] as? String
                )
                loadedFolders.append(folder)
            }
        }

        authorizedFolders = loadedFolders

        if !staleFolders.isEmpty {
            logger.warning("Removed \(staleFolders.count) stale bookmarks")
            // Save to remove stale entries
            saveBookmarks()
        }

        logger.info("Loaded \(loadedFolders.count) bookmarks")
    }

    // MARK: - Private Helpers

    private func resolveBookmark(_ bookmarkData: Data, isStale: inout Bool) -> URL? {
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    private func refreshStaleBookmark(_ folder: AuthorizedFolder, newURL: URL) -> AuthorizedFolder? {
        guard let newBookmarkData = try? newURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }

        let refreshed = AuthorizedFolder(
            id: folder.id,
            url: newURL,
            bookmarkData: newBookmarkData,
            createdAt: folder.createdAt,
            displayName: folder.displayName
        )

        // Update in list
        if let index = authorizedFolders.firstIndex(where: { $0.id == folder.id }) {
            authorizedFolders[index] = refreshed
            saveBookmarks()
        }

        logger.info("Refreshed stale bookmark for: \(newURL.path)")
        return refreshed
    }
}

// MARK: - Cleanup Presets

extension FileAccessManager {
    /// Standard cleanup presets
    static let defaultPresets: [CleanupPreset] = [
        CleanupPreset(
            name: "User Caches",
            suggestedPath: "~/Library/Caches",
            description: "Application cache files. Safe to delete, apps will recreate as needed.",
            estimatedSavings: "1-10 GB typical",
            icon: "folder.badge.gearshape",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "User Logs",
            suggestedPath: "~/Library/Logs",
            description: "Application log files. Useful for debugging but often not needed.",
            estimatedSavings: "100 MB - 1 GB typical",
            icon: "doc.text",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Crash Reports",
            suggestedPath: "~/Library/Application Support/CrashReporter",
            description: "Application crash reports. Can be deleted after reviewing.",
            estimatedSavings: "10-500 MB typical",
            icon: "exclamationmark.triangle",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Xcode Derived Data",
            suggestedPath: "~/Library/Developer/Xcode/DerivedData",
            description: "Xcode build caches. Safe to delete, will rebuild on next build.",
            estimatedSavings: "5-50 GB typical",
            icon: "hammer",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Xcode Archives",
            suggestedPath: "~/Library/Developer/Xcode/Archives",
            description: "Archived app builds. Only delete if you don't need to symbolicate old crashes.",
            estimatedSavings: "1-20 GB typical",
            icon: "archivebox",
            riskLevel: .caution
        ),
        CleanupPreset(
            name: "iOS Device Support",
            suggestedPath: "~/Library/Developer/Xcode/iOS DeviceSupport",
            description: "iOS device debugging symbols. Re-downloaded when you connect devices.",
            estimatedSavings: "5-30 GB typical",
            icon: "iphone",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Simulator Caches",
            suggestedPath: "~/Library/Developer/CoreSimulator/Caches",
            description: "iOS Simulator cache files. Safe to delete.",
            estimatedSavings: "1-5 GB typical",
            icon: "ipad.landscape",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Downloads",
            suggestedPath: "~/Downloads",
            description: "Your downloads folder. Review contents before cleaning.",
            estimatedSavings: "Varies",
            icon: "arrow.down.circle",
            riskLevel: .moderate
        ),
        CleanupPreset(
            name: "CocoaPods Cache",
            suggestedPath: "~/Library/Caches/CocoaPods",
            description: "Downloaded pod specs and sources. Re-downloaded on pod install.",
            estimatedSavings: "500 MB - 5 GB typical",
            icon: "shippingbox",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Swift Package Manager",
            suggestedPath: "~/Library/Caches/org.swift.swiftpm",
            description: "Swift package cache. Re-downloaded on build.",
            estimatedSavings: "500 MB - 2 GB typical",
            icon: "swift",
            riskLevel: .safe
        ),
        CleanupPreset(
            name: "Saved Application State",
            suggestedPath: "~/Library/Saved Application State",
            description: "App window positions and states. Apps start fresh after clearing.",
            estimatedSavings: "10-100 MB typical",
            icon: "rectangle.stack",
            riskLevel: .moderate
        )
    ]

    /// Get preset by name
    static func preset(named name: String) -> CleanupPreset? {
        defaultPresets.first { $0.name == name }
    }
}
