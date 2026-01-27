//
//  RunRecord.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - Execution Status

enum ExecutionStatus: String, Codable {
    case success
    case failed
    case cancelled
    case timeout
}

// MARK: - Run Record

/// Immutable record of a capability execution
struct RunRecord: Codable, Identifiable {

    // MARK: - Core Identity
    let id: UUID
    let timestamp: Date
    let capabilityId: String
    let capabilityTitle: String
    let privilegeLevel: PrivilegeLevel

    // MARK: - Execution Context
    let arguments: [String: String]

    // MARK: - Execution Metadata
    let durationMs: Int
    let exitCode: Int32
    let status: ExecutionStatus

    // MARK: - Output References
    let stdoutPath: String?  // Path to file if output > 10KB
    let stderrPath: String?
    let outputSizeBytes: Int

    // MARK: - Parsed Summary
    let parsedSummary: String?
    let parsedData: Data?  // JSON-encoded ParsedOutput

    // MARK: - Audit Chain
    let previousRecordHash: String?
    let recordHash: String

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date,
        capabilityId: String,
        capabilityTitle: String,
        privilegeLevel: PrivilegeLevel,
        arguments: [String: String],
        durationMs: Int,
        exitCode: Int32,
        status: ExecutionStatus,
        stdoutPath: String?,
        stderrPath: String?,
        outputSizeBytes: Int,
        parsedSummary: String?,
        parsedData: Data?,
        previousRecordHash: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.capabilityId = capabilityId
        self.capabilityTitle = capabilityTitle
        self.privilegeLevel = privilegeLevel
        self.arguments = arguments
        self.durationMs = durationMs
        self.exitCode = exitCode
        self.status = status
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
        self.outputSizeBytes = outputSizeBytes
        self.parsedSummary = parsedSummary
        self.parsedData = parsedData
        self.previousRecordHash = previousRecordHash
        self.recordHash = Self.computeHash(
            id: id,
            timestamp: timestamp,
            capabilityId: capabilityId,
            exitCode: exitCode,
            previousHash: previousRecordHash
        )
    }

    // MARK: - Hash Computation

    /// Compute SHA-256 hash for audit chain
    private static func computeHash(
        id: UUID,
        timestamp: Date,
        capabilityId: String,
        exitCode: Int32,
        previousHash: String?
    ) -> String {
        var hashInput = ""
        hashInput += id.uuidString
        hashInput += String(Int(timestamp.timeIntervalSince1970))
        hashInput += capabilityId
        hashInput += String(exitCode)
        if let previousHash = previousHash {
            hashInput += previousHash
        }

        let data = Data(hashInput.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Helpers

    /// Create summary text for UI display
    var displaySummary: String {
        if let summary = parsedSummary {
            return summary
        }

        switch status {
        case .success:
            return "Completed successfully in \(durationMs)ms"
        case .failed:
            return "Failed with exit code \(exitCode)"
        case .cancelled:
            return "Cancelled by user"
        case .timeout:
            return "Timed out after \(durationMs)ms"
        }
    }

    /// Check if output is stored in files vs inline
    var hasLargeOutput: Bool {
        stdoutPath != nil || stderrPath != nil
    }
}

// MARK: - Run Record Builder

/// Builder for constructing RunRecord from execution results
struct RunRecordBuilder {
    private var id: UUID = UUID()
    private var timestamp: Date = Date()
    private var capabilityId: String = ""
    private var capabilityTitle: String = ""
    private var privilegeLevel: PrivilegeLevel = .user
    private var arguments: [String: String] = [:]
    private var durationMs: Int = 0
    private var exitCode: Int32 = 0
    private var status: ExecutionStatus = .success
    private var stdoutPath: String?
    private var stderrPath: String?
    private var outputSizeBytes: Int = 0
    private var parsedSummary: String?
    private var parsedData: Data?
    private var previousRecordHash: String?

    mutating func setCapability(_ capability: Capability) {
        self.capabilityId = capability.id
        self.capabilityTitle = capability.title
        self.privilegeLevel = capability.privilegeLevel
    }

    mutating func setArguments(_ args: [String: String]) {
        self.arguments = args
    }

    mutating func setExecution(
        startTime: Date,
        endTime: Date,
        exitCode: Int32,
        status: ExecutionStatus
    ) {
        self.timestamp = startTime
        self.durationMs = Int((endTime.timeIntervalSince(startTime)) * 1000)
        self.exitCode = exitCode
        self.status = status
    }

    mutating func setOutput(
        stdoutPath: String?,
        stderrPath: String?,
        outputSizeBytes: Int
    ) {
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
        self.outputSizeBytes = outputSizeBytes
    }

    mutating func setParsedData(
        summary: String?,
        data: Data?
    ) {
        self.parsedSummary = summary
        self.parsedData = data
    }

    mutating func setPreviousHash(_ hash: String?) {
        self.previousRecordHash = hash
    }

    func build() -> RunRecord {
        RunRecord(
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
}
