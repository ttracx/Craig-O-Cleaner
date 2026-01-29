// File: CraigOClean-vNext/CraigOClean/Domain/Models/AppLogEntry.swift
// Craig-O-Clean - App Log Entry Model
// Represents a single log entry in the application logging system

import Foundation

/// Represents a single log entry
public struct AppLogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let metadata: [String: String]?
    public let source: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.source = source
    }

    /// Formatted timestamp for display
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// Full formatted timestamp for log files
    public var fullFormattedTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: timestamp)
    }

    /// Formatted log line for file output
    public var logLine: String {
        var line = "[\(fullFormattedTimestamp)] [\(level.rawValue.uppercased())] [\(category.rawValue)] \(message)"
        if let source = source {
            line = "[\(fullFormattedTimestamp)] [\(level.rawValue.uppercased())] [\(category.rawValue)] [\(source)] \(message)"
        }
        if let metadata = metadata, !metadata.isEmpty {
            let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            line += " {\(metaStr)}"
        }
        return line
    }
}

// MARK: - Log Level

public enum LogLevel: String, CaseIterable, Sendable, Comparable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"

    public var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }

    public var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Log Category

public enum LogCategory: String, CaseIterable, Sendable {
    case app = "app"
    case cleanup = "cleanup"
    case diagnostics = "diagnostics"
    case permissions = "permissions"
    case updates = "updates"
    case licensing = "licensing"
    case ui = "ui"
    case system = "system"

    public var displayName: String {
        switch self {
        case .app: return "Application"
        case .cleanup: return "Cleanup"
        case .diagnostics: return "Diagnostics"
        case .permissions: return "Permissions"
        case .updates: return "Updates"
        case .licensing: return "Licensing"
        case .ui: return "UI"
        case .system: return "System"
        }
    }
}

// MARK: - Log Filter

public struct LogFilter: Equatable, Sendable {
    public var levels: Set<LogLevel>
    public var categories: Set<LogCategory>
    public var searchText: String

    public init(
        levels: Set<LogLevel> = Set(LogLevel.allCases),
        categories: Set<LogCategory> = Set(LogCategory.allCases),
        searchText: String = ""
    ) {
        self.levels = levels
        self.categories = categories
        self.searchText = searchText
    }

    public static let all = LogFilter()

    public func matches(_ entry: AppLogEntry) -> Bool {
        guard levels.contains(entry.level) else { return false }
        guard categories.contains(entry.category) else { return false }

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
