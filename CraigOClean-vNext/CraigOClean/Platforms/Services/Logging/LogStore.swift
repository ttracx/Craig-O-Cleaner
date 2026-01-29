// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Logging/LogStore.swift
// Craig-O-Clean - Log Store
// In-memory log storage for UI display

import Foundation
import Combine

/// Thread-safe in-memory store for log entries.
/// Used by the UI to display recent log messages.
@MainActor
public final class LogStore: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var entries: [AppLogEntry] = []
    @Published public var filter: LogFilter = .all

    private let maxEntries: Int
    private let queue = DispatchQueue(label: "com.craigosoft.CraigOClean.LogStore")

    // MARK: - Initialization

    public init(maxEntries: Int = 500) {
        self.maxEntries = maxEntries
    }

    // MARK: - Public Methods

    /// Adds a new log entry
    public func add(_ entry: AppLogEntry) {
        entries.append(entry)

        // Trim if over capacity
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// Clears all log entries
    public func clear() {
        entries.removeAll()
    }

    /// Returns filtered entries based on current filter
    public var filteredEntries: [AppLogEntry] {
        entries.filter { filter.matches($0) }
    }

    /// Returns the most recent entries
    public func recentEntries(count: Int = 100) -> [AppLogEntry] {
        Array(entries.suffix(count))
    }

    /// Returns entries for a specific category
    public func entries(for category: LogCategory) -> [AppLogEntry] {
        entries.filter { $0.category == category }
    }

    /// Returns entries at or above a specific level
    public func entries(minLevel: LogLevel) -> [AppLogEntry] {
        entries.filter { $0.level >= minLevel }
    }

    /// Exports all entries as text
    public func exportAsText() -> String {
        entries.map { $0.logLine }.joined(separator: "\n")
    }

    /// Exports filtered entries as text
    public func exportFilteredAsText() -> String {
        filteredEntries.map { $0.logLine }.joined(separator: "\n")
    }
}

// MARK: - Statistics

extension LogStore {

    /// Returns count of entries by level
    public var countsByLevel: [LogLevel: Int] {
        Dictionary(grouping: entries, by: { $0.level }).mapValues { $0.count }
    }

    /// Returns count of entries by category
    public var countsByCategory: [LogCategory: Int] {
        Dictionary(grouping: entries, by: { $0.category }).mapValues { $0.count }
    }

    /// Returns error count
    public var errorCount: Int {
        entries.filter { $0.level == .error }.count
    }

    /// Returns warning count
    public var warningCount: Int {
        entries.filter { $0.level == .warning }.count
    }
}
