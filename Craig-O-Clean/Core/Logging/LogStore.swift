// MARK: - LogStore.swift
// Craig-O-Clean - Log Storage Protocol
// Defines interface for persisting and querying run records

import Foundation

/// Protocol for run record persistence
protocol LogStore: Sendable {
    func save(_ record: RunRecord) async throws
    func fetch(limit: Int, offset: Int) async throws -> [RunRecord]
    func fetch(capabilityId: String, limit: Int) async throws -> [RunRecord]
    func fetchRecent(hours: Int) async throws -> [RunRecord]
    func exportLogs(from: Date, to: Date) async throws -> URL
    func getLastError() async throws -> RunRecord?
    func deleteAll() async throws
    func count() async throws -> Int
}
