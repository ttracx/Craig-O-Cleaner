// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Cleaner/SafeCleanerService.swift
// Craig-O-Clean - Safe Cleaner Service
// Shared cleanup logic that works safely in both editions

import Foundation

/// Base cleaner service with safe operations that work in both editions.
/// Provides the core scanning and deletion logic for user-level caches.
@MainActor
public class SafeCleanerService: CleanerService {

    // MARK: - Properties

    internal let logger: Logger
    internal let fileManager: FileManager
    internal var cancelled: Bool = false

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var statusMessage: String = ""

    // MARK: - Initialization

    public init(logger: Logger, fileManager: FileManager = .default) {
        self.logger = logger
        self.fileManager = fileManager
    }

    // MARK: - CleanerService Protocol

    public func availableTargets() -> [CleanupTarget] {
        // Return only user-level targets that are safe for both editions
        CleanupTarget.userCacheTargets()
    }

    public func scanTargets(_ targets: [CleanupTarget]) async throws -> [CleanupScanResult] {
        isRunning = true
        progress = 0.0
        cancelled = false

        var results: [CleanupScanResult] = []
        let totalTargets = Double(targets.count)

        for (index, target) in targets.enumerated() {
            if cancelled {
                throw CleanupError.cancelled
            }

            statusMessage = "Scanning \(target.name)..."
            logger.debug("Scanning target: \(target.name)", category: .cleanup)

            do {
                let result = try await scanTarget(target)
                results.append(result)
            } catch {
                logger.warning("Failed to scan \(target.name): \(error.localizedDescription)", category: .cleanup)
                // Continue with other targets
                results.append(CleanupScanResult(
                    target: target,
                    files: [],
                    totalSize: 0,
                    errors: [.scanFailed(reason: error.localizedDescription)]
                ))
            }

            progress = Double(index + 1) / totalTargets
        }

        isRunning = false
        statusMessage = "Scan complete"
        return results
    }

    public func scanTarget(_ target: CleanupTarget) async throws -> CleanupScanResult {
        var scannedFiles: [ScannedFileItem] = []
        var totalSize: UInt64 = 0
        var errors: [CleanupError] = []

        for path in target.expandedPaths {
            if cancelled {
                throw CleanupError.cancelled
            }

            // Validate path is allowed
            guard isPathAllowed(path) else {
                errors.append(.pathNotAllowed(path: path))
                continue
            }

            // Check if path exists
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // Scan directory contents
                do {
                    let (files, size) = try await scanDirectory(at: path)
                    scannedFiles.append(contentsOf: files)
                    totalSize += size
                } catch {
                    errors.append(.scanFailed(reason: error.localizedDescription))
                }
            } else {
                // Single file
                if let item = scanFile(at: path) {
                    scannedFiles.append(item)
                    totalSize += item.size
                }
            }
        }

        var updatedTarget = target
        updatedTarget.estimatedSize = totalSize
        updatedTarget.fileCount = scannedFiles.count

        return CleanupScanResult(
            target: updatedTarget,
            files: scannedFiles,
            totalSize: totalSize,
            errors: errors
        )
    }

    public func runCleanup(targets: [CleanupTarget], dryRun: Bool) async throws -> CleanupSessionResult {
        isRunning = true
        progress = 0.0
        cancelled = false

        let startTime = Date()
        var results: [CleanupResult] = []
        let totalTargets = Double(targets.count)

        for (index, target) in targets.enumerated() {
            if cancelled {
                throw CleanupError.cancelled
            }

            statusMessage = "Cleaning \(target.name)..."
            logger.info("Cleaning target: \(target.name) (dryRun: \(dryRun))", category: .cleanup)

            let result = await cleanTarget(target, dryRun: dryRun)
            results.append(result)

            progress = Double(index + 1) / totalTargets
        }

        isRunning = false
        statusMessage = dryRun ? "Dry run complete" : "Cleanup complete"

        return CleanupSessionResult(
            results: results,
            startTime: startTime,
            endTime: Date()
        )
    }

    public func cancelCleanup() {
        cancelled = true
        statusMessage = "Cancelling..."
        logger.info("Cleanup cancellation requested", category: .cleanup)
    }

    // MARK: - Internal Methods

    /// Validates that a path is allowed for cleanup
    internal func isPathAllowed(_ path: String) -> Bool {
        // Base implementation allows only user home directory
        let home = NSHomeDirectory()
        return path.hasPrefix(home)
    }

    /// Scans a directory and returns file items and total size
    internal func scanDirectory(at path: String) async throws -> ([ScannedFileItem], UInt64) {
        var items: [ScannedFileItem] = []
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (items, totalSize)
        }

        while let url = enumerator.nextObject() as? URL {
            if cancelled {
                throw CleanupError.cancelled
            }

            do {
                let resourceValues = try url.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isDirectoryKey
                ])

                let isDirectory = resourceValues.isDirectory ?? false
                let size = UInt64(resourceValues.fileSize ?? 0)
                let modDate = resourceValues.contentModificationDate

                // Only count files, not directories themselves
                if !isDirectory {
                    let item = ScannedFileItem(
                        path: url.path,
                        name: url.lastPathComponent,
                        size: size,
                        modificationDate: modDate,
                        isDirectory: false
                    )
                    items.append(item)
                    totalSize += size
                }
            } catch {
                logger.debug("Failed to get attributes for \(url.path): \(error)", category: .cleanup)
            }
        }

        return (items, totalSize)
    }

    /// Scans a single file and returns its info
    internal func scanFile(at path: String) -> ScannedFileItem? {
        let url = URL(fileURLWithPath: path)

        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey
            ])

            return ScannedFileItem(
                path: path,
                name: url.lastPathComponent,
                size: UInt64(resourceValues.fileSize ?? 0),
                modificationDate: resourceValues.contentModificationDate,
                isDirectory: false
            )
        } catch {
            return nil
        }
    }

    /// Cleans a single target
    internal func cleanTarget(_ target: CleanupTarget, dryRun: Bool) async -> CleanupResult {
        let startTime = Date()
        var bytesFreed: UInt64 = 0
        var filesRemoved: Int = 0
        var errors: [CleanupError] = []

        for path in target.expandedPaths {
            if cancelled {
                return CleanupResult(
                    targetId: target.id,
                    targetName: target.name,
                    success: false,
                    bytesFreed: bytesFreed,
                    filesRemoved: filesRemoved,
                    errors: [.cancelled],
                    startTime: startTime,
                    endTime: Date()
                )
            }

            guard isPathAllowed(path) else {
                errors.append(.pathNotAllowed(path: path))
                continue
            }

            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // Clean directory contents (not the directory itself)
                do {
                    let contents = try fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.fileSizeKey],
                        options: [.skipsHiddenFiles]
                    )

                    for itemURL in contents {
                        if cancelled { break }

                        do {
                            let size = try itemURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0

                            if dryRun {
                                logger.debug("[DRY RUN] Would delete: \(itemURL.path)", category: .cleanup)
                            } else {
                                try fileManager.removeItem(at: itemURL)
                                logger.debug("Deleted: \(itemURL.path)", category: .cleanup)
                            }

                            bytesFreed += UInt64(size)
                            filesRemoved += 1
                        } catch {
                            logger.warning("Failed to delete \(itemURL.path): \(error)", category: .cleanup)
                            errors.append(.deletionFailed(path: itemURL.path, underlyingError: error.localizedDescription))
                        }
                    }
                } catch {
                    errors.append(.scanFailed(reason: error.localizedDescription))
                }
            } else {
                // Delete single file
                do {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0

                    if dryRun {
                        logger.debug("[DRY RUN] Would delete: \(path)", category: .cleanup)
                    } else {
                        try fileManager.removeItem(at: url)
                        logger.debug("Deleted: \(path)", category: .cleanup)
                    }

                    bytesFreed += UInt64(size)
                    filesRemoved += 1
                } catch {
                    errors.append(.deletionFailed(path: path, underlyingError: error.localizedDescription))
                }
            }
        }

        return CleanupResult(
            targetId: target.id,
            targetName: target.name,
            success: errors.isEmpty,
            bytesFreed: bytesFreed,
            filesRemoved: filesRemoved,
            errors: errors,
            startTime: startTime,
            endTime: Date()
        )
    }
}
