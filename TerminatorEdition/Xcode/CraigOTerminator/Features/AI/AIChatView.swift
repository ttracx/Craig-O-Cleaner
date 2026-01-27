//
//  AIChatView.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import SwiftUI

/// Main AI chat interface for natural language system maintenance
struct AIChatView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @State private var ollamaClient: OllamaClient
    @State private var plannerAgent: PlannerAgent
    @State private var safetyAgent: SafetyAgent
    @State private var workflowExecutor: WorkflowExecutor

    // MARK: - State

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var showingWorkflowApproval: Bool = false
    @State private var pendingWorkflow: WorkflowPlan?
    @State private var pendingSafetyAssessment: SafetyAssessment?
    @State private var showingSettings: Bool = false
    @State private var showingInstallOllama: Bool = false
    @State private var selectedModel: String = "llama3.2"

    // MARK: - Initialization

    init(
        capabilityCatalog: CapabilityCatalog,
        userExecutor: UserExecutor,
        elevatedExecutor: ElevatedExecutor,
        logStore: SQLiteLogStore
    ) {
        let ollama = OllamaClient()
        let planner = PlannerAgent(
            ollamaClient: ollama,
            capabilityCatalog: capabilityCatalog
        )
        let safety = SafetyAgent(
            ollamaClient: ollama,
            capabilityCatalog: capabilityCatalog
        )
        let executor = WorkflowExecutor(
            capabilityCatalog: capabilityCatalog,
            userExecutor: userExecutor,
            elevatedExecutor: elevatedExecutor,
            logStore: logStore
        )

        _ollamaClient = State(initialValue: ollama)
        _plannerAgent = State(initialValue: planner)
        _safetyAgent = State(initialValue: safety)
        _workflowExecutor = State(initialValue: executor)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }

                        if isProcessing {
                            TypingIndicatorView()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            inputView
        }
        .frame(width: 600, height: 700)
        .sheet(isPresented: $showingWorkflowApproval) {
            if let workflow = pendingWorkflow,
               let assessment = pendingSafetyAssessment {
                WorkflowApprovalSheet(
                    workflow: workflow,
                    safetyAssessment: assessment,
                    onApprove: { executeApprovedWorkflow(workflow) },
                    onCancel: { cancelWorkflow() }
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            AISettingsView(
                selectedModel: $selectedModel,
                ollamaClient: ollamaClient
            )
        }
        .alert("Install Ollama", isPresented: $showingInstallOllama) {
            Button("Open Website") {
                if let url = URL(string: "https://ollama.com/download") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ollama is not installed or not running. Please install Ollama to use AI features.")
        }
        .onAppear {
            checkOllamaStatus()
            addWelcomeMessage()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Assistant")
                    .font(.headline)

                HStack(spacing: 8) {
                    Circle()
                        .fill(ollamaClient.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(ollamaClient.isConnected ? "Ollama Connected" : "Ollama Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 8) {
            // Examples
            if messages.isEmpty || messages.count == 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ExampleQueryButton(text: "Clean up my system") {
                            sendMessage("Clean up my system")
                        }
                        ExampleQueryButton(text: "Check system status") {
                            sendMessage("Check system status")
                        }
                        ExampleQueryButton(text: "Close heavy browser tabs") {
                            sendMessage("Close heavy browser tabs")
                        }
                        ExampleQueryButton(text: "Free up memory") {
                            sendMessage("Free up memory")
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack(spacing: 12) {
                TextField("Ask me to do something...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .lineLimit(1...5)
                    .disabled(isProcessing || !ollamaClient.isConnected)
                    .onSubmit {
                        sendMessage(inputText)
                    }

                Button {
                    sendMessage(inputText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !ollamaClient.isConnected)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions

    private func checkOllamaStatus() {
        Task {
            let isRunning = await ollamaClient.checkServerStatus()
            if !isRunning {
                showingInstallOllama = true
            }
        }
    }

    private func addWelcomeMessage() {
        let welcome = ChatMessage(
            role: .assistant,
            content: "Hi! I'm your AI system maintenance assistant. Tell me what you'd like to do and I'll create a workflow for you.\n\nI can help with:\n• System diagnostics and analysis\n• Safe cleanup operations\n• Browser tab management\n• Memory optimization\n• Developer tool cleanup\n\nAll operations stay local on your Mac - your data never leaves your device.",
            timestamp: Date()
        )
        messages.append(welcome)
    }

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(
            role: .user,
            content: trimmed,
            timestamp: Date()
        )
        messages.append(userMessage)
        inputText = ""

        // Process request
        Task {
            await processRequest(trimmed)
        }
    }

    private func processRequest(_ query: String) async {
        isProcessing = true

        do {
            // Generate workflow plan
            let plan = try await plannerAgent.planWorkflow(from: query)

            // Assess safety
            let assessment = try await safetyAgent.assessSafety(of: plan)

            // Add AI response
            let responseMessage = ChatMessage(
                role: .assistant,
                content: "I've created a workflow:\n\n**\(plan.summary)**\n\nSteps:\n" +
                    plan.workflow.enumerated().map { index, step in
                        "\(index + 1). \(step.reason)"
                    }.joined(separator: "\n"),
                timestamp: Date(),
                workflowPlan: plan
            )
            messages.append(responseMessage)

            // Show approval sheet if needed
            if assessment.requiresConfirmation || assessment.riskLevel != .safe {
                pendingWorkflow = plan
                pendingSafetyAssessment = assessment
                showingWorkflowApproval = true
            } else {
                // Auto-execute safe workflows
                await executeWorkflow(plan)
            }

        } catch {
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Sorry, I encountered an error: \(error.localizedDescription)",
                timestamp: Date()
            )
            messages.append(errorMessage)
        }

        isProcessing = false
    }

    private func executeApprovedWorkflow(_ plan: WorkflowPlan) {
        showingWorkflowApproval = false
        Task {
            await executeWorkflow(plan)
        }
    }

    private func cancelWorkflow() {
        showingWorkflowApproval = false
        pendingWorkflow = nil
        pendingSafetyAssessment = nil

        let cancelMessage = ChatMessage(
            role: .assistant,
            content: "Workflow cancelled. What else can I help you with?",
            timestamp: Date()
        )
        messages.append(cancelMessage)
    }

    private func executeWorkflow(_ plan: WorkflowPlan) async {
        // Add execution start message
        let startMessage = ChatMessage(
            role: .assistant,
            content: "Executing workflow...",
            timestamp: Date()
        )
        messages.append(startMessage)

        do {
            let result = try await workflowExecutor.execute(plan: plan) { stepResult in
                // Could update UI with step progress here
            }

            // Add result message
            let resultMessage = ChatMessage(
                role: .assistant,
                content: result.summaryText + "\n\nDetails:\n" +
                    result.results.map { step in
                        "\(step.statusIcon) \(step.step.reason)"
                    }.joined(separator: "\n"),
                timestamp: Date()
            )
            messages.append(resultMessage)

        } catch {
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Execution failed: \(error.localizedDescription)",
                timestamp: Date()
            )
            messages.append(errorMessage)
        }
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)
                    .textSelection(.enabled)

                if let workflow = message.workflowPlan {
                    WorkflowPreviewView(workflow: workflow)
                }

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 450, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Workflow Preview View

struct WorkflowPreviewView: View {
    let workflow: WorkflowPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(workflow.workflow.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(step.reason)
                        .font(.caption)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Example Query Button

struct ExampleQueryButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    var workflowPlan: WorkflowPlan?

    enum Role {
        case user
        case assistant
    }
}
