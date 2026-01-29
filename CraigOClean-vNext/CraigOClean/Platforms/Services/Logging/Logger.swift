// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Logging/Logger.swift
// Craig-O-Clean - Logger
// Central logging service with file and memory output

import Foundation
import os.log

/// Central logging service that writes to both memory (for UI) and disk.
@MainActor
public final class Logger {

    // MARK: - Properties

    private let store: LogStore
    private let logFileURL: URL?
    private let fileHandle: FileHandle?
    private let osLog: OSLog
    private let dateFormatter: DateFormatter

    public var minimumLevel: LogLevel = .debug

    // MARK: - Initialization

    public init(store: LogStore, logFileURL: URL? = nil) {
        self.store = store
        self.logFileURL = logFileURL
        self.osLog = OSLog(subsystem: "com.craigosoft.CraigOClean", category: "general")

        // Set up date formatter
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Set up file handle if URL provided
        if let url = logFileURL {
            // Create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            self.fileHandle = try? FileHandle(forWritingTo: url)
            fileHandle?.seekToEndOfFile()
        } else {
            self.fileHandle = nil
        }
    }

    deinit {
        try? fileHandle?.close()
    }

    // MARK: - Logging Methods

    public func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        metadata: [String: String]? = nil,
        source: String? = nil
    ) {
        guard level >= minimumLevel else { return }

        let entry = AppLogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            source: source
        )

        // Add to in-memory store
        store.add(entry)

        // Write to file
        writeToFile(entry)

        // Write to system log
        writeToOSLog(entry)
    }

    // MARK: - Convenience Methods

    public func debug(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String]? = nil,
        source: String? = nil
    ) {
        log(message, level: .debug, category: category, metadata: metadata, source: source)
    }

    public func info(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String]? = nil,
        source: String? = nil
    ) {
        log(message, level: .info, category: category, metadata: metadata, source: source)
    }

    public func warning(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String]? = nil,
        source: String? = nil
    ) {
        log(message, level: .warning, category: category, metadata: metadata, source: source)
    }

    public func error(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String]? = nil,
        source: String? = nil
    ) {
        log(message, level: .error, category: category, metadata: metadata, source: source)
    }

    // MARK: - Private Methods

    private func writeToFile(_ entry: AppLogEntry) {
        guard let fileHandle = fileHandle else { return }

        let line = entry.logLine + "\n"
        if let data = line.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    private func writeToOSLog(_ entry: AppLogEntry) {
        let osLogType: OSLogType

        switch entry.level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        }

        os_log("%{public}@", log: osLog, type: osLogType, entry.message)
    }

    // MARK: - File Management

    /// Rotates the log file if it exceeds the size limit
    public func rotateLogFileIfNeeded(maxSizeBytes: Int = 10_000_000) {
        guard let url = logFileURL else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0

            if fileSize > maxSizeBytes {
                rotateLogFile()
            }
        } catch {
            // Ignore errors
        }
    }

    private func rotateLogFile() {
        guard let url = logFileURL else { return }

        let backupURL = url.deletingPathExtension()
            .appendingPathExtension("old")
            .appendingPathExtension("log")

        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: url, to: backupURL)
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    /// Returns the log file contents
    public func readLogFile() -> String? {
        guard let url = logFileURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Returns the log file size
    public var logFileSize: Int {
        guard let url = logFileURL else { return 0 }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int ?? 0
    }
}

// MARK: - Global Access

extension Logger {

    /// Shared logger instance (set up by DIContainer)
    @MainActor
    public static var shared: Logger {
        DIContainer.shared.logger
    }
}
