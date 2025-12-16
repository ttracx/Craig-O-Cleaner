// MARK: - AppLogger.swift
// Comprehensive logging and debugging system for Craig-O-Clean
// Supports real-time logging, export, and integration with testing infrastructure

import Foundation
import os.log
import Combine

// MARK: - Log Levels

enum LogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: String]
    let stackTrace: String?
    let error: ErrorDetails?
    let sessionId: String
    let threadId: String
    
    struct ErrorDetails: Codable, Hashable {
        let domain: String
        let code: Int
        let description: String
        let userInfo: [String: String]
    }
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        stackTrace: String? = nil,
        error: Error? = nil,
        sessionId: String,
        threadId: String = Thread.current.description
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.stackTrace = stackTrace
        self.sessionId = sessionId
        self.threadId = threadId
        
        if let error = error {
            self.error = ErrorDetails(
                domain: (error as NSError).domain,
                code: (error as NSError).code,
                description: error.localizedDescription,
                userInfo: (error as NSError).userInfo.reduce(into: [String: String]()) { result, pair in
                    result[String(describing: pair.key)] = String(describing: pair.value)
                }
            )
        } else {
            self.error = nil
        }
    }
    
    var formattedMessage: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timeString = timeFormatter.string(from: timestamp)
        
        var output = "[\(timeString)] [\(level.rawValue)] [\(category)] \(message)"
        
        if !metadata.isEmpty {
            output += " | Metadata: \(metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        }
        
        if let error = error {
            output += " | Error: \(error.domain)(\(error.code)) - \(error.description)"
        }
        
        if let stackTrace = stackTrace {
            output += "\nStack Trace:\n\(stackTrace)"
        }
        
        return output
    }
}

// MARK: - Performance Metric

struct PerformanceMetric: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let operation: String
    let duration: TimeInterval
    let metadata: [String: String]
    let sessionId: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        duration: TimeInterval,
        metadata: [String: String] = [:],
        sessionId: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.duration = duration
        self.metadata = metadata
        self.sessionId = sessionId
    }
}

// MARK: - UI Event

struct UIEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let eventType: String
    let viewName: String
    let action: String
    let metadata: [String: String]
    let sessionId: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        viewName: String,
        action: String,
        metadata: [String: String] = [:],
        sessionId: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.viewName = viewName
        self.action = action
        self.metadata = metadata
        self.sessionId = sessionId
    }
}

// MARK: - App Logger

@MainActor
final class AppLogger: ObservableObject {
    static let shared = AppLogger()
    
    // MARK: - Properties
    
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var performanceMetrics: [PerformanceMetric] = []
    @Published private(set) var uiEvents: [UIEvent] = []
    
    private let osLogger = Logger(subsystem: "com.craigoclean.app", category: "AppLogger")
    private let maxLogEntries = 10000
    private let maxPerformanceMetrics = 5000
    private let maxUIEvents = 5000
    
    let sessionId: String
    private let logQueue = DispatchQueue(label: "com.craigoclean.logger", qos: .utility)
    
    // Export file paths
    private var exportDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CraigOCleanLogs", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        sessionId = UUID().uuidString
        
        // Create export directory
        try? FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        
        // Log session start
        log(level: .info, category: "App", message: "App session started", metadata: ["sessionId": sessionId])
    }
    
    // MARK: - Logging Methods
    
    func log(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let stackTrace: String?
        if level == .error || level == .critical {
            stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        } else {
            stackTrace = nil
        }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata.merging([
                "file": (file as NSString).lastPathComponent,
                "function": function,
                "line": "\(line)"
            ]) { _, new in new },
            stackTrace: stackTrace,
            error: error,
            sessionId: sessionId
        )
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to in-memory store
            Task { @MainActor in
                self.logs.append(entry)
                if self.logs.count > self.maxLogEntries {
                    self.logs.removeFirst(self.logs.count - self.maxLogEntries)
                }
            }
            
            // Log to system logger
            self.osLogger.log(level: entry.level.osLogType, "\(entry.category): \(entry.message)")
            
            // Log to console in debug builds
            #if DEBUG
            print(entry.formattedMessage)
            #endif
        }
    }
    
    // Convenience methods
    func debug(_ message: String, category: String = "App", metadata: [String: String] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    func info(_ message: String, category: String = "App", metadata: [String: String] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }
    
    func warning(_ message: String, category: String = "App", metadata: [String: String] = [:], error: Error? = nil) {
        log(level: .warning, category: category, message: message, metadata: metadata, error: error)
    }
    
    func error(_ message: String, category: String = "App", metadata: [String: String] = [:], error: Error? = nil) {
        log(level: .error, category: category, message: message, metadata: metadata, error: error)
    }
    
    func critical(_ message: String, category: String = "App", metadata: [String: String] = [:], error: Error? = nil) {
        log(level: .critical, category: category, message: message, metadata: metadata, error: error)
    }
    
    // MARK: - Performance Tracking
    
    func startPerformanceTracking(operation: String, metadata: [String: String] = [:]) -> PerformanceTracker {
        return PerformanceTracker(operation: operation, metadata: metadata, logger: self)
    }
    
    func recordPerformance(operation: String, duration: TimeInterval, metadata: [String: String] = [:]) {
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            metadata: metadata,
            sessionId: sessionId
        )
        
        Task { @MainActor in
            performanceMetrics.append(metric)
            if performanceMetrics.count > maxPerformanceMetrics {
                performanceMetrics.removeFirst(performanceMetrics.count - maxPerformanceMetrics)
            }
        }
        
        log(level: .debug, category: "Performance", message: "\(operation) took \(String(format: "%.3f", duration))s", metadata: metadata)
    }
    
    // MARK: - UI Event Tracking
    
    func trackUIEvent(eventType: String, viewName: String, action: String, metadata: [String: String] = [:]) {
        let event = UIEvent(
            eventType: eventType,
            viewName: viewName,
            action: action,
            metadata: metadata,
            sessionId: sessionId
        )
        
        Task { @MainActor in
            uiEvents.append(event)
            if uiEvents.count > maxUIEvents {
                uiEvents.removeFirst(uiEvents.count - maxUIEvents)
            }
        }
        
        log(level: .debug, category: "UI", message: "\(eventType) in \(viewName): \(action)", metadata: metadata)
    }
    
    // MARK: - Export Methods
    
    func exportLogs(format: ExportFormat = .json) async throws -> URL {
        let currentLogs = self.logs
        let currentMetrics = self.performanceMetrics
        let currentEvents = self.uiEvents
        let currentSessionId = self.sessionId
        let currentExportDir = self.exportDirectory
        
        let result: (URL, String) = try await Task.detached { [currentLogs, currentMetrics, currentEvents, currentSessionId, currentExportDir, format] in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data: Data
            switch format {
            case .json:
                data = try encoder.encode(ExportData(
                    sessionId: currentSessionId,
                    timestamp: Date(),
                    logs: currentLogs,
                    performanceMetrics: currentMetrics,
                    uiEvents: currentEvents
                ))
            case .text:
                let text = AppLogger.generateTextReportStatic(
                    logs: currentLogs,
                    performanceMetrics: currentMetrics,
                    uiEvents: currentEvents,
                    sessionId: currentSessionId
                )
                data = text.data(using: .utf8) ?? Data()
            case .csv:
                let csv = AppLogger.generateCSVReportStatic(
                    logs: currentLogs,
                    performanceMetrics: currentMetrics,
                    uiEvents: currentEvents
                )
                data = csv.data(using: .utf8) ?? Data()
            }
            
            let timestamp = Date().timeIntervalSince1970
            let filename = "craigoclean_logs_\(currentSessionId)_\(timestamp).\(format.fileExtension)"
            let fileURL = currentExportDir.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            
            return (fileURL, filename)
        }.value
        
        // Log export completion
        self.log(level: .info, category: "Export", message: "Logs exported to \(result.1)", metadata: ["format": format.rawValue])
        
        return result.0
    }
    
    private nonisolated static func generateTextReportStatic(logs: [LogEntry], performanceMetrics: [PerformanceMetric], uiEvents: [UIEvent], sessionId: String) -> String {
        var report = """
        ========================================
        Craig-O-Clean Debug Report
        ========================================
        Session ID: \(sessionId)
        Generated: \(Date())
        
        ========================================
        LOGS (\(logs.count) entries)
        ========================================
        
        """
        
        for log in logs {
            report += log.formattedMessage + "\n\n"
        }
        
        report += """
        
        ========================================
        PERFORMANCE METRICS (\(performanceMetrics.count) entries)
        ========================================
        
        """
        
        for metric in performanceMetrics.sorted(by: { $0.duration > $1.duration }) {
            report += "[\(metric.timestamp)] \(metric.operation): \(String(format: "%.3f", metric.duration))s\n"
            if !metric.metadata.isEmpty {
                report += "  Metadata: \(metric.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))\n"
            }
        }
        
        report += """
        
        ========================================
        UI EVENTS (\(uiEvents.count) entries)
        ========================================
        
        """
        
        for event in uiEvents {
            report += "[\(event.timestamp)] \(event.eventType) in \(event.viewName): \(event.action)\n"
            if !event.metadata.isEmpty {
                report += "  Metadata: \(event.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))\n"
            }
        }
        
        return report
    }
    
    private nonisolated static func generateCSVReportStatic(logs: [LogEntry], performanceMetrics: [PerformanceMetric], uiEvents: [UIEvent]) -> String {
        var csv = "Type,Timestamp,Category/Operation/View,Message/Action,Duration,Metadata,Error\n"
        
        // Logs
        for log in logs {
            let metadataStr = log.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            let errorStr = log.error.map { "\($0.domain):\($0.code)" } ?? ""
            csv += "LOG,\(log.timestamp),\(log.category),\"\(log.message)\",,\(metadataStr),\(errorStr)\n"
        }
        
        // Performance
        for metric in performanceMetrics {
            let metadataStr = metric.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            csv += "PERFORMANCE,\(metric.timestamp),\(metric.operation),,\(metric.duration),\(metadataStr),\n"
        }
        
        // UI Events
        for event in uiEvents {
            let metadataStr = event.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            csv += "UI_EVENT,\(event.timestamp),\(event.viewName),\(event.action),,\(metadataStr),\n"
        }
        
        return csv
    }
    
    // MARK: - Analysis Methods
    
    func getErrorSummary() -> [String: Int] {
        var summary: [String: Int] = [:]
        for log in logs where log.level == .error || log.level == .critical {
            summary[log.category, default: 0] += 1
        }
        return summary
    }
    
    func getPerformanceSummary() -> [(operation: String, avgDuration: TimeInterval, count: Int)] {
        var operationDurations: [String: [TimeInterval]] = [:]
        for metric in performanceMetrics {
            operationDurations[metric.operation, default: []].append(metric.duration)
        }
        
        return operationDurations.map { operation, durations in
            let avg = durations.reduce(0, +) / Double(durations.count)
            return (operation: operation, avgDuration: avg, count: durations.count)
        }.sorted { $0.avgDuration > $1.avgDuration }
    }
    
    func getSlowestOperations(limit: Int = 10) -> [PerformanceMetric] {
        return Array(performanceMetrics.sorted { $0.duration > $1.duration }.prefix(limit))
    }
    
    func clearLogs() {
        logs.removeAll()
        performanceMetrics.removeAll()
        uiEvents.removeAll()
        log(level: .info, category: "App", message: "Logs cleared")
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case text = "Text"
    case csv = "CSV"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .text: return "txt"
        case .csv: return "csv"
        }
    }
}

struct ExportData: Codable {
    let sessionId: String
    let timestamp: Date
    let logs: [LogEntry]
    let performanceMetrics: [PerformanceMetric]
    let uiEvents: [UIEvent]
}

// MARK: - Performance Tracker

class PerformanceTracker {
    private let operation: String
    private let metadata: [String: String]
    private weak var logger: AppLogger?
    private let startTime: Date
    
    init(operation: String, metadata: [String: String], logger: AppLogger) {
        self.operation = operation
        self.metadata = metadata
        self.logger = logger
        self.startTime = Date()
    }
    
    func end() {
        let duration = Date().timeIntervalSince(startTime)
        Task { @MainActor in
            logger?.recordPerformance(operation: operation, duration: duration, metadata: metadata)
        }
    }
    
    deinit {
        end()
    }
}
