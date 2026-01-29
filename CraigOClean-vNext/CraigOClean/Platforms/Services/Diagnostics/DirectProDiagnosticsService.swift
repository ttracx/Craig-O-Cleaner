// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Diagnostics/DirectProDiagnosticsService.swift
// Craig-O-Clean - DirectPro Diagnostics Service
// Full-featured diagnostics for DirectPro edition

import Foundation

/// Diagnostics service for DirectPro edition with full system access.
@MainActor
public final class DirectProDiagnosticsService: BasicDiagnosticsService {

    // MARK: - Properties

    private let capabilities = DirectProCapabilities.shared

    public override var canInspectFullDisk: Bool { true }
    public override var canExportReports: Bool { true }

    // MARK: - Initialization

    public override init(logger: Logger, fileManager: FileManager = .default) {
        super.init(logger: logger, fileManager: fileManager)
        logger.debug("DirectProDiagnosticsService initialized", category: .diagnostics)
    }

    // MARK: - Override Cache Info to Include System Caches

    public override func collectCacheInfo() async -> CacheInfo {
        let home = NSHomeDirectory()

        // Calculate user cache size
        let userCacheSize = await calculateDirectorySize("\(home)/Library/Caches")

        // Calculate system cache size (Pro only)
        let systemCacheSize = await calculateDirectorySize("/Library/Caches")

        // Calculate log size (including system logs)
        let userLogSize = await calculateDirectorySize("\(home)/Library/Logs")
        let systemLogSize = await calculateDirectorySize("/Library/Logs")
        let totalLogSize = userLogSize + systemLogSize

        // Calculate temp files size
        let tempSize = await calculateDirectorySize(NSTemporaryDirectory())

        return CacheInfo(
            userCacheSize: userCacheSize,
            systemCacheSize: systemCacheSize,
            logSize: totalLogSize,
            tempFilesSize: tempSize
        )
    }

    // MARK: - Full Disk Inspection

    public override func collectDiskInfo() async -> DiskInfo? {
        // Try to get root volume info for more complete picture
        let rootURL = URL(fileURLWithPath: "/")

        do {
            let values = try rootURL.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeLocalizedFormatDescriptionKey
            ])

            return DiskInfo(
                volumeName: values.volumeName ?? "Macintosh HD",
                fileSystemType: values.volumeLocalizedFormatDescription ?? "APFS",
                totalCapacity: UInt64(values.volumeTotalCapacity ?? 0),
                availableCapacity: UInt64(values.volumeAvailableCapacity ?? 0),
                mountPoint: "/"
            )
        } catch {
            logger.warning("Failed to get disk info: \(error)", category: .diagnostics)
            return await super.collectDiskInfo()
        }
    }

    // MARK: - Report Export

    public override func exportReport(_ report: DiagnosticReport, to url: URL) async throws {
        logger.info("Exporting diagnostic report to \(url.path)", category: .diagnostics)

        let reportText = report.exportAsText()

        do {
            try reportText.write(to: url, atomically: true, encoding: .utf8)
            logger.info("Report exported successfully", category: .diagnostics)
        } catch {
            logger.error("Failed to export report: \(error)", category: .diagnostics)
            throw DiagnosticsError.exportFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Additional Pro Features

    /// Collects detailed disk usage breakdown
    public func collectDetailedDiskUsage() async -> [DiskUsageItem] {
        logger.debug("Collecting detailed disk usage", category: .diagnostics)

        var items: [DiskUsageItem] = []
        let home = NSHomeDirectory()

        // Key directories to analyze
        let directories: [(String, String)] = [
            ("\(home)/Library", "Library"),
            ("\(home)/Documents", "Documents"),
            ("\(home)/Downloads", "Downloads"),
            ("\(home)/Desktop", "Desktop"),
            ("\(home)/Movies", "Movies"),
            ("\(home)/Music", "Music"),
            ("\(home)/Pictures", "Pictures"),
            ("\(home)/Developer", "Developer"),
            ("/Applications", "Applications"),
            ("/Library", "System Library")
        ]

        for (path, name) in directories {
            let size = await calculateDirectorySize(path)
            if size > 0 {
                items.append(DiskUsageItem(name: name, path: path, size: size))
            }
        }

        // Sort by size descending
        items.sort { $0.size > $1.size }

        return items
    }

    /// Collects process information
    public func collectProcessInfo() -> [ProcessInfoItem] {
        // TODO: Implement process listing
        // This would use NSWorkspace or ps command
        return []
    }
}

// MARK: - Supporting Types

public struct DiskUsageItem: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let size: UInt64

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

public struct ProcessInfoItem: Identifiable, Sendable {
    public let id = UUID()
    public let pid: Int32
    public let name: String
    public let memoryUsage: UInt64
    public let cpuUsage: Double
}
