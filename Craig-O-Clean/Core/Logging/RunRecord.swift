// MARK: - RunRecord.swift
// Craig-O-Clean - Unified Run Record Model
// Captures execution metadata for audit trail and activity log

import Foundation

/// Record of a single capability execution
struct RunRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let capabilityId: String
    let capabilityTitle: String
    let privilegeLevel: PrivilegeLevel
    let arguments: [String: String]

    // Execution metadata
    let durationMs: Int
    let exitCode: Int32
    let status: ExecutionStatus

    // Output previews (truncated for storage)
    let stdoutPreview: String?
    let stderrPreview: String?
    let outputSizeBytes: Int

    // Parsed summary
    let parsedSummary: String?

    var durationFormatted: String {
        if durationMs < 1000 {
            return "\(durationMs)ms"
        } else {
            return String(format: "%.1fs", Double(durationMs) / 1000.0)
        }
    }

    var statusIcon: String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .partialSuccess: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        case .permissionDenied: return "lock.fill"
        case .timeout: return "clock.badge.exclamationmark"
        }
    }
}
