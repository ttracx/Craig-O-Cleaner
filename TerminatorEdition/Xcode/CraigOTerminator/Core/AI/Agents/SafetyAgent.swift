//
//  SafetyAgent.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import Foundation

/// AI agent that validates workflow safety and identifies risks
final class SafetyAgent {

    // MARK: - Properties

    private let ollamaClient: OllamaClient
    private let capabilityCatalog: CapabilityCatalog
    private let model: String

    // MARK: - Initialization

    init(
        ollamaClient: OllamaClient,
        capabilityCatalog: CapabilityCatalog,
        model: String = "llama3.2"
    ) {
        self.ollamaClient = ollamaClient
        self.capabilityCatalog = capabilityCatalog
        self.model = model
    }

    // MARK: - System Prompt

    private var systemPrompt: String {
        """
        You are a safety validator for system maintenance workflows on macOS. Review proposed workflows and identify risks.

        RISK CATEGORIES:
        - SAFE: Read-only operations, no data modification, no system changes
        - MODERATE: Writes temporary data, restarts services, closes applications (recoverable)
        - DESTRUCTIVE: Permanent data loss, file deletion, cannot be undone

        EVALUATION CRITERIA:
        1. Check if operations are reversible
        2. Identify potential data loss
        3. Evaluate privilege level requirements
        4. Consider impact on running applications
        5. Assess system stability risks

        Output format (JSON only):
        {
          "approved": true/false,
          "riskLevel": "safe|moderate|destructive",
          "warnings": ["...", ...],
          "suggestions": ["...", ...],
          "requiresConfirmation": true/false
        }

        Examples:

        Workflow: [{"capabilityId": "diag.mem.pressure"}, {"capabilityId": "diag.disk.free"}]
        Response:
        {
          "approved": true,
          "riskLevel": "safe",
          "warnings": [],
          "suggestions": ["These are diagnostic operations that only read system information"],
          "requiresConfirmation": false
        }

        Workflow: [{"capabilityId": "quick.restart.dock"}, {"capabilityId": "quick.restart.finder"}]
        Response:
        {
          "approved": true,
          "riskLevel": "moderate",
          "warnings": ["Restarting Dock and Finder will briefly interrupt your desktop"],
          "suggestions": ["Save any work before proceeding", "Both services will restart automatically"],
          "requiresConfirmation": true
        }

        Workflow: [{"capabilityId": "disk.trash.empty"}, {"capabilityId": "deep.cache.user"}]
        Response:
        {
          "approved": false,
          "riskLevel": "destructive",
          "warnings": [
            "Empty Trash will permanently delete all files in trash",
            "Clearing user caches may affect application performance temporarily"
          ],
          "suggestions": [
            "Review trash contents before emptying using Finder",
            "Consider running 'disk.trash.size' first to see what will be deleted",
            "Create a backup before proceeding"
          ],
          "requiresConfirmation": true
        }

        IMPORTANT:
        - Mark as approved=false ONLY if workflow includes destructive operations without analysis
        - Always require confirmation for moderate or destructive operations
        - Suggest analysis steps before destructive operations
        - Warn about privilege escalation (elevated operations require admin password)
        """
    }

    // MARK: - Safety Assessment

    /// Assesses the safety of a workflow plan
    func assessSafety(of plan: WorkflowPlan) async throws -> SafetyAssessment {
        // Quick rule-based assessment
        let quickAssessment = performQuickAssessment(plan)

        // If clearly safe, skip AI assessment
        if quickAssessment.riskLevel == .safe && quickAssessment.approved {
            return quickAssessment
        }

        // Use AI for nuanced assessment
        return try await performAIAssessment(plan)
    }

    // MARK: - Quick Rule-Based Assessment

    private func performQuickAssessment(_ plan: WorkflowPlan) -> SafetyAssessment {
        var maxRisk: RiskLevel = .safe
        var warnings: [String] = []
        var suggestions: [String] = []
        var requiresElevation = false

        for step in plan.workflow {
            guard let capability = capabilityCatalog.capability(id: step.capabilityId) else {
                continue
            }

            // Track maximum risk level
            let risk = mapRiskClass(capability.riskClass)
            if risk.priority > maxRisk.priority {
                maxRisk = risk
            }

            // Check privilege requirements
            if capability.privilegeLevel == PrivilegeLevel.elevated {
                requiresElevation = true
                warnings.append("'\(capability.title)' requires administrator privileges")
            }

            // Add specific warnings for destructive operations
            if capability.riskClass == .destructive {
                warnings.append("⚠️ '\(capability.title)' - \(capability.description)")
                if let rollback = capability.rollbackNotes {
                    suggestions.append("Note: \(rollback)")
                }
            }
        }

        // Add elevation warning
        if requiresElevation {
            suggestions.append("You will be prompted for your administrator password")
        }

        // Determine approval
        let approved = maxRisk != .destructive || hasAnalysisSteps(plan)

        return SafetyAssessment(
            approved: approved,
            riskLevel: maxRisk,
            warnings: warnings,
            suggestions: suggestions,
            requiresConfirmation: maxRisk != .safe
        )
    }

    private func hasAnalysisSteps(_ plan: WorkflowPlan) -> Bool {
        // Check if workflow includes diagnostic steps before destructive ones
        let diagnosticSteps = plan.workflow.filter { step in
            step.capabilityId.hasPrefix("diag.")
        }
        return !diagnosticSteps.isEmpty
    }

    // MARK: - AI-Based Assessment

    private func performAIAssessment(_ plan: WorkflowPlan) async throws -> SafetyAssessment {
        // Build workflow context
        let workflowContext = buildWorkflowContext(plan)

        let prompt = """
        Assess the safety of this workflow:

        \(workflowContext)

        Provide a safety assessment in JSON format.
        """

        // Generate assessment using Ollama
        let response = try await ollamaClient.generate(
            model: model,
            prompt: prompt,
            system: systemPrompt,
            temperature: 0.2, // Low temperature for consistent safety assessment
            stream: false
        )

        // Parse JSON response
        return try parseAssessment(from: response)
    }

    private func buildWorkflowContext(_ plan: WorkflowPlan) -> String {
        var context = "Workflow: \(plan.summary)\n\nSteps:\n"

        for (index, step) in plan.workflow.enumerated() {
            if let capability = capabilityCatalog.capability(id: step.capabilityId) {
                context += """
                \(index + 1). [\(step.capabilityId)] \(capability.title)
                   Description: \(capability.description)
                   Risk: \(capability.riskClass.rawValue)
                   Privilege: \(capability.privilegeLevel.rawValue)
                   Reason: \(step.reason)

                """
            }
        }

        return context
    }

    private func parseAssessment(from response: String) throws -> SafetyAssessment {
        // Clean response
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown formatting
        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = cleanedResponse
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleanedResponse.hasPrefix("```") {
            cleanedResponse = cleanedResponse
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find JSON object
        guard let jsonStart = cleanedResponse.firstIndex(of: "{"),
              let jsonEnd = cleanedResponse.lastIndex(of: "}") else {
            throw SafetyError.invalidResponse
        }

        let jsonString = String(cleanedResponse[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw SafetyError.invalidResponse
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(SafetyAssessment.self, from: jsonData)
        } catch {
            print("Safety Assessment Decoding Error: \(error)")
            throw SafetyError.invalidResponse
        }
    }

    // MARK: - Helper Methods

    private func mapRiskClass(_ riskClass: RiskClass) -> RiskLevel {
        switch riskClass {
        case .safe:
            return .safe
        case .moderate:
            return .moderate
        case .destructive:
            return .destructive
        }
    }
}

// MARK: - Models

struct SafetyAssessment: Codable {
    let approved: Bool
    let riskLevel: RiskLevel
    let warnings: [String]
    let suggestions: [String]
    let requiresConfirmation: Bool
}

enum RiskLevel: String, Codable, Comparable {
    case safe
    case moderate
    case destructive

    var priority: Int {
        switch self {
        case .safe: return 0
        case .moderate: return 1
        case .destructive: return 2
        }
    }

    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "safe": self = .safe
        case "moderate": self = .moderate
        case "destructive": self = .destructive
        default: return nil
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - Errors

enum SafetyError: LocalizedError {
    case invalidResponse
    case assessmentFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Failed to parse safety assessment"
        case .assessmentFailed:
            return "Safety assessment could not be completed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidResponse:
            return "Using rule-based safety assessment instead"
        case .assessmentFailed:
            return "Workflow will require manual confirmation"
        }
    }
}
