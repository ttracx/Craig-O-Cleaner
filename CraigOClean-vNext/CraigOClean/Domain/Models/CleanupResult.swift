// File: CraigOClean-vNext/CraigOClean/Domain/Models/CleanupResult.swift
// Craig-O-Clean - Cleanup Result Model
// Represents the outcome of cleanup operations

import Foundation

/// Represents the result of a cleanup operation
public struct CleanupResult: Sendable {
    public let targetId: UUID
    public let targetName: String
    public let success: Bool
    public let bytesFreed: UInt64
    public let filesRemoved: Int
    public let errors: [CleanupError]
    public let startTime: Date
    public let endTime: Date

    public init(
        targetId: UUID,
        targetName: String,
        success: Bool,
        bytesFreed: UInt64,
        filesRemoved: Int,
        errors: [CleanupError] = [],
        startTime: Date,
        endTime: Date
    ) {
        self.targetId = targetId
        self.targetName = targetName
        self.success = success
        self.bytesFreed = bytesFreed
        self.filesRemoved = filesRemoved
        self.errors = errors
        self.startTime = startTime
        self.endTime = endTime
    }

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesFreed), countStyle: .file)
    }

    public var hasErrors: Bool {
        !errors.isEmpty
    }
}

// MARK: - Cleanup Session Result

/// Aggregated result for a full cleanup session (multiple targets)
public struct CleanupSessionResult: Sendable {
    public let sessionId: UUID
    public let results: [CleanupResult]
    public let startTime: Date
    public let endTime: Date

    public init(
        sessionId: UUID = UUID(),
        results: [CleanupResult],
        startTime: Date,
        endTime: Date
    ) {
        self.sessionId = sessionId
        self.results = results
        self.startTime = startTime
        self.endTime = endTime
    }

    public var totalBytesFreed: UInt64 {
        results.reduce(0) { $0 + $1.bytesFreed }
    }

    public var totalFilesRemoved: Int {
        results.reduce(0) { $0 + $1.filesRemoved }
    }

    public var successfulCount: Int {
        results.filter { $0.success }.count
    }

    public var failedCount: Int {
        results.filter { !$0.success }.count
    }

    public var allSuccessful: Bool {
        results.allSatisfy { $0.success }
    }

    public var formattedTotalBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytesFreed), countStyle: .file)
    }

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

// MARK: - Cleanup Error

/// Errors that can occur during cleanup operations
public enum CleanupError: Error, LocalizedError, Sendable {
    case fileNotFound(path: String)
    case permissionDenied(path: String)
    case inUse(path: String)
    case deletionFailed(path: String, underlyingError: String)
    case pathNotAllowed(path: String)
    case notSupportedInEdition(reason: String)
    case scanFailed(reason: String)
    case cancelled
    case unknown(message: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .inUse(let path):
            return "File in use: \(path)"
        case .deletionFailed(let path, let error):
            return "Failed to delete '\(path)': \(error)"
        case .pathNotAllowed(let path):
            return "Path not allowed in this edition: \(path)"
        case .notSupportedInEdition(let reason):
            return "Not supported: \(reason)"
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .cancelled:
            return "Operation was cancelled"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .fileNotFound, .inUse:
            return true
        case .permissionDenied, .pathNotAllowed, .notSupportedInEdition:
            return false
        case .deletionFailed, .scanFailed, .unknown:
            return true
        case .cancelled:
            return false
        }
    }
}

// MARK: - Scan Result

/// Result of a cleanup target scan (preview before actual cleanup)
public struct CleanupScanResult: Sendable {
    public let target: CleanupTarget
    public let files: [ScannedFileItem]
    public let totalSize: UInt64
    public let scanTime: Date
    public let errors: [CleanupError]

    public init(
        target: CleanupTarget,
        files: [ScannedFileItem],
        totalSize: UInt64,
        scanTime: Date = Date(),
        errors: [CleanupError] = []
    ) {
        self.target = target
        self.files = files
        self.totalSize = totalSize
        self.scanTime = scanTime
        self.errors = errors
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    public var fileCount: Int {
        files.count
    }
}
