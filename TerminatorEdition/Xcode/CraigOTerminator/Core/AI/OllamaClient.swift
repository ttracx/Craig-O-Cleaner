//
//  OllamaClient.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import Foundation
import Observation

/// Client for communicating with local Ollama server
@Observable
final class OllamaClient {

    // MARK: - Observable State

    var isConnected: Bool = false
    var availableModels: [OllamaModel] = []
    var isCheckingConnection: Bool = false

    // MARK: - Configuration

    private let baseURL: URL
    private let urlSession: URLSession
    private var connectionCheckTask: Task<Void, Never>?

    // MARK: - Constants

    private enum Endpoint {
        static let generate = "/api/generate"
        static let tags = "/api/tags"
        static let pull = "/api/pull"
    }

    private enum Constants {
        static let requestTimeout: TimeInterval = 120
        static let connectionCheckInterval: TimeInterval = 30
        static let defaultTemperature: Double = 0.7
    }

    // MARK: - Initialization

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.requestTimeout
        config.timeoutIntervalForResource = Constants.requestTimeout
        self.urlSession = URLSession(configuration: config)

        // Start connection monitoring
        startConnectionMonitoring()
    }

    deinit {
        connectionCheckTask?.cancel()
    }

    // MARK: - Connection Management

    /// Checks if Ollama server is running
    func checkServerStatus() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent(Endpoint.tags)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5 // Quick check

            let (_, response) = try await urlSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    /// Starts periodic connection monitoring
    private func startConnectionMonitoring() {
        connectionCheckTask = Task {
            while !Task.isCancelled {
                let status = await checkServerStatus()
                await MainActor.run {
                    self.isConnected = status
                }

                // Refresh model list if connected
                if status && availableModels.isEmpty {
                    try? await listModels()
                }

                try? await Task.sleep(for: .seconds(Constants.connectionCheckInterval))
            }
        }
    }

    // MARK: - Model Management

    /// Lists available models from Ollama
    func listModels() async throws -> [OllamaModel] {
        let url = baseURL.appendingPathComponent(Endpoint.tags)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.serverError(statusCode: httpResponse.statusCode)
        }

        let tagsResponse = try JSONDecoder().decode(TagsResponse.self, from: data)
        let models = tagsResponse.models.map { model in
            OllamaModel(
                name: model.name,
                size: model.size,
                modifiedAt: model.modified_at
            )
        }

        await MainActor.run {
            self.availableModels = models
        }

        return models
    }

    /// Pulls a model from Ollama registry
    func pullModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {
        let url = baseURL.appendingPathComponent(Endpoint.pull)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = PullRequest(name: name, stream: true)
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.serverError(statusCode: httpResponse.statusCode)
        }

        // Stream progress updates
        for try await line in asyncBytes.lines {
            if let data = line.data(using: .utf8),
               let progress = try? JSONDecoder().decode(PullProgress.self, from: data) {
                if let total = progress.total, total > 0 {
                    let percentage = Double(progress.completed ?? 0) / Double(total)
                    onProgress(percentage)
                }
            }
        }

        onProgress(1.0) // Complete
    }

    // MARK: - Text Generation

    /// Generates text completion using Ollama
    func generate(
        model: String,
        prompt: String,
        system: String? = nil,
        temperature: Double = Constants.defaultTemperature,
        stream: Bool = false
    ) async throws -> String {
        let url = baseURL.appendingPathComponent(Endpoint.generate)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = GenerateRequest(
            model: model,
            prompt: prompt,
            system: system,
            temperature: temperature,
            stream: stream
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        if stream {
            return try await generateStreaming(request: request)
        } else {
            return try await generateNonStreaming(request: request)
        }
    }

    /// Non-streaming generation
    private func generateNonStreaming(request: URLRequest) async throws -> String {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw OllamaError.modelNotFound
            }
            throw OllamaError.serverError(statusCode: httpResponse.statusCode)
        }

        let generateResponse = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return generateResponse.response
    }

    /// Streaming generation
    private func generateStreaming(request: URLRequest) async throws -> String {
        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw OllamaError.modelNotFound
            }
            throw OllamaError.serverError(statusCode: httpResponse.statusCode)
        }

        var fullResponse = ""

        for try await line in asyncBytes.lines {
            if let data = line.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(GenerateResponse.self, from: data) {
                fullResponse += chunk.response

                if chunk.done {
                    break
                }
            }
        }

        return fullResponse
    }

    /// Generates text with streaming callback for real-time updates
    func generateWithCallback(
        model: String,
        prompt: String,
        system: String? = nil,
        temperature: Double = Constants.defaultTemperature,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        let url = baseURL.appendingPathComponent(Endpoint.generate)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = GenerateRequest(
            model: model,
            prompt: prompt,
            system: system,
            temperature: temperature,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw OllamaError.modelNotFound
            }
            throw OllamaError.serverError(statusCode: httpResponse.statusCode)
        }

        var fullResponse = ""

        for try await line in asyncBytes.lines {
            if let data = line.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(GenerateResponse.self, from: data) {
                fullResponse += chunk.response
                onChunk(chunk.response)

                if chunk.done {
                    break
                }
            }
        }

        return fullResponse
    }
}

// MARK: - Models

struct OllamaModel: Codable, Identifiable {
    let name: String
    let size: Int64?
    let modifiedAt: String?

    var id: String { name }

    var displayName: String {
        name.split(separator: ":").first.map(String.init) ?? name
    }

    var sizeFormatted: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Request/Response Models

private struct GenerateRequest: Codable {
    let model: String
    let prompt: String
    let system: String?
    let temperature: Double
    let stream: Bool
}

private struct GenerateResponse: Codable {
    let response: String
    let done: Bool
}

private struct TagsResponse: Codable {
    let models: [ModelInfo]

    struct ModelInfo: Codable {
        let name: String
        let size: Int64
        let modified_at: String
    }
}

private struct PullRequest: Codable {
    let name: String
    let stream: Bool
}

private struct PullProgress: Codable {
    let status: String
    let completed: Int64?
    let total: Int64?
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case serverNotRunning
    case invalidResponse
    case serverError(statusCode: Int)
    case modelNotFound
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Ollama server is not running. Please start Ollama and try again."
        case .invalidResponse:
            return "Invalid response from Ollama server"
        case .serverError(let statusCode):
            return "Server error: HTTP \(statusCode)"
        case .modelNotFound:
            return "Model not found. Please pull the model first."
        case .decodingError:
            return "Failed to decode server response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .serverNotRunning:
            return "Install Ollama from ollama.com and run 'ollama serve' in Terminal"
        case .modelNotFound:
            return "Pull the model using 'ollama pull <model-name>' in Terminal"
        case .serverError:
            return "Check Ollama server logs for details"
        case .networkError:
            return "Check your network connection and firewall settings"
        default:
            return nil
        }
    }
}
