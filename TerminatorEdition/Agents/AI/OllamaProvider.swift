import Foundation

// MARK: - Ollama AI Provider
/// Integration with local Ollama AI models for intelligent agent orchestration
/// Supports Claude Code integration and autonomous decision making

public final class OllamaProvider: AIProvider, @unchecked Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let host: String
        public let port: Int
        public let model: String
        public let timeout: TimeInterval
        public let maxTokens: Int
        public let temperature: Double

        public var baseURL: String {
            "http://\(host):\(port)"
        }

        public static let `default` = Configuration(
            host: "localhost",
            port: 11434,
            model: "llama3.2",
            timeout: 60,
            maxTokens: 2048,
            temperature: 0.7
        )

        public init(
            host: String = "localhost",
            port: Int = 11434,
            model: String = "llama3.2",
            timeout: TimeInterval = 60,
            maxTokens: Int = 2048,
            temperature: Double = 0.7
        ) {
            self.host = host
            self.port = port
            self.model = model
            self.timeout = timeout
            self.maxTokens = maxTokens
            self.temperature = temperature
        }
    }

    // MARK: - Types

    public struct GenerateRequest: Codable {
        let model: String
        let prompt: String
        let stream: Bool
        let options: Options?

        struct Options: Codable {
            let temperature: Double?
            let num_predict: Int?
        }
    }

    public struct GenerateResponse: Codable {
        let model: String
        let response: String
        let done: Bool
        let context: [Int]?
        let total_duration: Int?
        let load_duration: Int?
        let prompt_eval_count: Int?
        let eval_count: Int?
    }

    public struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let options: Options?

        struct Message: Codable {
            let role: String
            let content: String
        }

        struct Options: Codable {
            let temperature: Double?
            let num_predict: Int?
        }
    }

    public struct ChatResponse: Codable {
        let model: String
        let message: Message
        let done: Bool

        struct Message: Codable {
            let role: String
            let content: String
        }
    }

    public struct ModelListResponse: Codable {
        let models: [ModelInfo]

        struct ModelInfo: Codable {
            let name: String
            let modified_at: String
            let size: Int
        }
    }

    // MARK: - Properties

    public let configuration: Configuration
    private let session: URLSession

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - AI Provider Protocol

    /// Complete a prompt
    public func complete(prompt: String) async throws -> String {
        let request = GenerateRequest(
            model: configuration.model,
            prompt: prompt,
            stream: false,
            options: .init(
                temperature: configuration.temperature,
                num_predict: configuration.maxTokens
            )
        )

        let response: GenerateResponse = try await sendRequest(
            endpoint: "/api/generate",
            body: request
        )

        return response.response
    }

    /// Chat with conversation history
    public func chat(messages: [AIMessage]) async throws -> String {
        let request = ChatRequest(
            model: configuration.model,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            stream: false,
            options: .init(
                temperature: configuration.temperature,
                num_predict: configuration.maxTokens
            )
        )

        let response: ChatResponse = try await sendRequest(
            endpoint: "/api/chat",
            body: request
        )

        return response.message.content
    }

    // MARK: - Additional Methods

    /// Check if Ollama is running
    public func isAvailable() async -> Bool {
        do {
            let _ = try await listModels()
            return true
        } catch {
            return false
        }
    }

    /// List available models
    public func listModels() async throws -> [String] {
        let response: ModelListResponse = try await sendRequest(
            endpoint: "/api/tags",
            method: "GET"
        )

        return response.models.map { $0.name }
    }

    /// Pull a model
    public func pullModel(_ model: String) async throws {
        struct PullRequest: Codable {
            let name: String
        }

        let _: [String: String] = try await sendRequest(
            endpoint: "/api/pull",
            body: PullRequest(name: model)
        )
    }

    // MARK: - System Management Prompts

    /// Get recommendation for system optimization
    public func getOptimizationRecommendation(
        cpuUsage: Double,
        memoryUsage: Double,
        diskUsage: Double,
        topProcesses: [(name: String, cpu: Double, memory: Double)]
    ) async throws -> String {

        let processInfo = topProcesses.map { "\($0.name): CPU \($0.cpu)%, Memory \($0.memory)MB" }
            .joined(separator: "\n")

        let prompt = """
        You are an AI assistant helping optimize a macOS system. Analyze the following system state and provide specific, actionable recommendations:

        System Metrics:
        - CPU Usage: \(String(format: "%.1f", cpuUsage))%
        - Memory Usage: \(String(format: "%.1f", memoryUsage))%
        - Disk Usage: \(String(format: "%.1f", diskUsage))%

        Top Resource-Consuming Processes:
        \(processInfo)

        Based on this data, provide:
        1. A brief assessment of system health
        2. Specific processes that could be terminated to free resources
        3. Recommended cleanup actions
        4. Priority order for actions

        Keep your response concise and actionable.
        """

        return try await complete(prompt: prompt)
    }

    /// Analyze task and suggest agent assignment
    public func analyzeTaskForAgentAssignment(
        task: AgentTask,
        availableAgents: [(name: String, skills: [String], status: String)]
    ) async throws -> String {

        let agentInfo = availableAgents.map { agent in
            "- \(agent.name): Skills: \(agent.skills.joined(separator: ", ")), Status: \(agent.status)"
        }.joined(separator: "\n")

        let prompt = """
        You are an AI orchestrator for a macOS system management application. Determine which agent should handle the following task:

        Task: \(task.description)
        Type: \(task.type.rawValue)
        Priority: \(task.priority)

        Available Agents:
        \(agentInfo)

        Respond with ONLY the name of the most suitable agent. No explanation needed.
        """

        return try await complete(prompt: prompt)
    }

    /// Generate cleanup plan
    public func generateCleanupPlan(
        memoryPressure: String,
        diskFreePercent: Double,
        browserTabCount: Int,
        runningProcessCount: Int
    ) async throws -> String {

        let prompt = """
        You are an AI assistant for macOS system cleanup. Create a cleanup plan based on:

        Current State:
        - Memory Pressure: \(memoryPressure)
        - Disk Free: \(String(format: "%.1f", diskFreePercent))%
        - Browser Tabs: \(browserTabCount)
        - Running Processes: \(runningProcessCount)

        Create a prioritized cleanup plan with specific actions. Format as a numbered list.
        Focus on actions that will have the most impact with least disruption.
        """

        return try await complete(prompt: prompt)
    }

    // MARK: - Private Methods

    private func sendRequest<T: Codable, R: Codable>(
        endpoint: String,
        method: String = "POST",
        body: T
    ) async throws -> R {
        guard let url = URL(string: "\(configuration.baseURL)\(endpoint)") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(R.self, from: data)
    }

    private func sendRequest<R: Codable>(
        endpoint: String,
        method: String = "GET"
    ) async throws -> R {
        guard let url = URL(string: "\(configuration.baseURL)\(endpoint)") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(R.self, from: data)
    }
}

// MARK: - Errors

public enum OllamaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case notAvailable
    case modelNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama URL"
        case .invalidResponse: return "Invalid response from Ollama"
        case .httpError(let code): return "HTTP error: \(code)"
        case .notAvailable: return "Ollama is not available. Make sure it's running."
        case .modelNotFound(let model): return "Model not found: \(model)"
        }
    }
}

// MARK: - System Prompts

public enum SystemPrompts {

    public static let orchestratorSystem = """
    You are an AI orchestrator for Craig-O-Clean, a macOS system management application.
    Your role is to:
    1. Analyze system state and make decisions about cleanup and optimization
    2. Assign tasks to appropriate specialist agents
    3. Coordinate multi-agent workflows
    4. Provide recommendations for system health

    Available Agents:
    - CleanupAgent: Memory purging, cache cleaning, disk cleanup
    - DiagnosticsAgent: System health monitoring and analysis
    - BrowserAgent: Browser tab and cache management
    - ProcessAgent: Process monitoring and termination

    Always prioritize system stability and user data safety.
    """

    public static let cleanupAdvisor = """
    You are a cleanup advisor for macOS. Analyze system metrics and recommend specific cleanup actions.
    Focus on:
    1. Memory optimization
    2. Cache cleanup (user, browser, developer)
    3. Temporary file removal
    4. Browser resource management

    Provide concise, actionable recommendations.
    """

    public static let processAnalyzer = """
    You are a process analyzer for macOS. Identify resource-heavy processes and recommend actions.
    Consider:
    1. CPU usage patterns
    2. Memory consumption
    3. Process criticality (system vs user)
    4. Impact of termination

    Never recommend terminating critical system processes.
    """
}
