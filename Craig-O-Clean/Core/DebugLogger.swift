// MARK: - DebugLogger.swift
// Craig-O-Clean - Comprehensive Debug and Logging System
// Provides structured logging for automated testing and debugging

import Foundation
import os.log
import SwiftUI
import AppKit

// MARK: - Debug Log Level Enum

/// Defines the severity level of log entries
public enum DebugLogLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    public static func < (lhs: DebugLogLevel, rhs: DebugLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .verbose: return "📝"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }

    var name: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Debug Log Category Enum

/// Categories for organizing log entries
public enum DebugLogCategory: String, Codable, CaseIterable, Sendable {
    case app = "App"
    case ui = "UI"
    case navigation = "Navigation"
    case memory = "Memory"
    case process = "Process"
    case browser = "Browser"
    case network = "Network"
    case performance = "Performance"
    case security = "Security"
    case system = "System"
    case autoCleanup = "AutoCleanup"
    case test = "Test"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .app: return "app.badge"
        case .ui: return "rectangle.3.group"
        case .navigation: return "arrow.triangle.turn.up.right.diamond"
        case .memory: return "memorychip"
        case .process: return "list.bullet.rectangle"
        case .browser: return "safari"
        case .network: return "network"
        case .performance: return "gauge.with.dots.needle.bottom.50percent"
        case .security: return "lock.shield"
        case .system: return "gearshape.2"
        case .autoCleanup: return "wand.and.stars"
        case .test: return "testtube.2"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Debug Log Entry Model

/// A single log entry with all metadata
public struct DebugLogEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: DebugLogLevel
    public let category: DebugLogCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let threadName: String
    public let additionalInfo: [String: String]?
    public let stackTrace: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: DebugLogLevel,
        category: DebugLogCategory,
        message: String,
        file: String,
        function: String,
        line: Int,
        threadName: String = Thread.current.name ?? "unknown",
        additionalInfo: [String: String]? = nil,
        stackTrace: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.threadName = threadName
        self.additionalInfo = additionalInfo
        self.stackTrace = stackTrace
    }

    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    public var formattedMessage: String {
        "\(level.emoji) [\(formattedTimestamp)] [\(level.name)] [\(category.rawValue)] \(file):\(line) - \(message)"
    }

    public var jsonString: String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to encode log entry\"}"
        }
        return json
    }
}

// MARK: - Test Result Model

/// Represents a single test result for the automated testing system
public struct DebugTestResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let testName: String
    public let category: String
    public let passed: Bool
    public let duration: TimeInterval
    public let errorMessage: String?
    public let screenshot: Data?
    public let timestamp: Date
    public let logs: [DebugLogEntry]

    public init(
        id: UUID = UUID(),
        testName: String,
        category: String,
        passed: Bool,
        duration: TimeInterval,
        errorMessage: String? = nil,
        screenshot: Data? = nil,
        timestamp: Date = Date(),
        logs: [DebugLogEntry] = []
    ) {
        self.id = id
        self.testName = testName
        self.category = category
        self.passed = passed
        self.duration = duration
        self.errorMessage = errorMessage
        self.screenshot = screenshot
        self.timestamp = timestamp
        self.logs = logs
    }
}

// MARK: - Test Report Model

/// Complete test report containing all results
public struct DebugTestReport: Codable, Sendable {
    public let id: UUID
    public let appVersion: String
    public let buildNumber: String
    public let macOSVersion: String
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let results: [DebugTestResult]
    public let systemMetrics: DebugSystemTestMetrics
    public let summary: DebugTestSummary

    public init(
        id: UUID = UUID(),
        appVersion: String,
        buildNumber: String,
        macOSVersion: String,
        startTime: Date,
        endTime: Date,
        results: [DebugTestResult],
        systemMetrics: DebugSystemTestMetrics
    ) {
        self.id = id
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.macOSVersion = macOSVersion
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.results = results
        self.systemMetrics = systemMetrics

        // Calculate summary
        let totalTests = results.count
        let passedTests = results.filter { $0.passed }.count
        let failedTests = totalTests - passedTests
        let passRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100 : 0

        self.summary = DebugTestSummary(
            totalTests: totalTests,
            passedTests: passedTests,
            failedTests: failedTests,
            passRate: passRate,
            totalDuration: duration,
            criticalIssues: results.filter { !$0.passed && $0.category == "Critical" }.count
        )
    }
}

/// Test summary statistics
public struct DebugTestSummary: Codable, Sendable {
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let passRate: Double
    public let totalDuration: TimeInterval
    public let criticalIssues: Int
}

/// System metrics captured during testing
public struct DebugSystemTestMetrics: Codable, Sendable {
    public let peakMemoryUsage: Double
    public let averageCPUUsage: Double
    public let peakCPUUsage: Double
    public let diskIOOperations: Int
    public let networkRequests: Int

    public init(
        peakMemoryUsage: Double = 0,
        averageCPUUsage: Double = 0,
        peakCPUUsage: Double = 0,
        diskIOOperations: Int = 0,
        networkRequests: Int = 0
    ) {
        self.peakMemoryUsage = peakMemoryUsage
        self.averageCPUUsage = averageCPUUsage
        self.peakCPUUsage = peakCPUUsage
        self.diskIOOperations = diskIOOperations
        self.networkRequests = networkRequests
    }
}

// MARK: - Debug Logger Class

/// Main logging class - singleton pattern for app-wide access
@MainActor
public final class DebugLogger: ObservableObject {

    // MARK: - Singleton

    public static let shared = DebugLogger()

    // MARK: - Published Properties

    @Published public private(set) var logs: [DebugLogEntry] = []
    @Published public private(set) var isRecording: Bool = true
    @Published public var minimumLevel: DebugLogLevel = .debug
    @Published public var enabledCategories: Set<DebugLogCategory> = Set(DebugLogCategory.allCases)

    // MARK: - Private Properties

    private let osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.craigoclean", category: "CraigOClean")
    private let logQueue = DispatchQueue(label: "com.craigoclean.logger", qos: .utility)
    private let maxLogEntries = 10000
    private var logFileHandle: FileHandle?
    private var currentLogFilePath: URL?
    private var testResults: [DebugTestResult] = []
    private var testStartTime: Date?
    private var sessionID: UUID = UUID()

    // MARK: - Log Directory

    private var logDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("CraigOClean/Logs", isDirectory: true)

        if !FileManager.default.fileExists(atPath: logDir.path) {
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
        }

        return logDir
    }

    // MARK: - Initialization

    private init() {
        startNewLogFile()
        log(DebugLogLevel.info, category: DebugLogCategory.app, message: "DebugLogger initialized - Session: \(sessionID.uuidString)")
    }

    // MARK: - Public Logging Methods

    /// Log a message with full context
    public func log(
        _ level: DebugLogLevel,
        category: DebugLogCategory,
        message: String,
        additionalInfo: [String: String]? = nil,
        includeStackTrace: Bool = false,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLevel && enabledCategories.contains(category) else { return }

        let stackTrace: String? = includeStackTrace ? Thread.callStackSymbols.joined(separator: "\n") : nil

        let entry = DebugLogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            additionalInfo: additionalInfo,
            stackTrace: stackTrace
        )

        // Add to in-memory logs
        logs.append(entry)

        // Trim if exceeding max
        if logs.count > maxLogEntries {
            logs.removeFirst(logs.count - maxLogEntries)
        }

        // Write to file
        writeToFile(entry)

        // Also log to system console
        osLogger.log(level: entry.level.osLogType, "\(entry.formattedMessage)")

        // Print to console in debug builds
        #if DEBUG
        print(entry.formattedMessage)
        #endif
    }

    // MARK: - Convenience Methods

    public func verbose(_ message: String, category: DebugLogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.verbose, category: category, message: message, file: file, function: function, line: line)
    }

    public func debug(_ message: String, category: DebugLogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.debug, category: category, message: message, file: file, function: function, line: line)
    }

    public func info(_ message: String, category: DebugLogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.info, category: category, message: message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, category: DebugLogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.warning, category: category, message: message, file: file, function: function, line: line)
    }

    public func error(_ message: String, category: DebugLogCategory = .app, additionalInfo: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.error, category: category, message: message, additionalInfo: additionalInfo, includeStackTrace: true, file: file, function: function, line: line)
    }

    public func critical(_ message: String, category: DebugLogCategory = .app, additionalInfo: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.critical, category: category, message: message, additionalInfo: additionalInfo, includeStackTrace: true, file: file, function: function, line: line)
    }

    // MARK: - UI Action Logging

    public func logUIAction(_ action: String, view: String, element: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "UI Action: \(action) in \(view)"
        if let element = element {
            message += " on \(element)"
        }
        log(DebugLogLevel.debug, category: DebugLogCategory.ui, message: message, file: file, function: function, line: line)
    }

    public func logNavigation(from source: String, to destination: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(DebugLogLevel.info, category: DebugLogCategory.navigation, message: "Navigation: \(source) -> \(destination)", file: file, function: function, line: line)
    }

    public func logPerformance(_ operation: String, duration: TimeInterval, file: String = #file, function: String = #function, line: Int = #line) {
        let durationMs = duration * 1000
        let level: DebugLogLevel = durationMs > 1000 ? DebugLogLevel.warning : (durationMs > 500 ? DebugLogLevel.info : DebugLogLevel.debug)
        log(level, category: DebugLogCategory.performance, message: "\(operation) completed in \(String(format: "%.2f", durationMs))ms", file: file, function: function, line: line)
    }

    // MARK: - Test Logging

    public func startTestSession() {
        testStartTime = Date()
        testResults.removeAll()
        sessionID = UUID()
        log(DebugLogLevel.info, category: DebugLogCategory.test, message: "Test session started - ID: \(sessionID.uuidString)")
    }

    public func recordTestResult(_ result: DebugTestResult) {
        testResults.append(result)
        let status = result.passed ? "PASSED" : "FAILED"
        let level: DebugLogLevel = result.passed ? DebugLogLevel.info : DebugLogLevel.error
        log(level, category: DebugLogCategory.test, message: "Test '\(result.testName)' \(status) in \(String(format: "%.2f", result.duration))s")
    }

    public func endTestSession() -> DebugTestReport? {
        guard let startTime = testStartTime else { return nil }

        let endTime = Date()
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let macOSVersion = Foundation.ProcessInfo.processInfo.operatingSystemVersionString

        let report = DebugTestReport(
            appVersion: appVersion,
            buildNumber: buildNumber,
            macOSVersion: macOSVersion,
            startTime: startTime,
            endTime: endTime,
            results: testResults,
            systemMetrics: DebugSystemTestMetrics()
        )

        log(DebugLogLevel.info, category: DebugLogCategory.test, message: "Test session ended - \(report.summary.passedTests)/\(report.summary.totalTests) passed (\(String(format: "%.1f", report.summary.passRate))%)")

        // Save report
        saveTestReport(report)

        return report
    }

    // MARK: - File Operations

    private func startNewLogFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        currentLogFilePath = logDirectory.appendingPathComponent("craigoclean_\(timestamp).log")

        guard let path = currentLogFilePath else { return }

        FileManager.default.createFile(atPath: path.path, contents: nil, attributes: nil)
        logFileHandle = try? FileHandle(forWritingTo: path)

        // Write header
        let header = """
        ================================================================================
        Craig-O-Clean Debug Log
        Session ID: \(sessionID.uuidString)
        Started: \(Date())
        App Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
        macOS: \(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)
        ================================================================================

        """
        logFileHandle?.write(header.data(using: String.Encoding.utf8) ?? Data())
    }

    private func writeToFile(_ entry: DebugLogEntry) {
        let fileHandle = logFileHandle
        logQueue.async {
            let line = entry.formattedMessage + "\n"
            fileHandle?.write(line.data(using: String.Encoding.utf8) ?? Data())
        }
    }

    private func saveTestReport(_ report: DebugTestReport) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let reportPath = logDirectory.appendingPathComponent("test_report_\(timestamp).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(report) {
            try? data.write(to: reportPath)
            log(DebugLogLevel.info, category: DebugLogCategory.test, message: "Test report saved to: \(reportPath.path)")
        }
    }

    // MARK: - Export Methods

    /// Export all logs to a JSON file
    public func exportLogsToJSON() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let exportPath = logDirectory.appendingPathComponent("export_\(timestamp).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let payload = LogExportPayload(
            sessionID: sessionID.uuidString,
            exportTimestamp: ISO8601DateFormatter().string(from: Date()),
            totalEntries: logs.count,
            logs: logs
        )

        if let data = try? encoder.encode(payload) {
            try? data.write(to: exportPath)
            log(DebugLogLevel.info, category: DebugLogCategory.app, message: "Logs exported to: \(exportPath.path)")
            return exportPath
        }

        return nil
    }

    /// Export logs for automated testing consumption
    public func exportForAutomatedTesting() -> URL? {
        let exportPath = logDirectory.appendingPathComponent("automated_test_feed.json")

        let testLogs = logs.map { entry in
            AutomatedTestLogEntry(
                timestamp: entry.formattedTimestamp,
                level: entry.level.name,
                category: entry.category.rawValue,
                message: entry.message,
                location: "\(entry.file):\(entry.line)",
                additionalInfo: entry.additionalInfo
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        if let data = try? encoder.encode(testLogs) {
            try? data.write(to: exportPath)
            return exportPath
        }

        return nil
    }

    // MARK: - Filtering

    public func getFilteredLogs(level: DebugLogLevel? = nil, category: DebugLogCategory? = nil, searchText: String? = nil) -> [DebugLogEntry] {
        var filtered = logs

        if let level = level {
            filtered = filtered.filter { $0.level >= level }
        }

        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        if let searchText = searchText, !searchText.isEmpty {
            filtered = filtered.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return filtered
    }

    // MARK: - Utility Methods

    public func clearLogs() {
        logs.removeAll()
        log(DebugLogLevel.info, category: DebugLogCategory.app, message: "Logs cleared")
    }

    public func getLogDirectory() -> URL {
        return logDirectory
    }

    public func getCurrentLogFile() -> URL? {
        return currentLogFilePath
    }

    public var errorCount: Int {
        logs.filter { $0.level >= DebugLogLevel.error }.count
    }

    public var warningCount: Int {
        logs.filter { $0.level == DebugLogLevel.warning }.count
    }
}

// MARK: - Export Payload Structs

/// Payload structure for log exports
private struct LogExportPayload: Codable {
    let sessionID: String
    let exportTimestamp: String
    let totalEntries: Int
    let logs: [DebugLogEntry]
}

/// Simplified log entry for automated testing
private struct AutomatedTestLogEntry: Codable {
    let timestamp: String
    let level: String
    let category: String
    let message: String
    let location: String
    let additionalInfo: [String: String]?
}

// MARK: - Log Extension for SwiftUI Views

extension View {
    /// Log when a view appears
    func logAppearance(viewName: String) -> some View {
        self.onAppear {
            Task { @MainActor in
                DebugLogger.shared.logNavigation(from: "Navigation", to: viewName)
            }
        }
    }

    /// Log when a view disappears
    func logDisappearance(viewName: String) -> some View {
        self.onDisappear {
            Task { @MainActor in
                DebugLogger.shared.debug("View disappeared: \(viewName)", category: DebugLogCategory.navigation)
            }
        }
    }
}

// MARK: - Performance Measurement Helper

public struct PerformanceMeasure {
    private let operation: String
    private let startTime: Date

    public init(_ operation: String) {
        self.operation = operation
        self.startTime = Date()
    }

    @MainActor
    public func complete() {
        let duration = Date().timeIntervalSince(startTime)
        DebugLogger.shared.logPerformance(operation, duration: duration)
    }
}

// MARK: - Global Logging Functions (Convenience)

/// Quick log function for use throughout the app
@MainActor
public func appLog(_ message: String, level: DebugLogLevel = DebugLogLevel.info, category: DebugLogCategory = DebugLogCategory.app, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.shared.log(level, category: category, message: message, file: file, function: function, line: line)
}
