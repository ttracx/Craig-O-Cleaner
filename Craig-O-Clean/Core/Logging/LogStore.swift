// MARK: - LogStore.swift
// Craig-O-Clean - Log Store
// Persists RunRecords and stdout/stderr files for auditing and UI display

import Foundation
import os.log

@MainActor
final class LogStore: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var records: [RunRecord] = []
    @Published private(set) var isLoaded = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "LogStore")
    private let baseDir: URL
    private let recordsFile: URL

    // MARK: - Singleton

    static let shared = LogStore()

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("Craig-O-Clean/Logs")
        recordsFile = appSupport.appendingPathComponent("Craig-O-Clean/run_records.json")

        // Ensure directories exist
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        loadRecords()
    }

    // MARK: - Record Run

    func recordRun(from result: ExecutionResult, capability: Capability) async {
        let runId = UUID()
        let logsDir = baseDir.appendingPathComponent(runId.uuidString)

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // Write stdout
        var stdoutPath: String?
        if !result.stdout.isEmpty {
            let path = logsDir.appendingPathComponent("stdout.txt")
            try? result.stdout.write(to: path, atomically: true, encoding: .utf8)
            stdoutPath = path.path
        }

        // Write stderr
        var stderrPath: String?
        if !result.stderr.isEmpty {
            let path = logsDir.appendingPathComponent("stderr.txt")
            try? result.stderr.write(to: path, atomically: true, encoding: .utf8)
            stderrPath = path.path
        }

        let record = RunRecord(
            id: runId,
            timestamp: result.timestamp,
            capabilityId: result.capabilityId,
            capabilityTitle: capability.title,
            category: capability.category.rawValue,
            argsHash: "", // Could hash args for audit
            privilegeLevel: capability.requiredPrivileges.rawValue,
            durationMs: Int(result.duration * 1000),
            exitCode: result.exitCode,
            success: result.success,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            parsedSummaryJSON: result.parsedSummary,
            remediationHint: result.remediationHint
        )

        records.insert(record, at: 0)
        saveRecords()

        logger.info("Recorded run \(runId.uuidString) for \(result.capabilityId): \(result.success ? "success" : "failure")")
    }

    // MARK: - Query

    func records(forCapability capabilityId: String) -> [RunRecord] {
        return records.filter { $0.capabilityId == capabilityId }
    }

    func records(inCategory category: String) -> [RunRecord] {
        return records.filter { $0.category == category }
    }

    func failedRecords() -> [RunRecord] {
        return records.filter { !$0.success }
    }

    func readStdout(for record: RunRecord) -> String? {
        guard let path = record.stdoutPath else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    func readStderr(for record: RunRecord) -> String? {
        guard let path = record.stderrPath else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - Export

    func exportLogsZip() -> URL? {
        let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("CraigOClean-Logs-Export")
        try? FileManager.default.removeItem(at: exportDir)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Copy records file
        try? FileManager.default.copyItem(at: recordsFile, to: exportDir.appendingPathComponent("run_records.json"))

        // Copy log directories
        let logsExportDir = exportDir.appendingPathComponent("Logs")
        try? FileManager.default.copyItem(at: baseDir, to: logsExportDir)

        // Create zip
        let zipPath = FileManager.default.temporaryDirectory.appendingPathComponent("CraigOClean-Logs.zip")
        try? FileManager.default.removeItem(at: zipPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath.path, "."]
        process.currentDirectoryURL = exportDir

        try? process.run()
        process.waitUntilExit()

        try? FileManager.default.removeItem(at: exportDir)

        return process.terminationStatus == 0 ? zipPath : nil
    }

    // MARK: - Persistence

    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: recordsFile.path) else {
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: recordsFile)
            records = try JSONDecoder().decode([RunRecord].self, from: data)
            isLoaded = true
            logger.info("Loaded \(self.records.count) run records")
        } catch {
            logger.error("Failed to load run records: \(error.localizedDescription)")
            isLoaded = true
        }
    }

    private func saveRecords() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(records)

            let dir = recordsFile.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: recordsFile, options: .atomic)
        } catch {
            logger.error("Failed to save run records: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    func clearOldRecords(olderThan days: Int = 30) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let oldRecords = records.filter { $0.timestamp < cutoff }

        for record in oldRecords {
            // Delete log files
            let logsDir = baseDir.appendingPathComponent(record.id.uuidString)
            try? FileManager.default.removeItem(at: logsDir)
        }

        records.removeAll { $0.timestamp < cutoff }
        saveRecords()

        logger.info("Cleared \(oldRecords.count) old run records")
    }
}
