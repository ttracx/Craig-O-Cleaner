//
//  SQLiteLogStore.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import SQLite3
import os.log

// MARK: - Log Store Protocol

protocol LogStore {
    func save(_ record: RunRecord) async throws
    func fetch(limit: Int, offset: Int) async throws -> [RunRecord]
    func fetch(capabilityId: String, limit: Int) async throws -> [RunRecord]
    func fetchRecent(hours: Int) async throws -> [RunRecord]
    func getLastError() async throws -> RunRecord?
    func getLastRecordHash() async throws -> String?
    func exportLogs(from: Date, to: Date) async throws -> URL
}

// MARK: - SQLite Log Store Errors

enum LogStoreError: LocalizedError {
    case databaseOpenFailed(String)
    case databaseInitFailed(String)
    case queryFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let message):
            return "Failed to open database: \(message)"
        case .databaseInitFailed(let message):
            return "Failed to initialize database: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .encodingFailed(let message):
            return "Failed to encode data: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode data: \(message)"
        case .exportFailed(let message):
            return "Failed to export logs: \(message)"
        }
    }
}

// MARK: - SQLite Log Store

/// Thread-safe SQLite-backed log storage with file output support
actor SQLiteLogStore: LogStore {

    // MARK: - Constants
    private static let outputSizeThreshold = 10_240  // 10KB

    // MARK: - Private State
    private var db: OpaquePointer?
    private let dbPath: URL
    private let outputDirectory: URL
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "SQLiteLogStore")

    // MARK: - Singleton
    static let shared: SQLiteLogStore = {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let appDirectory = appSupport.appendingPathComponent("CraigOTerminator", isDirectory: true)
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

            let dbPath = appDirectory.appendingPathComponent("logs.sqlite")
            let outputDir = appDirectory.appendingPathComponent("logs", isDirectory: true)

            return try SQLiteLogStore(dbPath: dbPath, outputDirectory: outputDir)
        } catch {
            fatalError("Failed to initialize SQLiteLogStore: \(error)")
        }
    }()

    // MARK: - Initialization

    init(dbPath: URL, outputDirectory: URL) throws {
        self.dbPath = dbPath
        self.outputDirectory = outputDirectory

        // Create output directory
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        logger.info("Initializing SQLite log store at \(dbPath.path)")

        // Open database
        var db: OpaquePointer?
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw LogStoreError.databaseOpenFailed(errorMessage)
        }

        self.db = db

        // Initialize schema
        try initializeSchema()

        logger.info("SQLite log store initialized successfully")
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Schema Initialization

    private func initializeSchema() throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS run_records (
            id TEXT PRIMARY KEY,
            timestamp INTEGER NOT NULL,
            capability_id TEXT NOT NULL,
            capability_title TEXT NOT NULL,
            privilege_level TEXT NOT NULL,
            arguments TEXT,
            duration_ms INTEGER NOT NULL,
            exit_code INTEGER NOT NULL,
            status TEXT NOT NULL,
            stdout_path TEXT,
            stderr_path TEXT,
            output_size_bytes INTEGER NOT NULL,
            parsed_summary TEXT,
            parsed_data BLOB,
            previous_record_hash TEXT,
            record_hash TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_run_records_capability_id ON run_records(capability_id);
        CREATE INDEX IF NOT EXISTS idx_run_records_timestamp ON run_records(timestamp);
        CREATE INDEX IF NOT EXISTS idx_run_records_status ON run_records(status);
        CREATE INDEX IF NOT EXISTS idx_run_records_created_at ON run_records(created_at);
        """

        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, schema, nil, nil, &errorMessage) != SQLITE_OK {
            let error = errorMessage.flatMap { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw LogStoreError.databaseInitFailed(error)
        }

        logger.debug("Database schema initialized")
    }

    // MARK: - Save

    func save(_ record: RunRecord) async throws {
        logger.info("Saving run record: \(record.id.uuidString)")

        // Encode arguments as JSON
        let argumentsJSON = try JSONEncoder().encode(record.arguments)
        let argumentsString = String(data: argumentsJSON, encoding: .utf8) ?? "{}"

        // Prepare SQL
        let sql = """
        INSERT INTO run_records (
            id, timestamp, capability_id, capability_title, privilege_level,
            arguments, duration_ms, exit_code, status, stdout_path, stderr_path,
            output_size_bytes, parsed_summary, parsed_data, previous_record_hash,
            record_hash, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw LogStoreError.queryFailed("Failed to prepare insert: \(error)")
        }

        defer { sqlite3_finalize(statement) }

        // Bind values
        let timestamp = Int(record.timestamp.timeIntervalSince1970)
        let createdAt = Int(Date().timeIntervalSince1970)

        sqlite3_bind_text(statement, 1, record.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 2, Int64(timestamp))
        sqlite3_bind_text(statement, 3, record.capabilityId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, record.capabilityTitle, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, record.privilegeLevel.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, argumentsString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 7, Int64(record.durationMs))
        sqlite3_bind_int(statement, 8, record.exitCode)
        sqlite3_bind_text(statement, 9, record.status.rawValue, -1, SQLITE_TRANSIENT)
        bindOptionalText(statement, 10, record.stdoutPath)
        bindOptionalText(statement, 11, record.stderrPath)
        sqlite3_bind_int64(statement, 12, Int64(record.outputSizeBytes))
        bindOptionalText(statement, 13, record.parsedSummary)
        bindOptionalBlob(statement, 14, record.parsedData)
        bindOptionalText(statement, 15, record.previousRecordHash)
        sqlite3_bind_text(statement, 16, record.recordHash, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 17, Int64(createdAt))

        // Execute
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let error = String(cString: sqlite3_errmsg(db))
            throw LogStoreError.queryFailed("Failed to insert record: \(error)")
        }

        logger.debug("Record saved successfully")
    }

    // MARK: - Fetch

    func fetch(limit: Int, offset: Int) async throws -> [RunRecord] {
        let sql = """
        SELECT * FROM run_records
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
        """

        return try executeQuery(sql, bindings: { statement in
            sqlite3_bind_int(statement, 1, Int32(limit))
            sqlite3_bind_int(statement, 2, Int32(offset))
        })
    }

    func fetch(capabilityId: String, limit: Int) async throws -> [RunRecord] {
        let sql = """
        SELECT * FROM run_records
        WHERE capability_id = ?
        ORDER BY timestamp DESC
        LIMIT ?
        """

        return try executeQuery(sql, bindings: { statement in
            sqlite3_bind_text(statement, 1, capabilityId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(limit))
        })
    }

    func fetchRecent(hours: Int) async throws -> [RunRecord] {
        let cutoffTime = Date().addingTimeInterval(-Double(hours * 3600))
        let cutoffTimestamp = Int(cutoffTime.timeIntervalSince1970)

        let sql = """
        SELECT * FROM run_records
        WHERE timestamp >= ?
        ORDER BY timestamp DESC
        """

        return try executeQuery(sql, bindings: { statement in
            sqlite3_bind_int64(statement, 1, Int64(cutoffTimestamp))
        })
    }

    func getLastError() async throws -> RunRecord? {
        let sql = """
        SELECT * FROM run_records
        WHERE status = 'failed' OR status = 'timeout'
        ORDER BY timestamp DESC
        LIMIT 1
        """

        let results = try executeQuery(sql, bindings: nil)
        return results.first
    }

    func getLastRecordHash() async throws -> String? {
        let sql = """
        SELECT record_hash FROM run_records
        ORDER BY timestamp DESC
        LIMIT 1
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw LogStoreError.queryFailed("Failed to prepare query: \(error)")
        }

        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                return String(cString: cString)
            }
        }

        return nil
    }

    // MARK: - Export

    func exportLogs(from: Date, to: Date) async throws -> URL {
        logger.info("Exporting logs from \(from) to \(to)")

        let fromTimestamp = Int(from.timeIntervalSince1970)
        let toTimestamp = Int(to.timeIntervalSince1970)

        let sql = """
        SELECT * FROM run_records
        WHERE timestamp >= ? AND timestamp <= ?
        ORDER BY timestamp ASC
        """

        let records = try executeQuery(sql, bindings: { statement in
            sqlite3_bind_int64(statement, 1, Int64(fromTimestamp))
            sqlite3_bind_int64(statement, 2, Int64(toTimestamp))
        })

        // Create export file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "logs_export_\(dateFormatter.string(from: Date())).json"
        let exportURL = outputDirectory.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(records)
            try data.write(to: exportURL)

            logger.info("Exported \(records.count) records to \(exportURL.path)")
            return exportURL

        } catch {
            throw LogStoreError.exportFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func executeQuery(
        _ sql: String,
        bindings: ((OpaquePointer?) -> Void)?
    ) throws -> [RunRecord] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw LogStoreError.queryFailed("Failed to prepare query: \(error)")
        }

        defer { sqlite3_finalize(statement) }

        bindings?(statement)

        var records: [RunRecord] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            do {
                let record = try parseRecord(from: statement)
                records.append(record)
            } catch {
                logger.error("Failed to parse record: \(error.localizedDescription)")
            }
        }

        return records
    }

    private func parseRecord(from statement: OpaquePointer?) throws -> RunRecord {
        guard let statement = statement else {
            throw LogStoreError.decodingFailed("Null statement")
        }

        // Parse columns
        let idString = String(cString: sqlite3_column_text(statement, 0))
        guard let id = UUID(uuidString: idString) else {
            throw LogStoreError.decodingFailed("Invalid UUID: \(idString)")
        }

        let timestamp = Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 1)))
        let capabilityId = String(cString: sqlite3_column_text(statement, 2))
        let capabilityTitle = String(cString: sqlite3_column_text(statement, 3))

        let privilegeLevelStr = String(cString: sqlite3_column_text(statement, 4))
        guard let privilegeLevel = PrivilegeLevel(rawValue: privilegeLevelStr) else {
            throw LogStoreError.decodingFailed("Invalid privilege level: \(privilegeLevelStr)")
        }

        // Parse arguments JSON
        let argumentsStr = String(cString: sqlite3_column_text(statement, 5))
        let arguments = (try? JSONDecoder().decode([String: String].self, from: Data(argumentsStr.utf8))) ?? [:]

        let durationMs = Int(sqlite3_column_int64(statement, 6))
        let exitCode = sqlite3_column_int(statement, 7)

        let statusStr = String(cString: sqlite3_column_text(statement, 8))
        guard let status = ExecutionStatus(rawValue: statusStr) else {
            throw LogStoreError.decodingFailed("Invalid status: \(statusStr)")
        }

        let stdoutPath = columnTextOrNil(statement, 9)
        let stderrPath = columnTextOrNil(statement, 10)
        let outputSizeBytes = Int(sqlite3_column_int64(statement, 11))
        let parsedSummary = columnTextOrNil(statement, 12)
        let parsedData = columnBlobOrNil(statement, 13)
        let previousRecordHash = columnTextOrNil(statement, 14)

        return RunRecord(
            id: id,
            timestamp: timestamp,
            capabilityId: capabilityId,
            capabilityTitle: capabilityTitle,
            privilegeLevel: privilegeLevel,
            arguments: arguments,
            durationMs: durationMs,
            exitCode: exitCode,
            status: status,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            outputSizeBytes: outputSizeBytes,
            parsedSummary: parsedSummary,
            parsedData: parsedData,
            previousRecordHash: previousRecordHash
        )
    }

    // MARK: - SQLite Helpers

    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptionalBlob(_ statement: OpaquePointer?, _ index: Int32, _ value: Data?) {
        if let value = value {
            value.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func columnTextOrNil(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }

    private func columnBlobOrNil(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard let blob = sqlite3_column_blob(statement, index) else {
            return nil
        }
        let size = sqlite3_column_bytes(statement, index)
        return Data(bytes: blob, count: Int(size))
    }
}

// MARK: - Output File Manager

extension SQLiteLogStore {
    /// Save large output to file and return path
    func saveOutputToFile(_ output: String, prefix: String, recordId: UUID) async throws -> String? {
        guard output.count > Self.outputSizeThreshold else {
            return nil
        }

        let filename = "\(recordId.uuidString)_\(prefix).txt"
        let fileURL = outputDirectory.appendingPathComponent(filename)

        try output.write(to: fileURL, atomically: true, encoding: .utf8)

        logger.debug("Saved \(output.count) bytes to \(filename)")
        return fileURL.path
    }

    /// Load output from file
    func loadOutputFromFile(_ path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
