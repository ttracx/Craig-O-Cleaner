// MARK: - PlannerAgent.swift
// Craig-O-Clean - AI Planner Agent
// Proposes cleanup plans, enforces safety gating, and manages approval workflows

import Foundation
import os.log

// MARK: - Plan Execution Status

enum PlanStepStatus: String, Codable {
    case pending
    case awaitingApproval
    case approved
    case rejected
    case running
    case completed
    case failed
    case skipped
}

struct PlanStepExecution: Identifiable {
    let id: UUID
    let step: AIStep
    var status: PlanStepStatus
    var result: ExecutionResult?
}

// MARK: - Safety Agent

enum SafetyAgent {
    /// Validates that a plan step is safe to execute
    static func validate(step: AIStep, capability: Capability?) -> (safe: Bool, reason: String?) {
        guard let cap = capability else {
            return (false, "Capability '\(step.capabilityId)' not found in catalog")
        }

        // Destructive capabilities always need approval
        if cap.riskClass == .destructive && !step.requiresApproval {
            return (false, "Destructive capability must have requiresApproval=true")
        }

        // Elevated capabilities always need approval
        if cap.requiredPrivileges == .elevated && !step.requiresApproval {
            return (false, "Elevated capability must have requiresApproval=true")
        }

        return (true, nil)
    }

    /// Validates an entire plan
    static func validatePlan(_ plan: AIPlan, catalog: CatalogStore) -> [String] {
        var issues: [String] = []

        for step in plan.steps {
            let cap = catalog.capability(byId: step.capabilityId)
            let result = validate(step: step, capability: cap)
            if !result.safe, let reason = result.reason {
                issues.append("Step '\(step.capabilityId)': \(reason)")
            }
        }

        return issues
    }
}

// MARK: - Planner Agent

@MainActor
final class PlannerAgent: ObservableObject {

    @Published private(set) var currentPlan: AIPlan?
    @Published private(set) var stepExecutions: [PlanStepExecution] = []
    @Published private(set) var isExecuting = false
    @Published private(set) var currentStepIndex: Int = 0

    private let ollamaClient: OllamaClient
    private let commandExecutor: CommandExecutor
    private let catalogStore: CatalogStore
    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "PlannerAgent")

    init(ollamaClient: OllamaClient, commandExecutor: CommandExecutor, catalogStore: CatalogStore) {
        self.ollamaClient = ollamaClient
        self.commandExecutor = commandExecutor
        self.catalogStore = catalogStore
    }

    /// Generate and validate a plan
    func proposePlan(systemContext: String) async -> AIPlan? {
        guard let plan = await ollamaClient.generatePlan(systemContext: systemContext) else {
            return nil
        }

        // Safety validation
        let issues = SafetyAgent.validatePlan(plan, catalog: catalogStore)
        if !issues.isEmpty {
            logger.warning("Plan has safety issues: \(issues.joined(separator: "; "))")
            // Plans with safety issues are still shown but steps are marked for approval
        }

        currentPlan = plan
        stepExecutions = plan.steps.map { step in
            let cap = catalogStore.capability(byId: step.capabilityId)
            let needsApproval = step.requiresApproval ||
                cap?.requiredPrivileges == .elevated ||
                cap?.riskClass == .destructive ||
                cap?.riskClass == .moderate

            return PlanStepExecution(
                id: step.id,
                step: step,
                status: needsApproval ? .awaitingApproval : .pending
            )
        }

        return plan
    }

    /// Approve a step
    func approveStep(id: UUID) {
        if let idx = stepExecutions.firstIndex(where: { $0.id == id }) {
            stepExecutions[idx].status = .approved
        }
    }

    /// Reject a step
    func rejectStep(id: UUID) {
        if let idx = stepExecutions.firstIndex(where: { $0.id == id }) {
            stepExecutions[idx].status = .rejected
        }
    }

    /// Execute the plan (only approved/pending steps)
    func executePlan() async {
        isExecuting = true
        defer { isExecuting = false }

        for i in 0..<stepExecutions.count {
            currentStepIndex = i

            let execution = stepExecutions[i]

            // Skip rejected/awaiting steps
            if execution.status == .rejected {
                continue
            }
            if execution.status == .awaitingApproval {
                stepExecutions[i].status = .skipped
                continue
            }

            stepExecutions[i].status = .running

            let result = await commandExecutor.execute(
                capabilityId: execution.step.capabilityId,
                args: execution.step.args
            )

            stepExecutions[i].result = result
            stepExecutions[i].status = result.success ? .completed : .failed
        }
    }

    /// Reset the plan
    func clearPlan() {
        currentPlan = nil
        stepExecutions.removeAll()
        currentStepIndex = 0
    }
}
