// MARK: - AuditLogService.swift
// Craig-O-Clean - Audit Log Service
// Provides append-only audit logging for all operations

import Foundation
import Combine
import os.log

/// Service for managing the audit log
@MainActor
final class AuditLogService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var recentEntries: [AuditEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: CraigOCleanError?

    // MARK: - Configuration

    private let maxRecentEntries = 100
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "AuditLog")

    // MARK: - Dependencies

    private let store: AuditLogStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(store: AuditLogStore = SQLiteAuditLogStore()) {
        self.store = store
        loadRecentEntries()
        logAppStart()
    }

    // MARK: - Logging Methods

    /// Log a successful action
    func log(
        _ action: AuditAction,
        target: String,
        metadata: [String: String] = [:]
    ) {
        let entry = AuditEntry.success(action, target: target, metadata: metadata)
        appendEntry(entry)
    }

    /// Log a failed action
    func logError(
        _ action: AuditAction,
        target: String,
        error: Error,
        metadata: [String: String] = [:]
    ) {
        let entry = AuditEntry.failure(action, target: target, error: error, metadata: metadata)
        appendEntry(entry)
    }

    /// Log a failed action with custom message
    func logError(
        _ action: AuditAction,
        target: String,
        errorMessage: String,
        metadata: [String: String] = [:]
    ) {
        let entry = AuditEntry.failure(action, target: target, errorMessage: errorMessage, metadata: metadata)
        appendEntry(entry)
    }

    /// Log a custom entry
    func log(_ entry: AuditEntry) {
        appendEntry(entry)
    }

    // MARK: - Query Methods

    /// Fetch entries with optional filtering
    func fetchEntries(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        action: AuditAction? = nil,
        category: AuditCategory? = nil,
        limit: Int? = nil
    ) async -> [AuditEntry] {
        await store.fetch(
            from: startDate,
            to: endDate,
            action: action,
            category: category,
            limit: limit
        )
    }

    /// Fetch entries for the current session
    func fetchCurrentSessionEntries() async -> [AuditEntry] {
        await store.fetchBySession(AuditEntry.currentSessionId)
    }

    /// Get entry count
    func getEntryCount() async -> Int {
        await store.count()
    }

    /// Get entries by action type
    func fetchByAction(_ action: AuditAction, limit: Int = 50) async -> [AuditEntry] {
        await store.fetch(action: action, limit: limit)
    }

    // MARK: - Export Methods

    /// Export log as JSON data
    func exportLog(from startDate: Date? = nil, to endDate: Date? = nil) async -> Data? {
        let entries = await fetchEntries(from: startDate, to: endDate)

        let export = AuditLogExport(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            sessionId: AuditEntry.currentSessionId,
            entries: entries
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try? encoder.encode(export)
    }

    /// Export log to a file URL
    func exportLogToFile(from startDate: Date? = nil, to endDate: Date? = nil) async -> URL? {
        guard let data = await exportLog(from: startDate, to: endDate) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "craig-o-clean-audit-\(formatter.string(from: Date())).json"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            log(.settingChanged, target: "audit_log_exported", metadata: ["path": fileURL.path])
            return fileURL
        } catch {
            logger.error("Failed to export audit log: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Cleanup Methods

    /// Delete entries older than a date
    func deleteEntries(olderThan date: Date) async {
        await store.delete(olderThan: date)
        loadRecentEntries()
        log(.settingChanged, target: "audit_log_cleaned", metadata: ["before": date.ISO8601Format()])
    }

    /// Delete all entries
    func deleteAllEntries() async {
        await store.deleteAll()
        recentEntries = []
        log(.settingChanged, target: "audit_log_cleared")
    }

    // MARK: - Private Methods

    private func appendEntry(_ entry: AuditEntry) {
        // Log to system log
        if entry.success {
            logger.info("[\(entry.action.rawValue)] \(entry.target)")
        } else {
            logger.warning("[\(entry.action.rawValue)] \(entry.target) - FAILED: \(entry.errorMessage ?? "Unknown")")
        }

        // Persist to store
        Task {
            await store.append(entry)
        }

        // Update in-memory recent entries
        recentEntries.insert(entry, at: 0)
        if recentEntries.count > maxRecentEntries {
            recentEntries = Array(recentEntries.prefix(maxRecentEntries))
        }
    }

    private func loadRecentEntries() {
        Task {
            let entries = await store.fetch(limit: maxRecentEntries)
            await MainActor.run {
                self.recentEntries = entries
            }
        }
    }

    private func logAppStart() {
        log(.appStarted, target: "Craig-O-Clean", metadata: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "sessionId": AuditEntry.currentSessionId
        ])
    }
}

// MARK: - Audit Log Store Protocol

/// Protocol for audit log persistence
protocol AuditLogStore: Sendable {
    func append(_ entry: AuditEntry) async
    func fetch(from startDate: Date?, to endDate: Date?, action: AuditAction?, category: AuditCategory?, limit: Int?) async -> [AuditEntry]
    func fetch(action: AuditAction?, limit: Int?) async -> [AuditEntry]
    func fetchBySession(_ sessionId: String) async -> [AuditEntry]
    func count() async -> Int
    func delete(olderThan date: Date) async
    func deleteAll() async
}

// MARK: - SQLite Audit Log Store

/// SQLite-based implementation of audit log storage
final class SQLiteAuditLogStore: AuditLogStore, @unchecked Sendable {

    private let dbPath: String
    private let queue = DispatchQueue(label: "com.craigoclean.auditlog", qos: .utility)
    private var db: OpaquePointer?
    private let logger = Logger(subsystem: "com.CraigOClean.controlcenter", category: "AuditLogStore")

    init() {
        // Store in app's Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CraigOClean", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.dbPath = appDir.appendingPathComponent("audit_log.sqlite").path
        setupDatabase()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func setupDatabase() {
        queue.sync {
            guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
                logger.error("Failed to open audit log database")
                return
            }

            let createTableSQL = """
                CREATE TABLE IF NOT EXISTS audit_entries (
                    id TEXT PRIMARY KEY,
                    timestamp REAL NOT NULL,
                    action TEXT NOT NULL,
                    target TEXT NOT NULL,
                    metadata TEXT,
                    success INTEGER NOT NULL,
                    error_message TEXT,
                    session_id TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_timestamp ON audit_entries(timestamp DESC);
                CREATE INDEX IF NOT EXISTS idx_action ON audit_entries(action);
                CREATE INDEX IF NOT EXISTS idx_session ON audit_entries(session_id);
            """

            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, createTableSQL, nil, nil, &errMsg) != SQLITE_OK {
                if let errMsg = errMsg {
                    logger.error("Failed to create audit table: \(String(cString: errMsg))")
                    sqlite3_free(errMsg)
                }
            }
        }
    }

    // MARK: - AuditLogStore Implementation

    func append(_ entry: AuditEntry) async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume()
                    return
                }

                let sql = """
                    INSERT INTO audit_entries (id, timestamp, action, target, metadata, success, error_message, session_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """

                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                    continuation.resume()
                    return
                }
                defer { sqlite3_finalize(statement) }

                let metadataJSON = (try? JSONEncoder().encode(entry.metadata)).flatMap { String(data: $0, encoding: .utf8) }

                sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, entry.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, entry.action.rawValue, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 4, entry.target, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 5, metadataJSON, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 6, entry.success ? 1 : 0)
                sqlite3_bind_text(statement, 7, entry.errorMessage, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 8, entry.sessionId, -1, SQLITE_TRANSIENT)

                sqlite3_step(statement)
                continuation.resume()
            }
        }
    }

    func fetch(from startDate: Date? = nil, to endDate: Date? = nil, action: AuditAction? = nil, category: AuditCategory? = nil, limit: Int? = nil) async -> [AuditEntry] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume(returning: [])
                    return
                }

                var conditions: [String] = []
                var params: [Any] = []

                if let start = startDate {
                    conditions.append("timestamp >= ?")
                    params.append(start.timeIntervalSince1970)
                }

                if let end = endDate {
                    conditions.append("timestamp <= ?")
                    params.append(end.timeIntervalSince1970)
                }

                if let action = action {
                    conditions.append("action = ?")
                    params.append(action.rawValue)
                }

                if let category = category {
                    let categoryActions = AuditAction.allCases.filter { $0.category == category }
                    let placeholders = categoryActions.map { _ in "?" }.joined(separator: ", ")
                    conditions.append("action IN (\(placeholders))")
                    params.append(contentsOf: categoryActions.map { $0.rawValue })
                }

                var sql = "SELECT * FROM audit_entries"
                if !conditions.isEmpty {
                    sql += " WHERE " + conditions.joined(separator: " AND ")
                }
                sql += " ORDER BY timestamp DESC"
                if let limit = limit {
                    sql += " LIMIT \(limit)"
                }

                let entries = self.executeQuery(sql, params: params)
                continuation.resume(returning: entries)
            }
        }
    }

    func fetch(action: AuditAction? = nil, limit: Int? = nil) async -> [AuditEntry] {
        await fetch(from: nil, to: nil, action: action, category: nil, limit: limit)
    }

    func fetchBySession(_ sessionId: String) async -> [AuditEntry] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                let sql = "SELECT * FROM audit_entries WHERE session_id = ? ORDER BY timestamp DESC"
                let entries = self.executeQuery(sql, params: [sessionId])
                continuation.resume(returning: entries)
            }
        }
    }

    func count() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume(returning: 0)
                    return
                }

                let sql = "SELECT COUNT(*) FROM audit_entries"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                    continuation.resume(returning: 0)
                    return
                }
                defer { sqlite3_finalize(statement) }

                if sqlite3_step(statement) == SQLITE_ROW {
                    let count = Int(sqlite3_column_int(statement, 0))
                    continuation.resume(returning: count)
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    func delete(olderThan date: Date) async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume()
                    return
                }

                let sql = "DELETE FROM audit_entries WHERE timestamp < ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                    continuation.resume()
                    return
                }
                defer { sqlite3_finalize(statement) }

                sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
                sqlite3_step(statement)
                continuation.resume()
            }
        }
    }

    func deleteAll() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume()
                    return
                }

                let sql = "DELETE FROM audit_entries"
                var errMsg: UnsafeMutablePointer<CChar>?
                sqlite3_exec(db, sql, nil, nil, &errMsg)
                if let errMsg = errMsg {
                    sqlite3_free(errMsg)
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Private Helpers

    private func executeQuery(_ sql: String, params: [Any]) -> [AuditEntry] {
        guard let db = db else { return [] }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            let bindIndex = Int32(index + 1)
            if let stringValue = param as? String {
                sqlite3_bind_text(statement, bindIndex, stringValue, -1, SQLITE_TRANSIENT)
            } else if let doubleValue = param as? Double {
                sqlite3_bind_double(statement, bindIndex, doubleValue)
            } else if let intValue = param as? Int {
                sqlite3_bind_int(statement, bindIndex, Int32(intValue))
            }
        }

        var entries: [AuditEntry] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = parseEntry(from: statement) {
                entries.append(entry)
            }
        }

        return entries
    }

    private func parseEntry(from statement: OpaquePointer?) -> AuditEntry? {
        guard let statement = statement else { return nil }

        guard let idStr = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
              let id = UUID(uuidString: idStr),
              let actionStr = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
              let action = AuditAction(rawValue: actionStr),
              let target = sqlite3_column_text(statement, 3).map({ String(cString: $0) }),
              let sessionId = sqlite3_column_text(statement, 7).map({ String(cString: $0) }) else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))

        var metadata: [String: String] = [:]
        if let metadataStr = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
           let metadataData = metadataStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: metadataData) {
            metadata = decoded
        }

        let success = sqlite3_column_int(statement, 5) == 1
        let errorMessage = sqlite3_column_text(statement, 6).map { String(cString: $0) }

        return AuditEntry(
            id: id,
            timestamp: timestamp,
            action: action,
            target: target,
            metadata: metadata,
            success: success,
            errorMessage: errorMessage,
            sessionId: sessionId
        )
    }
}

// MARK: - SQLite Helpers

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - In-Memory Store for Testing

/// In-memory implementation for testing
final class InMemoryAuditLogStore: AuditLogStore, @unchecked Sendable {
    private var entries: [AuditEntry] = []
    private let lock = NSLock()

    func append(_ entry: AuditEntry) async {
        lock.lock()
        defer { lock.unlock() }
        entries.insert(entry, at: 0)
    }

    func fetch(from startDate: Date?, to endDate: Date?, action: AuditAction?, category: AuditCategory?, limit: Int?) async -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        var result = entries

        if let start = startDate {
            result = result.filter { $0.timestamp >= start }
        }
        if let end = endDate {
            result = result.filter { $0.timestamp <= end }
        }
        if let action = action {
            result = result.filter { $0.action == action }
        }
        if let category = category {
            result = result.filter { $0.action.category == category }
        }
        if let limit = limit {
            result = Array(result.prefix(limit))
        }

        return result
    }

    func fetch(action: AuditAction?, limit: Int?) async -> [AuditEntry] {
        await fetch(from: nil, to: nil, action: action, category: nil, limit: limit)
    }

    func fetchBySession(_ sessionId: String) async -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.sessionId == sessionId }
    }

    func count() async -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    func delete(olderThan date: Date) async {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll { $0.timestamp < date }
    }

    func deleteAll() async {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
