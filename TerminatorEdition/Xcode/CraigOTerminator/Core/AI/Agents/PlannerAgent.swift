//
//  PlannerAgent.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import Foundation

/// AI agent that plans workflows from natural language queries
final class PlannerAgent {

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
        You are a system maintenance planner for macOS. Given a user request and a catalog of available capabilities, create a workflow plan in JSON format.

        RULES:
        1. Only use capability IDs from the provided catalog
        2. Order operations logically (e.g., analysis before cleanup)
        3. Avoid destructive operations unless explicitly requested
        4. Return JSON only, no explanation or markdown formatting
        5. Use the exact capability IDs from the catalog
        6. Provide a reason for each step
        7. Limit workflows to 10 steps maximum

        Output format:
        {
          "workflow": [
            {
              "capabilityId": "exact.capability.id",
              "arguments": {},
              "reason": "Brief explanation"
            }
          ],
          "summary": "Brief description of what this workflow does"
        }

        Available capability categories:
        - diagnostics: System information and analysis
        - quickClean: Safe, non-destructive cleanup
        - deepClean: More aggressive cleanup (requires confirmation)
        - browsers: Browser tab management and cleanup
        - disk: Disk space analysis and management
        - memory: Memory management
        - devTools: Developer tool cleanup (Xcode, npm, etc.)
        - system: System maintenance and repairs

        Example workflows:

        User: "Check my system status"
        Response:
        {
          "workflow": [
            {"capabilityId": "diag.mem.pressure", "arguments": {}, "reason": "Check memory pressure"},
            {"capabilityId": "diag.disk.free", "arguments": {}, "reason": "Check available disk space"},
            {"capabilityId": "diag.cpu.top", "arguments": {}, "reason": "Identify CPU-intensive processes"}
          ],
          "summary": "Analyzes system memory, disk, and CPU usage"
        }

        User: "Clean up my Mac"
        Response:
        {
          "workflow": [
            {"capabilityId": "diag.disk.free", "arguments": {}, "reason": "Check available space"},
            {"capabilityId": "quick.temp.user", "arguments": {}, "reason": "Clear temporary files"},
            {"capabilityId": "quick.ql.reset", "arguments": {}, "reason": "Reset Quick Look cache"},
            {"capabilityId": "disk.trash.size", "arguments": {}, "reason": "Check trash size"}
          ],
          "summary": "Performs safe cleanup of temporary files and caches"
        }

        User: "Prepare for presentation"
        Response:
        {
          "workflow": [
            {"capabilityId": "quick.mem.purge", "arguments": {}, "reason": "Free up RAM"},
            {"capabilityId": "browser.heavy.list", "arguments": {}, "reason": "Identify memory-heavy browser tabs"},
            {"capabilityId": "quick.restart.notifications", "arguments": {}, "reason": "Restart notifications to prevent interruptions"}
          ],
          "summary": "Optimizes performance and reduces distractions for presentations"
        }

        IMPORTANT:
        - Never suggest arbitrary commands or shell scripts
        - Only use capabilities from the provided catalog
        - If the request is unclear, suggest diagnostic capabilities first
        - If the request is destructive (delete, empty trash), include analysis steps first
        """
    }

    // MARK: - Planning

    /// Generates a workflow plan from a natural language query
    func planWorkflow(from query: String) async throws -> WorkflowPlan {
        // Build catalog context
        let catalogContext = buildCatalogContext()

        // Build full prompt
        let fullPrompt = """
        User request: "\(query)"

        \(catalogContext)

        Generate a workflow plan in JSON format.
        """

        // Generate plan using Ollama
        let response = try await ollamaClient.generate(
            model: model,
            prompt: fullPrompt,
            system: systemPrompt,
            temperature: 0.3, // Low temperature for more consistent JSON output
            stream: false
        )

        // Parse JSON response
        let plan = try parseWorkflowPlan(from: response)

        // Validate all capability IDs exist
        try validateWorkflowPlan(plan)

        return plan
    }

    /// Generates a workflow plan with streaming updates
    func planWorkflowWithStreaming(
        from query: String,
        onUpdate: @escaping (String) -> Void
    ) async throws -> WorkflowPlan {
        let catalogContext = buildCatalogContext()

        let fullPrompt = """
        User request: "\(query)"

        \(catalogContext)

        Generate a workflow plan in JSON format.
        """

        var accumulatedResponse = ""

        let response = try await ollamaClient.generateWithCallback(
            model: model,
            prompt: fullPrompt,
            system: systemPrompt,
            temperature: 0.3
        ) { chunk in
            accumulatedResponse += chunk
            onUpdate(accumulatedResponse)
        }

        let plan = try parseWorkflowPlan(from: response)
        try validateWorkflowPlan(plan)

        return plan
    }

    // MARK: - Helper Methods

    private func buildCatalogContext() -> String {
        let capabilities = capabilityCatalog.allCapabilities()

        var context = "Available capabilities:\n\n"

        // Group by category
        let grouped = Dictionary(grouping: capabilities, by: { $0.group })

        for (group, caps) in grouped.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            context += "\n[\(group.rawValue)]\n"
            for cap in caps.prefix(20) { // Limit to avoid token overflow
                let risk = cap.riskClass == .safe ? "" : " ⚠️ \(cap.riskClass.rawValue)"
                context += "- \(cap.id): \(cap.description)\(risk)\n"
            }
        }

        return context
    }

    private func parseWorkflowPlan(from response: String) throws -> WorkflowPlan {
        // Clean response (remove markdown code blocks if present)
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown JSON formatting
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
            throw PlannerError.invalidJSONResponse
        }

        let jsonString = String(cleanedResponse[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw PlannerError.invalidJSONResponse
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(WorkflowPlan.self, from: jsonData)
        } catch {
            print("JSON Decoding Error: \(error)")
            print("Response: \(jsonString)")
            throw PlannerError.invalidJSONResponse
        }
    }

    private func validateWorkflowPlan(_ plan: WorkflowPlan) throws {
        // Check workflow is not empty
        guard !plan.workflow.isEmpty else {
            throw PlannerError.emptyWorkflow
        }

        // Check workflow is not too long
        guard plan.workflow.count <= 10 else {
            throw PlannerError.workflowTooLong(count: plan.workflow.count)
        }

        // Validate all capability IDs exist
        for step in plan.workflow {
            guard capabilityCatalog.capability(id: step.capabilityId) != nil else {
                throw PlannerError.invalidCapabilityId(step.capabilityId)
            }
        }
    }
}

// MARK: - Models

struct WorkflowPlan: Codable {
    let workflow: [WorkflowStep]
    let summary: String
}

struct WorkflowStep: Codable, Identifiable {
    let capabilityId: String
    let arguments: [String: String]
    let reason: String

    var id: String { capabilityId }
}

// MARK: - Errors

enum PlannerError: LocalizedError {
    case invalidJSONResponse
    case emptyWorkflow
    case workflowTooLong(count: Int)
    case invalidCapabilityId(String)
    case modelNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidJSONResponse:
            return "Failed to parse workflow plan from AI response"
        case .emptyWorkflow:
            return "Generated workflow is empty"
        case .workflowTooLong(let count):
            return "Generated workflow is too long (\(count) steps, max 10)"
        case .invalidCapabilityId(let id):
            return "Invalid capability ID in workflow: \(id)"
        case .modelNotAvailable:
            return "AI model is not available"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidJSONResponse:
            return "Try rephrasing your request more simply"
        case .emptyWorkflow:
            return "Try providing more specific details about what you want to do"
        case .workflowTooLong:
            return "Try breaking your request into smaller tasks"
        case .invalidCapabilityId:
            return "This capability is not supported. Try a different request."
        case .modelNotAvailable:
            return "Pull the model using 'ollama pull llama3.2' in Terminal"
        }
    }
}
