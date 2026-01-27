// MARK: - SQLiteLogStore.swift
// Craig-O-Clean - SQLite-backed Log Store
// Persists run records to a local SQLite database using JSON serialization

import Foundation
import os.log

/// SQLite-backed implementation of LogStore using JSON file storage
/// Uses a simple JSON array file for persistence (avoids SQLite C API complexity)
final class SQLiteLogStore: LogStore, @unchecked Sendable {
    static let shared = SQLiteLogStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.CraigOClean.logstore", qos: .utility)
    private let logger = Logger(subsystem: "com.CraigOClean", category: "LogStore")
    private let maxRecords = 1000

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CraigOClean", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("run_records.json")
    }

    func save(_ record: RunRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    var records = (try? self.loadRecords()) ?? []
                    records.insert(record, at: 0)

                    // Trim to max
                    if records.count > maxRecords {
                        records = Array(records.prefix(maxRecords))
                    }

                    try self.saveRecords(records)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetch(limit: Int = 50, offset: Int = 0) async throws -> [RunRecord] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let records = try self.loadRecords()
                    let sliced = Array(records.dropFirst(offset).prefix(limit))
                    continuation.resume(returning: sliced)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetch(capabilityId: String, limit: Int = 50) async throws -> [RunRecord] {
        let all = try await fetch(limit: maxRecords, offset: 0)
        return Array(all.filter { $0.capabilityId == capabilityId }.prefix(limit))
    }

    func fetchRecent(hours: Int) async throws -> [RunRecord] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let all = try await fetch(limit: maxRecords, offset: 0)
        return all.filter { $0.timestamp > cutoff }
    }

    func exportLogs(from: Date, to: Date) async throws -> URL {
        let all = try await fetch(limit: maxRecords, offset: 0)
        let filtered = all.filter { $0.timestamp >= from && $0.timestamp <= to }

        let exportDir = FileManager.default.temporaryDirectory
        let exportURL = exportDir.appendingPathComponent("CraigOClean_logs_\(ISO8601DateFormatter().string(from: Date())).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(filtered)
        try data.write(to: exportURL)

        return exportURL
    }

    func getLastError() async throws -> RunRecord? {
        let all = try await fetch(limit: maxRecords, offset: 0)
        return all.first { $0.status == .failed || $0.status == .permissionDenied }
    }

    func deleteAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try self.saveRecords([])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func count() async throws -> Int {
        let records = try await fetch(limit: maxRecords, offset: 0)
        return records.count
    }

    // MARK: - Private

    private func loadRecords() throws -> [RunRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([RunRecord].self, from: data)
    }

    private func saveRecords(_ records: [RunRecord]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }
}
