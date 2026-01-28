// MARK: - CleanerService.swift
// Craig-O-Clean - Sandbox-Compliant Cleanup Service
// Provides user-scoped file cleanup with security-scoped bookmarks, dry-run preview, and confirmation

import Foundation
import AppKit
import Combine
import os.log

// MARK: - Cleaner Service

@MainActor
final class CleanerService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var authorizedFolders: [AuthorizedFolder] = []
    @Published private(set) var lastScanResults: ScanResults?
    @Published private(set) var lastCleanupResult: CleanupResult?
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var cleanProgress: Double = 0
    @Published private(set) var lastError: CraigOCleanError?

    // MARK: - Dependencies

    private let fileAccessManager: FileAccessManager
    private let auditLog: AuditLogService
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "CleanerService")

    // MARK: - Initialization

    init(fileAccessManager: FileAccessManager, auditLog: AuditLogService) {
        self.fileAccessManager = fileAccessManager
        self.auditLog = auditLog

        // Sync authorized folders
        self.authorizedFolders = fileAccessManager.authorizedFolders
    }

    // MARK: - Folder Authorization

    /// Authorize a new folder for cleanup
    func authorizeFolder(suggestedPath: String? = nil) async -> AuthorizedFolder? {
        let folder = await fileAccessManager.authorizeFolder(
            suggestedPath: suggestedPath,
            message: "Select a folder to enable cleanup. Craig-O-Clean will only delete files within this folder."
        )

        if let folder = folder {
            authorizedFolders = fileAccessManager.authorizedFolders
            auditLog.log(.folderAuthorized, target: folder.path)
        }

        return folder
    }

    /// Authorize a preset folder
    func authorizePreset(_ preset: CleanupPreset) async -> AuthorizedFolder? {
        return await authorizeFolder(suggestedPath: preset.expandedPath)
    }

    /// Remove authorization for a folder
    func revokeAuthorization(for folder: AuthorizedFolder) {
        fileAccessManager.removeAuthorization(for: folder)
        authorizedFolders = fileAccessManager.authorizedFolders
    }

    /// Check if a preset is already authorized
    func isPresetAuthorized(_ preset: CleanupPreset) -> AuthorizedFolder? {
        let expandedPath = preset.expandedPath
        return authorizedFolders.first { folder in
            expandedPath.hasPrefix(folder.path) || folder.path.hasPrefix(expandedPath)
        }
    }

    // MARK: - Dry Run (Preview)

    /// Scan a folder and return what would be cleaned
    /// This does NOT delete anything
    func dryRun(folder: AuthorizedFolder, options: CleanupScanOptions = .default) async -> ScanResults {
        logger.info("Starting dry run for: \(folder.path)")
        auditLog.log(.cleanupDryRun, target: folder.path)

        isScanning = true
        scanProgress = 0
        lastError = nil

        defer {
            isScanning = false
            scanProgress = 1.0
        }

        // Start accessing the folder
        guard fileAccessManager.startAccessing(folder) else {
            let error = CraigOCleanError.accessDenied(folder.url)
            lastError = error
            auditLog.logError(.cleanupDryRun, target: folder.path, error: error)
            return ScanResults(error: error)
        }
        defer { fileAccessManager.stopAccessing(folder) }

        let startTime = Date()
        var results = ScanResults()
        results.folder = folder

        let fileManager = FileManager.default

        // Enumerate files
        guard let enumerator = fileManager.enumerator(
            at: folder.url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .typeIdentifierKey],
            options: options.includeHidden ? [] : [.skipsHiddenFiles]
        ) else {
            let error = CraigOCleanError.fileOperationFailed(folder.url, operation: .enumerate, underlying: nil)
            lastError = error
            return ScanResults(error: error)
        }

        var fileCount = 0
        let maxFiles = 10000 // Safety limit

        while let fileURL = enumerator.nextObject() as? URL {
            fileCount += 1
            if fileCount > maxFiles {
                logger.warning("Reached max file limit (\(maxFiles)) during scan")
                break
            }

            // Update progress periodically
            if fileCount % 100 == 0 {
                scanProgress = min(0.9, Double(fileCount) / 1000.0)
            }

            // Check if it's a file (not directory)
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .typeIdentifierKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            // Apply filters
            if let minAge = options.minAgeDays {
                guard let modDate = resourceValues.contentModificationDate else { continue }
                let age = Date().timeIntervalSince(modDate) / 86400 // days
                guard age >= Double(minAge) else { continue }
            }

            if let minSize = options.minSizeBytes {
                guard let size = resourceValues.fileSize, UInt64(size) >= minSize else { continue }
            }

            if let pattern = options.filePattern {
                guard fileURL.lastPathComponent.range(of: pattern, options: .regularExpression) != nil else { continue }
            }

            // Add to results
            let file = ScannedFile(
                url: fileURL,
                size: UInt64(resourceValues.fileSize ?? 0),
                modificationDate: resourceValues.contentModificationDate,
                fileType: resourceValues.typeIdentifier ?? "public.item"
            )

            results.files.append(file)
            results.totalSize += file.size
        }

        results.scanDuration = Date().timeIntervalSince(startTime)
        lastScanResults = results

        logger.info("Dry run complete: \(results.files.count) files, \(results.totalSize) bytes")

        return results
    }

    /// Scan multiple folders
    func dryRunMultiple(folders: [AuthorizedFolder], options: CleanupScanOptions = .default) async -> [ScanResults] {
        var allResults: [ScanResults] = []

        for (index, folder) in folders.enumerated() {
            scanProgress = Double(index) / Double(folders.count)
            let results = await dryRun(folder: folder, options: options)
            allResults.append(results)
        }

        return allResults
    }

    // MARK: - Cleanup Execution

    /// Execute cleanup after user confirmation
    /// Requires prior dry run results and explicit confirmation
    func executeCleanup(scanResults: ScanResults, confirmed: Bool) async -> CleanupResult {
        guard confirmed else {
            return CleanupResult(
                deletedCount: 0,
                failedCount: 0,
                freedSpace: 0,
                errors: [],
                skippedFiles: [],
                duration: 0
            )
        }

        guard let folder = scanResults.folder else {
            lastError = .invalidConfiguration(description: "No folder in scan results")
            return CleanupResult.empty
        }

        logger.info("Starting cleanup for: \(folder.path) with \(scanResults.files.count) files")
        auditLog.log(.cleanupStarted, target: folder.path, metadata: [
            "fileCount": "\(scanResults.files.count)",
            "totalSize": "\(scanResults.totalSize)"
        ])

        isCleaning = true
        cleanProgress = 0
        lastError = nil

        defer {
            isCleaning = false
            cleanProgress = 1.0
        }

        // Start accessing the folder
        guard fileAccessManager.startAccessing(folder) else {
            let error = CraigOCleanError.accessDenied(folder.url)
            lastError = error
            auditLog.logError(.cleanupFailed, target: folder.path, error: error)
            return CleanupResult.empty
        }
        defer { fileAccessManager.stopAccessing(folder) }

        let startTime = Date()
        let fileManager = FileManager.default
        var deletedCount = 0
        var failedCount = 0
        var freedSpace: UInt64 = 0
        var errors: [CleanupError] = []
        var skippedFiles: [URL] = []

        let totalFiles = scanResults.files.count

        for (index, file) in scanResults.files.enumerated() {
            cleanProgress = Double(index) / Double(totalFiles)

            // Verify file still exists
            guard fileManager.fileExists(atPath: file.url.path) else {
                skippedFiles.append(file.url)
                continue
            }

            // Verify file is within authorized scope
            guard file.url.path.hasPrefix(folder.path) else {
                logger.warning("Skipping file outside authorized scope: \(file.url.path)")
                skippedFiles.append(file.url)
                continue
            }

            do {
                try fileManager.removeItem(at: file.url)
                deletedCount += 1
                freedSpace += file.size

                // Log individual file deletion (batch these for performance)
                if deletedCount % 50 == 0 {
                    logger.debug("Deleted \(deletedCount) files so far...")
                }
            } catch {
                failedCount += 1
                let cleanupError = CleanupError(
                    url: file.url,
                    reason: error.localizedDescription,
                    underlying: error
                )
                errors.append(cleanupError)

                logger.warning("Failed to delete \(file.url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        let result = CleanupResult(
            deletedCount: deletedCount,
            failedCount: failedCount,
            freedSpace: freedSpace,
            errors: errors,
            skippedFiles: skippedFiles,
            duration: duration
        )

        lastCleanupResult = result

        // Log completion
        if result.success {
            auditLog.log(.cleanupCompleted, target: folder.path, metadata: [
                "deletedCount": "\(deletedCount)",
                "freedSpace": "\(freedSpace)",
                "duration": String(format: "%.2f", duration)
            ])
        } else {
            auditLog.logError(.cleanupFailed, target: folder.path, errorMessage: "Failed to delete \(failedCount) files")
        }

        logger.info("Cleanup complete: \(deletedCount) deleted, \(failedCount) failed, \(freedSpace) bytes freed")

        return result
    }

    // MARK: - Quick Cleanup

    /// Perform a quick cleanup of an authorized folder with default options
    /// Still requires confirmation
    func quickCleanup(folder: AuthorizedFolder, confirmed: Bool) async -> CleanupResult {
        let scanResults = await dryRun(folder: folder)

        guard scanResults.success else {
            return CleanupResult.empty
        }

        return await executeCleanup(scanResults: scanResults, confirmed: confirmed)
    }

    // MARK: - Trash Operations

    /// Empty trash via Finder AppleScript (requires automation permission)
    func emptyTrash() async -> ActionResult<UInt64> {
        logger.info("Emptying trash via Finder")

        let script = """
        tell application "Finder"
            empty the trash
        end tell
        """

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(.operationFailed(description: "Service deallocated", underlying: nil)))
                    return
                }

                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(returning: .failure(.scriptCompilationFailed(description: "Failed to create AppleScript")))
                    return
                }

                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)

                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"

                    if errorNumber == -1743 || errorNumber == -10004 {
                        continuation.resume(returning: .failure(.appleScriptPermissionDenied(targetApp: "Finder")))
                    } else {
                        continuation.resume(returning: .failure(.scriptExecutionFailed(errorCode: errorNumber, description: errorMessage)))
                    }
                    return
                }

                self.auditLog.log(.folderCleared, target: "Trash")
                continuation.resume(returning: .success(0)) // Can't easily get trash size
            }
        }
    }

    /// Get trash size (approximate, uses home directory .Trash)
    func getTrashSize() async -> UInt64 {
        let trashURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")

        guard let enumerator = FileManager.default.enumerator(
            at: trashURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: UInt64 = 0

        while let fileURL = enumerator.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += UInt64(size)
            }
        }

        return totalSize
    }
}

// MARK: - Cleanup Scan Options

struct CleanupScanOptions {
    var includeHidden: Bool = false
    var includeSubfolders: Bool = true
    var minAgeDays: Int? = nil
    var minSizeBytes: UInt64? = nil
    var filePattern: String? = nil
    var excludePatterns: [String] = []

    static let `default` = CleanupScanOptions()

    static let cacheCleanup = CleanupScanOptions(
        includeHidden: false,
        includeSubfolders: true,
        minAgeDays: nil,
        minSizeBytes: nil
    )

    static let oldFilesCleanup = CleanupScanOptions(
        includeHidden: false,
        includeSubfolders: true,
        minAgeDays: 7,
        minSizeBytes: nil
    )

    static let largeFilesCleanup = CleanupScanOptions(
        includeHidden: false,
        includeSubfolders: true,
        minAgeDays: nil,
        minSizeBytes: 100 * 1024 * 1024 // 100MB
    )
}

// MARK: - Cleanup Statistics

extension CleanerService {

    struct CleanupStatistics {
        let totalAuthorizedFolders: Int
        let totalScannedFiles: Int
        let totalScannedSize: UInt64
        let totalDeletedFiles: Int
        let totalFreedSpace: UInt64
        let lastCleanupDate: Date?
    }

    func getStatistics() -> CleanupStatistics {
        CleanupStatistics(
            totalAuthorizedFolders: authorizedFolders.count,
            totalScannedFiles: lastScanResults?.files.count ?? 0,
            totalScannedSize: lastScanResults?.totalSize ?? 0,
            totalDeletedFiles: lastCleanupResult?.deletedCount ?? 0,
            totalFreedSpace: lastCleanupResult?.freedSpace ?? 0,
            lastCleanupDate: lastCleanupResult != nil ? Date() : nil
        )
    }
}

// MARK: - File Type Analysis

extension CleanerService {

    struct FileTypeBreakdown {
        let type: String
        let count: Int
        let totalSize: UInt64
        let percentage: Double
    }

    func analyzeFileTypes(from results: ScanResults) -> [FileTypeBreakdown] {
        var typeMap: [String: (count: Int, size: UInt64)] = [:]

        for file in results.files {
            let type = simplifyFileType(file.fileType)
            var entry = typeMap[type] ?? (count: 0, size: 0)
            entry.count += 1
            entry.size += file.size
            typeMap[type] = entry
        }

        let total = results.totalSize

        return typeMap.map { type, data in
            FileTypeBreakdown(
                type: type,
                count: data.count,
                totalSize: data.size,
                percentage: total > 0 ? Double(data.size) / Double(total) * 100 : 0
            )
        }.sorted { $0.totalSize > $1.totalSize }
    }

    private func simplifyFileType(_ uti: String) -> String {
        if uti.contains("image") { return "Images" }
        if uti.contains("video") { return "Videos" }
        if uti.contains("audio") { return "Audio" }
        if uti.contains("text") || uti.contains("log") { return "Text/Logs" }
        if uti.contains("archive") || uti.contains("zip") { return "Archives" }
        if uti.contains("cache") { return "Cache" }
        if uti.contains("database") || uti.contains("sqlite") { return "Databases" }
        return "Other"
    }
}

// MARK: - Formatting Helpers

extension CleanerService {

    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0f ms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1f sec", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        }
    }
}
