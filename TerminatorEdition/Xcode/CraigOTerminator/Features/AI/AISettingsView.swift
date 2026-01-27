//
//  AISettingsView.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import SwiftUI

/// Settings view for AI features configuration
struct AISettingsView: View {

    // MARK: - Properties

    @Binding var selectedModel: String
    let ollamaClient: OllamaClient

    @Environment(\.dismiss) private var dismiss
    @State private var serverURL: String = "http://localhost:11434"
    @State private var isLoadingModels: Bool = false
    @State private var showingModelPull: Bool = false
    @State private var modelToPull: String = ""
    @State private var pullProgress: Double = 0.0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Connection
                    connectionSection

                    Divider()

                    // Model Selection
                    modelSelectionSection

                    Divider()

                    // Privacy Notice
                    privacySection

                    Divider()

                    // Installation Help
                    installationSection
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadAvailableModels()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("AI Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

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

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connection", systemImage: "network")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(ollamaClient.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)

                    Text(ollamaClient.isConnected ? "Connected to Ollama" : "Ollama not running")
                        .font(.subheadline)

                    Spacer()

                    if ollamaClient.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Server URL (currently fixed, could be made configurable)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(serverURL)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Model Selection Section

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Model Selection", systemImage: "cpu")
                    .font(.headline)

                Spacer()

                Button {
                    loadAvailableModels()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(isLoadingModels)
            }

            if isLoadingModels {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if ollamaClient.availableModels.isEmpty {
                VStack(spacing: 12) {
                    Text("No models installed")
                        .foregroundStyle(.secondary)

                    Button("Pull a Model") {
                        showingModelPull = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(ollamaClient.availableModels) { model in
                        ModelRow(
                            model: model,
                            isSelected: selectedModel == model.name,
                            onSelect: {
                                selectedModel = model.name
                            }
                        )
                    }
                }

                Button("Pull Another Model") {
                    showingModelPull = true
                }
                .buttonStyle(.link)
            }
        }
        .sheet(isPresented: $showingModelPull) {
            ModelPullSheet(
                modelName: $modelToPull,
                progress: $pullProgress,
                ollamaClient: ollamaClient,
                onComplete: {
                    showingModelPull = false
                    loadAvailableModels()
                }
            )
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Privacy", systemImage: "lock.shield")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                PrivacyPointView(
                    icon: "checkmark.circle.fill",
                    text: "All AI processing happens locally on your Mac",
                    color: .green
                )

                PrivacyPointView(
                    icon: "checkmark.circle.fill",
                    text: "No data is sent to external servers",
                    color: .green
                )

                PrivacyPointView(
                    icon: "checkmark.circle.fill",
                    text: "Works completely offline",
                    color: .green
                )

                PrivacyPointView(
                    icon: "checkmark.circle.fill",
                    text: "Free to use, no API keys required",
                    color: .green
                )
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Installation Section

    private var installationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Installation Help", systemImage: "questionmark.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                InstallStepView(
                    number: 1,
                    title: "Install Ollama",
                    description: "Download from ollama.com and run the installer"
                )

                InstallStepView(
                    number: 2,
                    title: "Start Ollama",
                    description: "Run 'ollama serve' in Terminal or use the menu bar app"
                )

                InstallStepView(
                    number: 3,
                    title: "Pull a Model",
                    description: "Run 'ollama pull llama3.2' to download the recommended model"
                )

                Button("Open Ollama Website") {
                    if let url = URL(string: "https://ollama.com/download") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Actions

    private func loadAvailableModels() {
        guard !isLoadingModels else { return }

        isLoadingModels = true

        Task {
            do {
                try await ollamaClient.listModels()
            } catch {
                print("Failed to load models: \(error)")
            }
            isLoadingModels = false
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: OllamaModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)

                    if let size = model.sizeFormatted {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Privacy Point View

struct PrivacyPointView: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(text)
                .font(.callout)

            Spacer()
        }
    }
}

// MARK: - Install Step View

struct InstallStepView: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Model Pull Sheet

struct ModelPullSheet: View {
    @Binding var modelName: String
    @Binding var progress: Double
    let ollamaClient: OllamaClient
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPulling: Bool = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Pull Model")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Model Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g., llama3.2, mistral, qwen2.5", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isPulling)
            }

            if isPulling {
                VStack(spacing: 8) {
                    ProgressView(value: progress)

                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = error {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Button(isPulling ? "Pulling..." : "Pull") {
                    pullModel()
                }
                .disabled(modelName.isEmpty || isPulling)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func pullModel() {
        isPulling = true
        error = nil

        Task {
            do {
                try await ollamaClient.pullModel(modelName) { newProgress in
                    progress = newProgress
                }
                onComplete()
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isPulling = false
            }
        }
    }
}
