//
//  WorkflowExecutor.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import Foundation
import Observation

/// Executes AI-generated workflows step by step
@Observable
final class WorkflowExecutor {

    // MARK: - Observable State

    var currentStep: Int = 0
    var totalSteps: Int = 0
    var isExecuting: Bool = false
    var currentStepDescription: String = ""
    var progress: Double = 0.0

    // MARK: - Properties

    private let capabilityCatalog: CapabilityCatalog
    private let userExecutor: UserExecutor
    private let elevatedExecutor: ElevatedExecutor
    private let logStore: SQLiteLogStore

    // MARK: - Initialization

    init(
        capabilityCatalog: CapabilityCatalog,
        userExecutor: UserExecutor,
        elevatedExecutor: ElevatedExecutor,
        logStore: SQLiteLogStore
    ) {
        self.capabilityCatalog = capabilityCatalog
        self.userExecutor = userExecutor
        self.elevatedExecutor = elevatedExecutor
        self.logStore = logStore
    }

    // MARK: - Execution

    /// Executes a workflow plan step by step
    func execute(
        plan: WorkflowPlan,
        onProgress: @escaping (WorkflowStepResult) -> Void
    ) async throws -> WorkflowResult {
        guard !isExecuting else {
            throw WorkflowError.alreadyExecuting
        }

        await MainActor.run {
            self.isExecuting = true
            self.totalSteps = plan.workflow.count
            self.currentStep = 0
            self.progress = 0.0
        }

        var results: [WorkflowStepResult] = []
        var failedSteps: [WorkflowStepResult] = []
        let startTime = Date()

        defer {
            Task { @MainActor in
                self.isExecuting = false
                self.currentStepDescription = ""
                self.progress = 1.0
            }
        }

        // Execute each step sequentially
        for (index, step) in plan.workflow.enumerated() {
            await MainActor.run {
                self.currentStep = index + 1
                self.currentStepDescription = step.reason
                self.progress = Double(index) / Double(plan.workflow.count)
            }

            do {
                let result = try await executeStep(step, index: index + 1)
                results.append(result)
                onProgress(result)

                // Stop if step failed critically
                if !result.success && result.isCritical {
                    failedSteps.append(result)
                    break
                }
            } catch {
                let failureResult = WorkflowStepResult(
                    step: step,
                    stepNumber: index + 1,
                    success: false,
                    output: nil,
                    error: error.localizedDescription,
                    duration: 0,
                    isCritical: true
                )
                results.append(failureResult)
                failedSteps.append(failureResult)
                onProgress(failureResult)
                break
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        await MainActor.run {
            self.progress = 1.0
        }

        return WorkflowResult(
            plan: plan,
            results: results,
            failedSteps: failedSteps,
            totalDuration: duration,
            completedAt: endTime,
            success: failedSteps.isEmpty
        )
    }

    // MARK: - Step Execution

    private func executeStep(_ step: WorkflowStep, index: Int) async throws -> WorkflowStepResult {
        guard let capability = capabilityCatalog.capability(id: step.capabilityId) else {
            throw WorkflowError.capabilityNotFound(step.capabilityId)
        }

        let startTime = Date()

        do {
            let executionResult: ExecutionResultWithOutput

            // Route to appropriate executor based on privilege level
            switch capability.privilegeLevel {
            case .user:
                executionResult = try await userExecutor.execute(
                    capability,
                    arguments: step.arguments
                )

            case .elevated:
                executionResult = try await elevatedExecutor.execute(
                    capability,
                    arguments: step.arguments
                )

            case .automation:
                // Automation capabilities (browser operations) go through user executor
                executionResult = try await userExecutor.execute(
                    capability,
                    arguments: step.arguments
                )

            case .fullDiskAccess:
                // Full disk access capabilities also use user executor
                executionResult = try await userExecutor.execute(
                    capability,
                    arguments: step.arguments
                )
            }

            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            // Note: Execution logging is handled by individual executors
            // try? await logStore.save(executionResult.record)

            return WorkflowStepResult(
                step: step,
                stepNumber: index,
                success: executionResult.exitCode == 0,
                output: executionResult.stdout,
                error: executionResult.exitCode != 0 ? executionResult.stderr : nil,
                duration: duration,
                isCritical: capability.riskClass == .destructive
            )

        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            return WorkflowStepResult(
                step: step,
                stepNumber: index,
                success: false,
                output: nil,
                error: error.localizedDescription,
                duration: duration,
                isCritical: capability.riskClass == .destructive
            )
        }
    }

    /// Cancels the currently executing workflow
    func cancel() {
        Task { @MainActor in
            self.isExecuting = false
            self.currentStepDescription = "Cancelled"
        }
    }
}

// MARK: - Result Models

struct WorkflowStepResult: Identifiable {
    let step: WorkflowStep
    let stepNumber: Int
    let success: Bool
    let output: String?
    let error: String?
    let duration: TimeInterval
    let isCritical: Bool

    var id: String { "\(stepNumber)-\(step.capabilityId)" }

    var statusIcon: String {
        success ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    var statusColor: String {
        success ? "green" : "red"
    }
}

struct WorkflowResult {
    let plan: WorkflowPlan
    let results: [WorkflowStepResult]
    let failedSteps: [WorkflowStepResult]
    let totalDuration: TimeInterval
    let completedAt: Date
    let success: Bool

    var successRate: Double {
        guard !results.isEmpty else { return 0.0 }
        let successfulSteps = results.filter { $0.success }.count
        return Double(successfulSteps) / Double(results.count)
    }

    var summaryText: String {
        let successCount = results.filter { $0.success }.count
        let totalCount = results.count

        if success {
            return "✅ Successfully completed all \(totalCount) steps in \(formattedDuration)"
        } else {
            return "⚠️ Completed \(successCount) of \(totalCount) steps. \(failedSteps.count) failed."
        }
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalDuration) ?? "\(Int(totalDuration))s"
    }
}

// MARK: - Errors

enum WorkflowError: LocalizedError {
    case alreadyExecuting
    case capabilityNotFound(String)
    case executionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .alreadyExecuting:
            return "A workflow is already executing"
        case .capabilityNotFound(let id):
            return "Capability not found: \(id)"
        case .executionFailed(let reason):
            return "Workflow execution failed: \(reason)"
        case .cancelled:
            return "Workflow execution was cancelled"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .alreadyExecuting:
            return "Wait for the current workflow to complete"
        case .capabilityNotFound:
            return "Check that the workflow uses valid capability IDs"
        case .executionFailed:
            return "Review the error details and try again"
        case .cancelled:
            return "Start a new workflow when ready"
        }
    }
}
