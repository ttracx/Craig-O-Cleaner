import Foundation

// MARK: - Disk Manager
/// Disk space management, analysis, and cleanup for macOS Silicon
/// Handles temporary files, downloads, trash, and large file detection

@MainActor
public final class DiskManager: ObservableObject {

    // MARK: - Types

    public struct DiskInfo: Sendable {
        public let volumeName: String
        public let mountPoint: String
        public let totalBytes: UInt64
        public let usedBytes: UInt64
        public let freeBytes: UInt64
        public let fileSystem: String

        public var usedPercent: Double {
            Double(usedBytes) / Double(totalBytes) * 100
        }

        public var freePercent: Double {
            Double(freeBytes) / Double(totalBytes) * 100
        }

        public var totalGB: Double {
            Double(totalBytes) / 1_073_741_824
        }

        public var freeGB: Double {
            Double(freeBytes) / 1_073_741_824
        }

        public var summary: String {
            let total = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
            let free = ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .file)
            return "\(volumeName): \(free) free of \(total) (\(String(format: "%.1f", freePercent))% available)"
        }
    }

    public struct LargeFile: Identifiable, Sendable {
        public let id = UUID()
        public let path: String
        public let name: String
        public let sizeBytes: UInt64
        public let modificationDate: Date?
        public let fileType: FileType

        public enum FileType: String, Sendable {
            case video = "Video"
            case image = "Image"
            case archive = "Archive"
            case disk = "Disk Image"
            case application = "Application"
            case document = "Document"
            case other = "Other"
        }

        public var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
        }
    }

    public struct CleanupTarget: Identifiable, Sendable {
        public let id = UUID()
        public let name: String
        public let path: String
        public let description: String
        public let estimatedSize: UInt64
        public let safeToDelete: Bool
        public let category: CleanupCategory

        public enum CleanupCategory: String, Sendable {
            case temporary = "Temporary Files"
            case downloads = "Downloads"
            case trash = "Trash"
            case logs = "Log Files"
            case crashReports = "Crash Reports"
            case applicationData = "Application Data"
            case developer = "Developer Files"
            case mail = "Mail Data"
            case messages = "Messages Data"
        }
    }

    public struct DiskCleanupResult {
        public let spaceFreed: UInt64
        public let filesDeleted: Int
        public let errors: [String]
        public let duration: TimeInterval

        public var summary: String {
            let freed = ByteCountFormatter.string(fromByteCount: Int64(spaceFreed), countStyle: .file)
            return "Freed \(freed), deleted \(filesDeleted) files in \(String(format: "%.1f", duration))s"
        }
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var diskInfo: DiskInfo?
    @Published public private(set) var largeFiles: [LargeFile] = []
    @Published public private(set) var cleanupTargets: [CleanupTarget] = []

    // MARK: - Cleanup Locations

    public static let cleanupLocations: [CleanupTarget] = [
        // Temporary files
        CleanupTarget(
            name: "System Temp",
            path: "/private/var/tmp",
            description: "System temporary files",
            estimatedSize: 0,
            safeToDelete: true,
            category: .temporary
        ),
        CleanupTarget(
            name: "User Temp Items",
            path: "~/Library/Caches/TemporaryItems",
            description: "User temporary items",
            estimatedSize: 0,
            safeToDelete: true,
            category: .temporary
        ),
        CleanupTarget(
            name: "Private Folders",
            path: "/private/var/folders",
            description: "Per-user temp caches",
            estimatedSize: 0,
            safeToDelete: true,
            category: .temporary
        ),

        // Downloads
        CleanupTarget(
            name: "DMG Files",
            path: "~/Downloads/*.dmg",
            description: "Downloaded disk images",
            estimatedSize: 0,
            safeToDelete: true,
            category: .downloads
        ),
        CleanupTarget(
            name: "PKG Files",
            path: "~/Downloads/*.pkg",
            description: "Downloaded packages",
            estimatedSize: 0,
            safeToDelete: true,
            category: .downloads
        ),
        CleanupTarget(
            name: "ZIP Files",
            path: "~/Downloads/*.zip",
            description: "Downloaded archives",
            estimatedSize: 0,
            safeToDelete: true,
            category: .downloads
        ),

        // Trash
        CleanupTarget(
            name: "User Trash",
            path: "~/.Trash",
            description: "User trash bin",
            estimatedSize: 0,
            safeToDelete: true,
            category: .trash
        ),
        CleanupTarget(
            name: "Volume Trashes",
            path: "/Volumes/*/.Trashes",
            description: "External volume trashes",
            estimatedSize: 0,
            safeToDelete: true,
            category: .trash
        ),

        // Logs
        CleanupTarget(
            name: "User Logs",
            path: "~/Library/Logs",
            description: "Application log files",
            estimatedSize: 0,
            safeToDelete: true,
            category: .logs
        ),
        CleanupTarget(
            name: "System Logs",
            path: "/private/var/log",
            description: "System log files",
            estimatedSize: 0,
            safeToDelete: true,
            category: .logs
        ),
        CleanupTarget(
            name: "ASL Logs",
            path: "/private/var/log/asl",
            description: "Apple System Logs",
            estimatedSize: 0,
            safeToDelete: true,
            category: .logs
        ),

        // Crash reports
        CleanupTarget(
            name: "Crash Reports",
            path: "~/Library/Application Support/CrashReporter",
            description: "Application crash reports",
            estimatedSize: 0,
            safeToDelete: true,
            category: .crashReports
        ),
        CleanupTarget(
            name: "Diagnostic Reports",
            path: "~/Library/Logs/DiagnosticReports",
            description: "System diagnostic reports",
            estimatedSize: 0,
            safeToDelete: true,
            category: .crashReports
        ),

        // Application data
        CleanupTarget(
            name: "Saved App States",
            path: "~/Library/Saved Application State",
            description: "Saved application states",
            estimatedSize: 0,
            safeToDelete: true,
            category: .applicationData
        ),

        // Developer
        CleanupTarget(
            name: "Xcode Derived Data",
            path: "~/Library/Developer/Xcode/DerivedData",
            description: "Xcode build artifacts",
            estimatedSize: 0,
            safeToDelete: true,
            category: .developer
        ),
        CleanupTarget(
            name: "iOS Device Support",
            path: "~/Library/Developer/Xcode/iOS DeviceSupport",
            description: "iOS device symbols",
            estimatedSize: 0,
            safeToDelete: true,
            category: .developer
        ),
        CleanupTarget(
            name: "Simulators",
            path: "~/Library/Developer/CoreSimulator/Devices",
            description: "iOS Simulator devices",
            estimatedSize: 0,
            safeToDelete: true,
            category: .developer
        ),

        // Mail & Messages
        CleanupTarget(
            name: "Mail Downloads",
            path: "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
            description: "Mail attachment downloads",
            estimatedSize: 0,
            safeToDelete: true,
            category: .mail
        ),
        CleanupTarget(
            name: "Messages Attachments",
            path: "~/Library/Messages/Attachments",
            description: "iMessage attachments",
            estimatedSize: 0,
            safeToDelete: true,
            category: .messages
        )
    ]

    // MARK: - Disk Information

    /// Get disk usage for root volume
    public func getDiskInfo() async throws -> DiskInfo {
        let result = try await executor.execute("df -k / | tail -1")

        let components = result.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 6 else {
            throw CommandExecutor.CommandError.executionFailed("Failed to parse disk info")
        }

        let totalKB = UInt64(components[1]) ?? 0
        let usedKB = UInt64(components[2]) ?? 0
        let freeKB = UInt64(components[3]) ?? 0
        let mountPoint = components[components.count - 1]

        // Get volume name
        let volumeResult = try? await executor.execute("diskutil info / | grep 'Volume Name' | cut -d: -f2")
        let volumeName = volumeResult?.output.trimmingCharacters(in: .whitespaces) ?? "Macintosh HD"

        // Get file system
        let fsResult = try? await executor.execute("diskutil info / | grep 'Type (Bundle)' | cut -d: -f2")
        let fileSystem = fsResult?.output.trimmingCharacters(in: .whitespaces) ?? "APFS"

        let info = DiskInfo(
            volumeName: volumeName,
            mountPoint: mountPoint,
            totalBytes: totalKB * 1024,
            usedBytes: usedKB * 1024,
            freeBytes: freeKB * 1024,
            fileSystem: fileSystem
        )

        diskInfo = info
        return info
    }

    /// Get disk usage percentage
    public func getDiskUsagePercent() async -> Double {
        guard let info = try? await getDiskInfo() else { return 0 }
        return info.usedPercent
    }

    /// Get free space in bytes
    public func getFreeSpace() async -> UInt64 {
        guard let info = try? await getDiskInfo() else { return 0 }
        return info.freeBytes
    }

    // MARK: - Large File Detection

    /// Find large files in home directory
    public func findLargeFiles(minimumMB: Int = 100, limit: Int = 50) async -> [LargeFile] {
        let result = try? await executor.execute(
            "find ~ -type f -size +\(minimumMB)M 2>/dev/null | head -\(limit)"
        )

        guard let output = result?.output, !output.isEmpty else {
            return []
        }

        var files: [LargeFile] = []
        let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for path in paths {
            if let file = await getLargeFileInfo(path: path) {
                files.append(file)
            }
        }

        largeFiles = files.sorted { $0.sizeBytes > $1.sizeBytes }
        return largeFiles
    }

    /// Get info for a specific large file
    private func getLargeFileInfo(path: String) async -> LargeFile? {
        let result = try? await executor.execute("stat -f '%z %m' \"\(path)\" 2>/dev/null")
        guard let output = result?.output else { return nil }

        let parts = output.components(separatedBy: " ")
        guard parts.count >= 2,
              let size = UInt64(parts[0]),
              let timestamp = Double(parts[1]) else {
            return nil
        }

        let name = (path as NSString).lastPathComponent
        let ext = (name as NSString).pathExtension.lowercased()

        let fileType: LargeFile.FileType
        switch ext {
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv":
            fileType = .video
        case "jpg", "jpeg", "png", "gif", "heic", "raw", "tiff":
            fileType = .image
        case "zip", "tar", "gz", "rar", "7z":
            fileType = .archive
        case "dmg", "iso", "img":
            fileType = .disk
        case "app":
            fileType = .application
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx":
            fileType = .document
        default:
            fileType = .other
        }

        return LargeFile(
            path: path,
            name: name,
            sizeBytes: size,
            modificationDate: Date(timeIntervalSince1970: timestamp),
            fileType: fileType
        )
    }

    // MARK: - Cleanup Operations

    /// Clean temporary files
    public func cleanTemporaryFiles() async throws -> DiskCleanupResult {
        let startTime = Date()
        var spaceFreed: UInt64 = 0
        var filesDeleted = 0
        var errors: [String] = []

        let tempLocations = Self.cleanupLocations.filter { $0.category == .temporary }

        for location in tempLocations {
            let result = await cleanLocation(location)
            spaceFreed += result.freed
            filesDeleted += result.files
            if let error = result.error { errors.append(error) }
        }

        return DiskCleanupResult(
            spaceFreed: spaceFreed,
            filesDeleted: filesDeleted,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Clean downloads (installers only)
    public func cleanDownloadInstallers() async throws -> DiskCleanupResult {
        let startTime = Date()
        var spaceFreed: UInt64 = 0
        var filesDeleted = 0
        var errors: [String] = []

        let downloadLocations = Self.cleanupLocations.filter { $0.category == .downloads }

        for location in downloadLocations {
            let result = await cleanLocation(location)
            spaceFreed += result.freed
            filesDeleted += result.files
            if let error = result.error { errors.append(error) }
        }

        return DiskCleanupResult(
            spaceFreed: spaceFreed,
            filesDeleted: filesDeleted,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Empty all trash
    public func emptyTrash() async throws -> DiskCleanupResult {
        let startTime = Date()

        // Get size before
        let userTrashSize = await getDirectorySize("~/.Trash")

        // Empty user trash
        _ = try await executor.execute("rm -rf ~/.Trash/* 2>/dev/null")

        // Empty volume trashes
        _ = try await executor.execute("sudo rm -rf /Volumes/*/.Trashes/* 2>/dev/null")

        let afterSize = await getDirectorySize("~/.Trash")
        let freed = userTrashSize > afterSize ? userTrashSize - afterSize : 0

        return DiskCleanupResult(
            spaceFreed: freed,
            filesDeleted: 0, // Unknown count
            errors: [],
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Clean log files (older than days)
    public func cleanOldLogs(olderThanDays: Int = 7) async throws -> DiskCleanupResult {
        let startTime = Date()

        // Clean user logs
        let userLogResult = try await executor.execute(
            "find ~/Library/Logs -type f -mtime +\(olderThanDays) -delete 2>/dev/null; echo $?"
        )

        // Clean system logs
        let sysLogResult = try await executor.execute(
            "sudo find /var/log -name '*.log' -type f -mtime +\(olderThanDays) -delete 2>/dev/null; echo $?"
        )

        return DiskCleanupResult(
            spaceFreed: 0, // Can't easily calculate
            filesDeleted: 0,
            errors: userLogResult.isSuccess && sysLogResult.isSuccess ? [] : ["Some log cleanup failed"],
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Clean crash reports
    public func cleanCrashReports() async throws -> DiskCleanupResult {
        let startTime = Date()

        let crashLocations = Self.cleanupLocations.filter { $0.category == .crashReports }
        var spaceFreed: UInt64 = 0

        for location in crashLocations {
            let result = await cleanLocation(location)
            spaceFreed += result.freed
        }

        return DiskCleanupResult(
            spaceFreed: spaceFreed,
            filesDeleted: 0,
            errors: [],
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Clean developer files
    public func cleanDeveloperFiles() async throws -> DiskCleanupResult {
        let startTime = Date()

        let devLocations = Self.cleanupLocations.filter { $0.category == .developer }
        var spaceFreed: UInt64 = 0

        for location in devLocations {
            let result = await cleanLocation(location)
            spaceFreed += result.freed
        }

        // Delete unavailable simulators
        _ = try? await executor.execute("xcrun simctl delete unavailable 2>/dev/null")

        return DiskCleanupResult(
            spaceFreed: spaceFreed,
            filesDeleted: 0,
            errors: [],
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Run comprehensive disk cleanup
    public func performFullCleanup() async throws -> DiskCleanupResult {
        let startTime = Date()
        var totalFreed: UInt64 = 0
        var totalFiles = 0
        var allErrors: [String] = []

        // Temporary files
        let tempResult = try await cleanTemporaryFiles()
        totalFreed += tempResult.spaceFreed
        totalFiles += tempResult.filesDeleted
        allErrors.append(contentsOf: tempResult.errors)

        // Logs
        let logsResult = try await cleanOldLogs()
        totalFreed += logsResult.spaceFreed
        allErrors.append(contentsOf: logsResult.errors)

        // Crash reports
        let crashResult = try await cleanCrashReports()
        totalFreed += crashResult.spaceFreed
        allErrors.append(contentsOf: crashResult.errors)

        // Empty trash
        let trashResult = try await emptyTrash()
        totalFreed += trashResult.spaceFreed
        allErrors.append(contentsOf: trashResult.errors)

        return DiskCleanupResult(
            spaceFreed: totalFreed,
            filesDeleted: totalFiles,
            errors: allErrors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Time Machine

    /// List local Time Machine snapshots
    public func listLocalSnapshots() async -> [String] {
        let result = try? await executor.execute("tmutil listlocalsnapshots / 2>/dev/null")
        guard let output = result?.output else { return [] }

        return output.components(separatedBy: .newlines)
            .filter { $0.contains("com.apple.TimeMachine") }
            .compactMap { line in
                line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
            }
    }

    /// Delete old Time Machine snapshots
    public func deleteOldSnapshots(keepLast: Int = 1) async throws {
        let snapshots = await listLocalSnapshots()
        let toDelete = snapshots.dropLast(keepLast)

        for snapshot in toDelete {
            _ = try await executor.executePrivileged("tmutil deletelocalsnapshots \(snapshot)")
        }
    }

    /// Thin local snapshots to free space
    public func thinLocalSnapshots(freeUpBytes: UInt64) async throws {
        _ = try await executor.executePrivileged("tmutil thinlocalsnapshots / \(freeUpBytes) 4")
    }

    // MARK: - Helpers

    private func cleanLocation(_ target: CleanupTarget) async -> (freed: UInt64, files: Int, error: String?) {
        let expandedPath = (target.path as NSString).expandingTildeInPath

        // Get size before
        let beforeSize = await getDirectorySize(expandedPath)

        // Determine command based on path pattern
        let command: String
        if target.path.contains("*") {
            command = "rm -rf \(expandedPath) 2>/dev/null"
        } else {
            command = "rm -rf \"\(expandedPath)\"/* 2>/dev/null"
        }

        let needsSudo = target.path.hasPrefix("/private") || target.path.hasPrefix("/var")
        let result = needsSudo ?
            try? await executor.executePrivileged(command) :
            try? await executor.execute(command)

        let afterSize = await getDirectorySize(expandedPath)
        let freed = beforeSize > afterSize ? beforeSize - afterSize : 0

        return (freed, 0, result?.isSuccess == false ? result?.error : nil)
    }

    private func getDirectorySize(_ path: String) async -> UInt64 {
        let expandedPath = (path as NSString).expandingTildeInPath
        let result = try? await executor.execute("du -sk \"\(expandedPath)\" 2>/dev/null | cut -f1")
        guard let sizeStr = result?.output.trimmingCharacters(in: .whitespacesAndNewlines),
              let sizeKB = UInt64(sizeStr) else {
            return 0
        }
        return sizeKB * 1024
    }
}

// MARK: - Disk Commands Reference

public enum DiskCommands {

    // Information
    public static let diskFree = "df -h /"
    public static let diskUsage = "du -sh ~/*"
    public static let largeFiles = "find ~ -type f -size +100M 2>/dev/null"
    public static let diskList = "diskutil list"
    public static let diskInfo = "diskutil info /"

    // Cleanup
    public static let emptyTrash = "rm -rf ~/.Trash/*"
    public static let clearTemp = "rm -rf /private/var/tmp/*"
    public static let clearLogs = "rm -rf ~/Library/Logs/*"
    public static let clearCrashReports = "rm -rf ~/Library/Application\\ Support/CrashReporter/*"

    // Downloads cleanup
    public static let clearDMGs = "rm -rf ~/Downloads/*.dmg"
    public static let clearPKGs = "rm -rf ~/Downloads/*.pkg"
    public static let clearZIPs = "rm -rf ~/Downloads/*.zip"

    // Time Machine
    public static let listSnapshots = "tmutil listlocalsnapshots /"
    public static func deleteSnapshot(_ date: String) -> String {
        "sudo tmutil deletelocalsnapshots \(date)"
    }
    public static func thinSnapshots(bytes: UInt64) -> String {
        "sudo tmutil thinlocalsnapshots / \(bytes) 4"
    }

    // Developer
    public static let clearDerivedData = "rm -rf ~/Library/Developer/Xcode/DerivedData/*"
    public static let clearArchives = "rm -rf ~/Library/Developer/Xcode/Archives/*"
    public static let deleteUnavailableSimulators = "xcrun simctl delete unavailable"
}
