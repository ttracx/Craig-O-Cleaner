// MARK: - ActionResult.swift
// Craig-O-Clean - Result Envelope Types
// Provides structured results for all operations with timing and metadata

import Foundation

/// Generic result envelope for all operations
struct ActionResult<T> {
    let success: Bool
    let value: T?
    let error: CraigOCleanError?
    let timestamp: Date
    let duration: TimeInterval
    let metadata: [String: String]

    private init(
        success: Bool,
        value: T?,
        error: CraigOCleanError?,
        timestamp: Date,
        duration: TimeInterval,
        metadata: [String: String]
    ) {
        self.success = success
        self.value = value
        self.error = error
        self.timestamp = timestamp
        self.duration = duration
        self.metadata = metadata
    }

    /// Create a successful result
    static func success(_ value: T, duration: TimeInterval = 0, metadata: [String: String] = [:]) -> ActionResult<T> {
        ActionResult(
            success: true,
            value: value,
            error: nil,
            timestamp: Date(),
            duration: duration,
            metadata: metadata
        )
    }

    /// Create a failed result
    static func failure(_ error: CraigOCleanError, duration: TimeInterval = 0, metadata: [String: String] = [:]) -> ActionResult<T> {
        ActionResult(
            success: false,
            value: nil,
            error: error,
            timestamp: Date(),
            duration: duration,
            metadata: metadata
        )
    }

    /// Map the value to a new type
    func map<U>(_ transform: (T) -> U) -> ActionResult<U> {
        if let value = value {
            return ActionResult<U>(
                success: success,
                value: transform(value),
                error: error,
                timestamp: timestamp,
                duration: duration,
                metadata: metadata
            )
        } else {
            return ActionResult<U>(
                success: success,
                value: nil,
                error: error,
                timestamp: timestamp,
                duration: duration,
                metadata: metadata
            )
        }
    }

    /// Convert to void result (discarding value)
    func asVoid() -> ActionResult<Void> {
        ActionResult<Void>(
            success: success,
            value: success ? () : nil,
            error: error,
            timestamp: timestamp,
            duration: duration,
            metadata: metadata
        )
    }
}

// MARK: - ActionResult where T == Void

extension ActionResult where T == Void {
    /// Create a successful void result
    static func success(duration: TimeInterval = 0, metadata: [String: String] = [:]) -> ActionResult<Void> {
        ActionResult(
            success: true,
            value: (),
            error: nil,
            timestamp: Date(),
            duration: duration,
            metadata: metadata
        )
    }
}

// MARK: - Timed Execution Helper

/// Execute an operation and wrap the result with timing
func timedOperation<T>(_ operation: () throws -> T) -> ActionResult<T> {
    let start = Date()
    do {
        let result = try operation()
        let duration = Date().timeIntervalSince(start)
        return .success(result, duration: duration)
    } catch let error as CraigOCleanError {
        let duration = Date().timeIntervalSince(start)
        return .failure(error, duration: duration)
    } catch {
        let duration = Date().timeIntervalSince(start)
        return .failure(.operationFailed(description: error.localizedDescription, underlying: error), duration: duration)
    }
}

/// Execute an async operation and wrap the result with timing
func timedOperationAsync<T>(_ operation: () async throws -> T) async -> ActionResult<T> {
    let start = Date()
    do {
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)
        return .success(result, duration: duration)
    } catch let error as CraigOCleanError {
        let duration = Date().timeIntervalSince(start)
        return .failure(error, duration: duration)
    } catch {
        let duration = Date().timeIntervalSince(start)
        return .failure(.operationFailed(description: error.localizedDescription, underlying: error), duration: duration)
    }
}

// MARK: - Specific Result Types

/// Result for cleanup operations
struct CleanupResult {
    let deletedCount: Int
    let failedCount: Int
    let freedSpace: UInt64
    let errors: [CleanupError]
    let skippedFiles: [URL]
    let duration: TimeInterval

    var success: Bool { failedCount == 0 && errors.isEmpty }

    static let empty = CleanupResult(
        deletedCount: 0,
        failedCount: 0,
        freedSpace: 0,
        errors: [],
        skippedFiles: [],
        duration: 0
    )
}

/// Error during cleanup operation
struct CleanupError: Error, Identifiable {
    let id = UUID()
    let url: URL
    let reason: String
    let underlying: Error?
}

/// Result for dry-run scan operations
struct ScanResults {
    var files: [ScannedFile] = []
    var totalSize: UInt64 = 0
    var folder: AuthorizedFolder?
    var error: CraigOCleanError?
    var scanDuration: TimeInterval = 0

    var fileCount: Int { files.count }
    var success: Bool { error == nil }

    static let empty = ScanResults()
}

/// Information about a scanned file
struct ScannedFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: UInt64
    let modificationDate: Date?
    let fileType: String

    var name: String { url.lastPathComponent }
    var path: String { url.path }
}

/// Result for process termination
struct ProcessTerminationResult {
    let processName: String
    let processId: pid_t
    let terminated: Bool
    let method: TerminationMethod
    let error: CraigOCleanError?

    enum TerminationMethod: String {
        case graceful = "graceful"
        case force = "force"
        case appleScript = "appleScript"
    }
}

/// Result for browser tab operations
struct TabOperationResult {
    let browser: String
    let tabsClosed: Int
    let tabsFailed: Int
    let errors: [String]

    var success: Bool { tabsFailed == 0 && errors.isEmpty }
}

// MARK: - Permission State

/// State of a permission check
enum PermissionState: String, Equatable {
    case unknown = "unknown"
    case granted = "granted"
    case denied = "denied"
    case notDetermined = "notDetermined"
    case restricted = "restricted"

    var isGranted: Bool { self == .granted }
    var isDenied: Bool { self == .denied || self == .restricted }
    var needsRequest: Bool { self == .notDetermined || self == .unknown }

    var displayText: String {
        switch self {
        case .unknown: return "Unknown"
        case .granted: return "Enabled"
        case .denied: return "Disabled"
        case .notDetermined: return "Not Requested"
        case .restricted: return "Restricted"
        }
    }

    var iconName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined, .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .granted: return "green"
        case .denied, .restricted: return "red"
        case .notDetermined, .unknown: return "yellow"
        }
    }
}

// MARK: - Authorized Folder

/// Represents a folder authorized via security-scoped bookmark
struct AuthorizedFolder: Identifiable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let bookmarkData: Data
    let createdAt: Date
    let displayName: String?

    var name: String { displayName ?? url.lastPathComponent }
    var path: String { url.path }

    init(id: UUID = UUID(), url: URL, bookmarkData: Data, createdAt: Date = Date(), displayName: String? = nil) {
        self.id = id
        self.url = url
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.displayName = displayName
    }

    static func == (lhs: AuthorizedFolder, rhs: AuthorizedFolder) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Cleanup Options

/// Options for cleanup operations
struct CleanupOptions: OptionSet {
    let rawValue: Int

    static let includeHidden = CleanupOptions(rawValue: 1 << 0)
    static let includeSubfolders = CleanupOptions(rawValue: 1 << 1)
    static let olderThanDays = CleanupOptions(rawValue: 1 << 2)
    static let largerThanSize = CleanupOptions(rawValue: 1 << 3)
    static let matchingPattern = CleanupOptions(rawValue: 1 << 4)

    static let `default`: CleanupOptions = [.includeSubfolders]
    static let all: CleanupOptions = [.includeHidden, .includeSubfolders]

    var olderThanDaysValue: Int?
    var largerThanSizeValue: UInt64?
    var patternValue: String?
}

// MARK: - Cleanup Preset

/// Preset cleanup target with suggested path and description
struct CleanupPreset: Identifiable {
    let id = UUID()
    let name: String
    let suggestedPath: String
    let description: String
    let estimatedSavings: String
    let icon: String
    let riskLevel: RiskLevel

    enum RiskLevel: String {
        case safe
        case moderate
        case caution

        var color: String {
            switch self {
            case .safe: return "green"
            case .moderate: return "yellow"
            case .caution: return "orange"
            }
        }
    }

    /// Expand ~ in path to full home directory path
    var expandedPath: String {
        if suggestedPath.hasPrefix("~") {
            return NSString(string: suggestedPath).expandingTildeInPath
        }
        return suggestedPath
    }
}
