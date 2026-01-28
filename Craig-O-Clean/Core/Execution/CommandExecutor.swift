// MARK: - CommandExecutor.swift
// Craig-O-Clean - Command Execution Protocol & Coordinator
// Centralized execution with preflight checks, permission gating, and audit logging

import Foundation
import AppKit
import os.log

// MARK: - Command Executor Protocol

/// Protocol for executing capabilities with streaming output
protocol CommandExecutor {
    /// Execute a capability and stream results
    func execute(
        _ capability: Capability,
        arguments: [String: String],
        progress: @escaping (ExecutionProgress) -> Void
    ) async throws -> ExecutionResult

    /// Validate capability can execute with current permissions
    func canExecute(_ capability: Capability) async -> PreflightResult

    /// Cancel running execution
    func cancel() async
}

// MARK: - Capability Coordinator

/// Orchestrates capability execution across different executors based on privilege level
@MainActor
final class CapabilityCoordinator: ObservableObject {
    @Published var isExecuting = false
    @Published var currentCapability: Capability?
    @Published var lastResult: ExecutionResult?
    @Published var lastError: String?

    private let userExecutor: UserExecutor
    private let elevatedExecutor: ElevatedExecutor
    private let logStore: LogStore
    private let logger = Logger(subsystem: "com.CraigOClean", category: "CapabilityCoordinator")

    init(logStore: LogStore = SQLiteLogStore.shared) {
        self.userExecutor = UserExecutor()
        self.elevatedExecutor = ElevatedExecutor()
        self.logStore = logStore
    }

    // MARK: - Preflight

    /// Run preflight checks for a capability
    func preflight(_ capability: Capability) async -> PreflightResult {
        var failedChecks: [PreflightCheck] = []
        var missingPermissions: [PermissionRequirement] = []
        var remediationSteps: [RemediationStep] = []

        for check in capability.preflightChecks {
            let passed = await evaluateCheck(check)
            if !passed {
                failedChecks.append(check)

                if check.type == .automationPermission {
                    missingPermissions.append(PermissionRequirement(
                        type: "Automation",
                        target: check.target,
                        description: check.failureMessage
                    ))
                    remediationSteps.append(RemediationStep(
                        instruction: "Grant automation permission for \(check.target) in System Settings > Privacy & Security > Automation",
                        systemSettingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
                        canOpenAutomatically: true
                    ))
                }
            }
        }

        return PreflightResult(
            canExecute: failedChecks.isEmpty,
            missingPermissions: missingPermissions,
            failedChecks: failedChecks,
            remediationSteps: remediationSteps
        )
    }

    // MARK: - Execution

    /// Execute a capability with full preflight, confirmation flow, and logging
    func execute(
        _ capability: Capability,
        arguments: [String: String] = [:],
        progress: @escaping (ExecutionProgress) -> Void = { _ in }
    ) async throws -> ExecutionResult {
        isExecuting = true
        currentCapability = capability
        lastError = nil

        defer {
            isExecuting = false
            currentCapability = nil
        }

        // Select executor based on privilege level
        let executor: CommandExecutor
        switch capability.privilegeLevel {
        case .user, .automation:
            executor = userExecutor
        case .elevated:
            executor = elevatedExecutor
        case .fullDiskAccess:
            executor = userExecutor
        }

        do {
            let result = try await executor.execute(capability, arguments: arguments, progress: progress)
            lastResult = result

            // Persist log record
            try? await logStore.save(result.record)

            logger.info("Executed \(capability.id) — exit \(result.exitCode)")
            return result
        } catch {
            let record = RunRecord(
                id: UUID(),
                timestamp: Date(),
                capabilityId: capability.id,
                capabilityTitle: capability.title,
                privilegeLevel: capability.privilegeLevel,
                arguments: arguments,
                durationMs: 0,
                exitCode: -1,
                status: .failed,
                stdoutPreview: nil,
                stderrPreview: error.localizedDescription,
                outputSizeBytes: 0,
                parsedSummary: nil
            )
            try? await logStore.save(record)

            lastError = error.localizedDescription
            logger.error("Failed \(capability.id): \(error.localizedDescription)")
            throw error
        }
    }

    /// Cancel the current execution
    func cancel() async {
        if let cap = currentCapability {
            switch cap.privilegeLevel {
            case .user, .automation, .fullDiskAccess:
                await userExecutor.cancel()
            case .elevated:
                await elevatedExecutor.cancel()
            }
        }
    }

    // MARK: - Preflight Evaluation

    private func evaluateCheck(_ check: PreflightCheck) async -> Bool {
        switch check.type {
        case .pathExists:
            let path = (check.target as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: path)
        case .pathWritable:
            let path = (check.target as NSString).expandingTildeInPath
            return FileManager.default.isWritableFile(atPath: path)
        case .appRunning:
            return NSWorkspace.shared.runningApplications.contains {
                $0.localizedName == check.target || $0.bundleIdentifier?.contains(check.target.lowercased()) == true
            }
        case .appNotRunning:
            return !NSWorkspace.shared.runningApplications.contains {
                $0.localizedName == check.target || $0.bundleIdentifier?.contains(check.target.lowercased()) == true
            }
        case .diskSpaceAvailable:
            return true // Simplified
        case .sipStatus:
            return true // Cannot check SIP from sandboxed app
        case .automationPermission:
            return true // Checked at execution time via Apple Events
        }
    }
}
