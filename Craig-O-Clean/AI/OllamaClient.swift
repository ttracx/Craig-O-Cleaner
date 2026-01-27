// MARK: - OllamaClient.swift
// Craig-O-Clean - Local AI Client via Ollama
// Communicates with local Ollama instance for AI-assisted cleanup suggestions

import Foundation
import os.log

// MARK: - Ollama Models

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let format: String?
    let stream: Bool

    init(model: String = "llama3.2", prompt: String, format: String? = "json", stream: Bool = false) {
        self.model = model
        self.prompt = prompt
        self.format = format
        self.stream = stream
    }
}

struct OllamaResponse: Codable {
    let model: String?
    let response: String
    let done: Bool?
}

// MARK: - AI Plan Models

struct AIPlan: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let steps: [AIStep]
    let createdAt: Date

    init(id: UUID = UUID(), title: String, description: String, steps: [AIStep], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.steps = steps
        self.createdAt = createdAt
    }
}

struct AIStep: Codable, Identifiable {
    let id: UUID
    let capabilityId: String
    let reason: String
    let args: [String: String]
    let requiresApproval: Bool

    init(id: UUID = UUID(), capabilityId: String, reason: String, args: [String: String] = [:], requiresApproval: Bool = false) {
        self.id = id
        self.capabilityId = capabilityId
        self.reason = reason
        self.args = args
        self.requiresApproval = requiresApproval
    }
}

// MARK: - Ollama Client

@MainActor
final class OllamaClient: ObservableObject {

    @Published private(set) var isAvailable = false
    @Published private(set) var isProcessing = false
    @Published private(set) var lastPlan: AIPlan?
    @Published private(set) var errorMessage: String?

    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "OllamaClient")
    private let baseURL: URL
    private let catalogStore: CatalogStore

    init(baseURL: URL = URL(string: "http://localhost:11434")!, catalogStore: CatalogStore) {
        self.baseURL = baseURL
        self.catalogStore = catalogStore
    }

    // MARK: - Health Check

    func checkAvailability() async {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            isAvailable = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            isAvailable = false
        }
    }

    // MARK: - Plan Generation

    func generatePlan(systemContext: String) async -> AIPlan? {
        guard isAvailable else {
            errorMessage = "Ollama is not running. Start it with: ollama serve"
            return nil
        }

        isProcessing = true
        defer { isProcessing = false }

        let capabilityList = catalogStore.capabilities.map { cap in
            "- \(cap.id): \(cap.title) (\(cap.category.rawValue), risk: \(cap.riskClass.rawValue), privilege: \(cap.requiredPrivileges.rawValue))"
        }.joined(separator: "\n")

        let prompt = """
        You are a macOS system optimization assistant. Based on the following system context, suggest a cleanup plan.

        SYSTEM CONTEXT:
        \(systemContext)

        AVAILABLE CAPABILITIES (you can ONLY use these IDs):
        \(capabilityList)

        Respond with a JSON object matching this schema:
        {
          "title": "string - plan title",
          "description": "string - brief explanation",
          "steps": [
            {
              "capabilityId": "string - must be from the list above",
              "reason": "string - why this step",
              "args": {},
              "requiresApproval": true/false
            }
          ]
        }

        Rules:
        - Only use capability IDs from the list above
        - Mark any destructive or elevated step with requiresApproval: true
        - Put safe diagnostics first
        - Keep the plan focused (max 8 steps)
        """

        let ollamaReq = OllamaRequest(prompt: prompt)

        do {
            let url = baseURL.appendingPathComponent("api/generate")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60
            request.httpBody = try JSONEncoder().encode(ollamaReq)

            let (data, _) = try await URLSession.shared.data(for: request)
            let ollamaResp = try JSONDecoder().decode(OllamaResponse.self, from: data)

            // Parse the JSON response
            guard let jsonData = ollamaResp.response.data(using: .utf8) else {
                errorMessage = "Invalid response from AI"
                return nil
            }

            let planData = try JSONDecoder().decode(RawAIPlan.self, from: jsonData)

            // Validate: all capability IDs must be in the catalog
            let validSteps = planData.steps.compactMap { step -> AIStep? in
                guard catalogStore.isAllowed(step.capabilityId) else {
                    logger.warning("AI suggested unknown capability: \(step.capabilityId) — rejected")
                    return nil
                }

                // Force approval for elevated/destructive
                let cap = catalogStore.capability(byId: step.capabilityId)
                let needsApproval = step.requiresApproval ||
                    cap?.requiredPrivileges == .elevated ||
                    cap?.riskClass == .destructive

                return AIStep(
                    capabilityId: step.capabilityId,
                    reason: step.reason,
                    args: step.args ?? [:],
                    requiresApproval: needsApproval
                )
            }

            let plan = AIPlan(
                title: planData.title,
                description: planData.description,
                steps: validSteps
            )

            lastPlan = plan
            return plan

        } catch {
            errorMessage = "AI plan generation failed: \(error.localizedDescription)"
            logger.error("Ollama request failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Raw Plan for JSON parsing

private struct RawAIPlan: Codable {
    let title: String
    let description: String
    let steps: [RawAIStep]
}

private struct RawAIStep: Codable {
    let capabilityId: String
    let reason: String
    let args: [String: String]?
    let requiresApproval: Bool
}
