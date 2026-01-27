// MARK: - RunRecord.swift
// Craig-O-Clean - Run Record Model
// Structured audit record for every capability execution

import Foundation

struct RunRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let capabilityId: String
    let capabilityTitle: String
    let category: String
    let argsHash: String
    let privilegeLevel: String
    let durationMs: Int
    let exitCode: Int32
    let success: Bool
    let stdoutPath: String?
    let stderrPath: String?
    let parsedSummaryJSON: String?
    let remediationHint: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        capabilityId: String,
        capabilityTitle: String,
        category: String,
        argsHash: String = "",
        privilegeLevel: String,
        durationMs: Int,
        exitCode: Int32,
        success: Bool,
        stdoutPath: String? = nil,
        stderrPath: String? = nil,
        parsedSummaryJSON: String? = nil,
        remediationHint: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.capabilityId = capabilityId
        self.capabilityTitle = capabilityTitle
        self.category = category
        self.argsHash = argsHash
        self.privilegeLevel = privilegeLevel
        self.durationMs = durationMs
        self.exitCode = exitCode
        self.success = success
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
        self.parsedSummaryJSON = parsedSummaryJSON
        self.remediationHint = remediationHint
    }

    // MARK: - Computed Properties

    var formattedDuration: String {
        if durationMs < 1000 {
            return "\(durationMs)ms"
        } else {
            return String(format: "%.1fs", Double(durationMs) / 1000.0)
        }
    }

    var statusEmoji: String {
        success ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}
