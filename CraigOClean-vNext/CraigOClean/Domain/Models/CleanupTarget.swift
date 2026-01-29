// File: CraigOClean-vNext/CraigOClean/Domain/Models/CleanupTarget.swift
// Craig-O-Clean - Cleanup Target Model
// Represents a target directory or file set for cleanup operations

import Foundation

/// Represents a cleanup target - a specific location or category of files to clean
public struct CleanupTarget: Identifiable, Hashable, Sendable {

    public let id: UUID
    public let name: String
    public let description: String
    public let category: CleanupCategory
    public let paths: [String]
    public var estimatedSize: UInt64
    public var fileCount: Int
    public let requiresPrivileges: Bool
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: CleanupCategory,
        paths: [String],
        estimatedSize: UInt64 = 0,
        fileCount: Int = 0,
        requiresPrivileges: Bool = false,
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.paths = paths
        self.estimatedSize = estimatedSize
        self.fileCount = fileCount
        self.requiresPrivileges = requiresPrivileges
        self.isSelected = isSelected
    }

    /// Returns paths with tilde expanded to actual home directory
    public var expandedPaths: [String] {
        paths.map { ($0 as NSString).expandingTildeInPath }
    }

    /// Human-readable size string
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(estimatedSize), countStyle: .file)
    }
}

// MARK: - Cleanup Category

/// Categories for organizing cleanup targets
public enum CleanupCategory: String, CaseIterable, Sendable {
    case userCaches = "User Caches"
    case systemCaches = "System Caches"
    case logs = "Logs"
    case downloads = "Downloads"
    case trash = "Trash"
    case browserData = "Browser Data"
    case developerTools = "Developer Tools"
    case other = "Other"

    public var icon: String {
        switch self {
        case .userCaches: return "folder.badge.gearshape"
        case .systemCaches: return "gearshape.2"
        case .logs: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .browserData: return "globe"
        case .developerTools: return "hammer"
        case .other: return "folder"
        }
    }

    public var requiresPrivileges: Bool {
        switch self {
        case .systemCaches:
            return true
        default:
            return false
        }
    }
}

// MARK: - Scanned File Item

/// Represents a single file found during cleanup scanning
public struct ScannedFileItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let size: UInt64
    public let modificationDate: Date?
    public let isDirectory: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        size: UInt64,
        modificationDate: Date? = nil,
        isDirectory: Bool = false
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - Predefined Targets

extension CleanupTarget {

    /// Standard user cache cleanup targets (available in both editions)
    public static func userCacheTargets() -> [CleanupTarget] {
        let home = "~"
        return [
            CleanupTarget(
                name: "User Caches",
                description: "Application caches in your Library folder",
                category: .userCaches,
                paths: ["\(home)/Library/Caches"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "User Logs",
                description: "Application and system logs in your Library",
                category: .logs,
                paths: ["\(home)/Library/Logs"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "Safari Caches",
                description: "Safari browser cache files",
                category: .browserData,
                paths: ["\(home)/Library/Caches/com.apple.Safari"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "Xcode Derived Data",
                description: "Xcode build artifacts and derived data",
                category: .developerTools,
                paths: ["\(home)/Library/Developer/Xcode/DerivedData"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "iOS Device Support",
                description: "iOS device support files used by Xcode",
                category: .developerTools,
                paths: ["\(home)/Library/Developer/Xcode/iOS DeviceSupport"],
                requiresPrivileges: false
            )
        ]
    }

    /// System-wide cleanup targets (DirectPro only)
    public static func systemCacheTargets() -> [CleanupTarget] {
        return [
            CleanupTarget(
                name: "System Caches",
                description: "System-level cache files",
                category: .systemCaches,
                paths: ["/Library/Caches"],
                requiresPrivileges: true
            ),
            CleanupTarget(
                name: "System Logs",
                description: "System-level log files",
                category: .logs,
                paths: ["/Library/Logs", "/var/log"],
                requiresPrivileges: true
            )
        ]
    }
}
