import SwiftUI

struct SettingsView: View {
    @AppStorage("autonomousMode") private var autonomousMode = false
    @AppStorage("memoryThreshold") private var memoryThreshold = 85.0
    @AppStorage("diskThreshold") private var diskThreshold = 90.0
    @AppStorage("checkInterval") private var checkInterval = 300.0
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("ollamaEnabled") private var ollamaEnabled = false
    @AppStorage("ollamaHost") private var ollamaHost = "localhost"
    @AppStorage("ollamaPort") private var ollamaPort = 11434
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.2"

    var body: some View {
        TabView {
            AccountSettingsView()
            .tabItem {
                Label("Account", systemImage: "person.circle")
            }

            GeneralSettingsView(
                showMenuBarIcon: $showMenuBarIcon,
                launchAtLogin: $launchAtLogin,
                showNotifications: $showNotifications
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            AutomationSettingsView(
                autonomousMode: $autonomousMode,
                memoryThreshold: $memoryThreshold,
                diskThreshold: $diskThreshold,
                checkInterval: $checkInterval
            )
            .tabItem {
                Label("Automation", systemImage: "clock.arrow.circlepath")
            }

            AISettingsView(
                ollamaEnabled: $ollamaEnabled,
                ollamaHost: $ollamaHost,
                ollamaPort: $ollamaPort,
                ollamaModel: $ollamaModel
            )
            .tabItem {
                Label("AI", systemImage: "brain")
            }

            AdvancedSettingsView()
            .tabItem {
                Label("Advanced", systemImage: "slider.horizontal.3")
            }
        }
        .frame(width: 500, height: 500)
    }
}

struct GeneralSettingsView: View {
    @Binding var showMenuBarIcon: Bool
    @Binding var launchAtLogin: Bool
    @Binding var showNotifications: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show notifications", isOn: $showNotifications)
            } header: {
                Text("General")
            }

            Section {
                LabeledContent("Version") {
                    Text("1.0.0 (Terminator Edition)")
                }
                LabeledContent("Build") {
                    Text("2024.1")
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AutomationSettingsView: View {
    @Binding var autonomousMode: Bool
    @Binding var memoryThreshold: Double
    @Binding var diskThreshold: Double
    @Binding var checkInterval: Double

    var body: some View {
        Form {
            Section {
                Toggle("Enable autonomous mode", isOn: $autonomousMode)

                if autonomousMode {
                    Text("When enabled, Craig-O-Clean will automatically perform cleanup tasks when system resources exceed thresholds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Autonomous Mode")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Memory threshold")
                        Spacer()
                        Text("\(Int(memoryThreshold))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $memoryThreshold, in: 50...95, step: 5)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Disk threshold")
                        Spacer()
                        Text("\(Int(diskThreshold))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $diskThreshold, in: 60...95, step: 5)
                }

                Picker("Check interval", selection: $checkInterval) {
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("30 minutes").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                }
            } header: {
                Text("Thresholds")
            } footer: {
                Text("Cleanup will be triggered when memory or disk usage exceeds these thresholds.")
            }
        }
        .formStyle(.grouped)
        .padding()
        .disabled(!autonomousMode)
    }
}

struct AISettingsView: View {
    @Binding var ollamaEnabled: Bool
    @Binding var ollamaHost: String
    @Binding var ollamaPort: Int
    @Binding var ollamaModel: String
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var ollamaInstalled = false
    @State private var isCheckingOllama = true
    @State private var isInstallingOllama = false
    @State private var availableModels: [String] = []
    @State private var runningModels: [String] = []
    @State private var isLoadingModels = false
    @State private var isDownloadingModel = false
    @State private var downloadProgress: String = ""

    enum ConnectionStatus {
        case unknown, connected, failed
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Ollama AI", isOn: $ollamaEnabled)

                if ollamaEnabled {
                    Text("Ollama provides local AI-powered recommendations and intelligent task coordination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("AI Integration")
            }

            // Ollama Installation Section
            Section {
                HStack {
                    if isCheckingOllama {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking Ollama installation...")
                            .foregroundStyle(.secondary)
                    } else if ollamaInstalled {
                        Label("Ollama Installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Ollama Not Installed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if !ollamaInstalled && !isCheckingOllama {
                    Button {
                        Task { await downloadAndInstallOllama() }
                    } label: {
                        HStack {
                            if isInstallingOllama {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Installing Ollama...")
                            } else {
                                Label("Download & Install Ollama", systemImage: "arrow.down.circle")
                            }
                        }
                    }
                    .disabled(isInstallingOllama)

                    Text("This will download and install Ollama from ollama.ai")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Ollama Setup")
            }

            if ollamaEnabled && ollamaInstalled {
                Section {
                    TextField("Host", text: $ollamaHost)
                    TextField("Port", value: $ollamaPort, format: .number)

                    Picker("Model", selection: $ollamaModel) {
                        if availableModels.isEmpty {
                            Text("No models available").tag("")
                        } else {
                            ForEach(availableModels, id: \.self) { model in
                                HStack {
                                    Text(model)
                                    if runningModels.contains(model) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .tag(model)
                            }
                            // Add tag for current selection if not in available models
                            if !availableModels.contains(ollamaModel) && !ollamaModel.isEmpty {
                                Text(ollamaModel + " (not installed)").tag(ollamaModel)
                            }
                        }
                    }

                    HStack {
                        Button("Test Connection") {
                            Task { await testConnection() }
                        }
                        .disabled(isTestingConnection)

                        Button("Refresh Models") {
                            Task { await loadAvailableModels() }
                        }
                        .disabled(isLoadingModels)

                        Spacer()

                        switch connectionStatus {
                        case .unknown:
                            EmptyView()
                        case .connected:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failed:
                            Label("Failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Ollama Configuration")
                } footer: {
                    Text("Make sure Ollama is running with the specified model installed.")
                }

                // Default Model Installation
                Section {
                    if !availableModels.contains("lfm2.5-thinking") {
                        Button {
                            Task { await downloadDefaultModel() }
                        } label: {
                            HStack {
                                if isDownloadingModel {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    VStack(alignment: .leading) {
                                        Text("Downloading lfm2.5-thinking...")
                                        if !downloadProgress.isEmpty {
                                            Text(downloadProgress)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    Label("Install Default Model (lfm2.5-thinking)", systemImage: "arrow.down.circle.fill")
                                }
                            }
                        }
                        .disabled(isDownloadingModel)

                        Text("This is the recommended model for intelligent task coordination.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label("Default model installed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            if ollamaModel != "lfm2.5-thinking" {
                                Button("Set as Active") {
                                    ollamaModel = "lfm2.5-thinking"
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    if !runningModels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Running Models:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(runningModels, id: \.self) { model in
                                Text("• \(model)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Text("AI Models")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            // Run initialization in a separate task to avoid state updates during view rendering
            await Task { @MainActor in
                await checkOllamaInstallation()
                if ollamaInstalled {
                    await loadAvailableModels()
                    await checkRunningModels()
                }
            }.value
        }
    }

    @MainActor
    private func testConnection() async {
        isTestingConnection = true
        connectionStatus = .unknown

        let executor = CommandExecutor.shared
        let status: ConnectionStatus
        if let result = try? await executor.execute("curl -s http://\(ollamaHost):\(ollamaPort)/api/tags") {
            status = result.output.contains("models") ? .connected : .failed
        } else {
            status = .failed
        }

        // Update state outside of view update cycle
        Task { @MainActor in
            self.connectionStatus = status
            self.isTestingConnection = false
        }
    }

    @MainActor
    private func checkOllamaInstallation() async {
        isCheckingOllama = true

        let executor = CommandExecutor.shared
        // Check if ollama command exists
        let installed: Bool
        if let result = try? await executor.execute("which ollama") {
            installed = !result.output.isEmpty && result.isSuccess
        } else {
            installed = false
        }

        // Update state outside of view update cycle
        Task { @MainActor in
            self.ollamaInstalled = installed
            self.isCheckingOllama = false
        }
    }

    @MainActor
    private func downloadAndInstallOllama() async {
        Task { @MainActor in
            self.isInstallingOllama = true
        }

        let executor = CommandExecutor.shared

        // Download Ollama installer
        _ = try? await executor.execute("curl -fsSL https://ollama.ai/install.sh | sh")

        // Wait a moment for installation to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Verify installation
        await checkOllamaInstallation()

        if ollamaInstalled {
            // Start Ollama service
            _ = try? await executor.execute("ollama serve > /dev/null 2>&1 &")
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Load models after installation
            await loadAvailableModels()

            // Auto-install default model if not present
            if !availableModels.contains("lfm2.5-thinking") {
                await downloadDefaultModel()
            }
        }

        Task { @MainActor in
            self.isInstallingOllama = false
        }
    }

    @MainActor
    private func loadAvailableModels() async {
        isLoadingModels = true

        let executor = CommandExecutor.shared

        // First ensure Ollama is running
        _ = try? await executor.execute("pgrep -x ollama > /dev/null || ollama serve > /dev/null 2>&1 &")
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Get list of installed models
        if let result = try? await executor.execute("ollama list") {
            let lines = result.output.components(separatedBy: "\n")
            var models: Set<String> = [] // Use Set to avoid duplicates

            for line in lines {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count > 0 && !line.contains("NAME") {
                    let modelName = String(parts[0]).components(separatedBy: ":").first ?? ""
                    if !modelName.isEmpty && modelName != "NAME" {
                        models.insert(modelName)
                    }
                }
            }

            let sortedModels = models.sorted()

            // Update state outside of view update cycle
            Task { @MainActor in
                self.availableModels = sortedModels

                // If no model is selected and we have models, select the first one or lfm2.5-thinking
                if self.ollamaModel.isEmpty && !sortedModels.isEmpty {
                    if sortedModels.contains("lfm2.5-thinking") {
                        self.ollamaModel = "lfm2.5-thinking"
                    } else if let firstModel = sortedModels.first {
                        self.ollamaModel = firstModel
                    }
                }
            }
        }

        isLoadingModels = false
    }

    @MainActor
    private func checkRunningModels() async {
        let executor = CommandExecutor.shared

        // Check which models are currently running
        if let result = try? await executor.execute("ollama ps") {
            let lines = result.output.components(separatedBy: "\n")
            var running: [String] = []

            for line in lines {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count > 0 && !line.contains("NAME") {
                    let modelName = String(parts[0]).components(separatedBy: ":").first ?? ""
                    if !modelName.isEmpty && modelName != "NAME" {
                        running.append(modelName)
                    }
                }
            }

            // Update state outside of view update cycle
            Task { @MainActor in
                self.runningModels = running
            }
        }
    }

    @MainActor
    private func downloadDefaultModel() async {
        Task { @MainActor in
            self.isDownloadingModel = true
            self.downloadProgress = "Starting download..."
        }

        let executor = CommandExecutor.shared

        // Ensure Ollama is running
        _ = try? await executor.execute("pgrep -x ollama > /dev/null || ollama serve > /dev/null 2>&1 &")
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Download and run the model (this will download if not present)
        Task { @MainActor in
            self.downloadProgress = "Downloading lfm2.5-thinking model... This may take a few minutes."
        }

        // Run in background and capture output
        if let result = try? await executor.execute("ollama run lfm2.5-thinking 'Hello' || ollama pull lfm2.5-thinking", timeout: 600) {
            if result.isSuccess {
                Task { @MainActor in
                    self.downloadProgress = "Model downloaded successfully!"
                    self.ollamaModel = "lfm2.5-thinking"
                }

                // Reload available models
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await loadAvailableModels()
            } else {
                Task { @MainActor in
                    self.downloadProgress = "Download failed. Please try manually: ollama run lfm2.5-thinking"
                }
            }
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        Task { @MainActor in
            self.downloadProgress = ""
            self.isDownloadingModel = false
        }
    }
}

struct AdvancedSettingsView: View {
    @State private var showConfirmReset = false

    var body: some View {
        Form {
            Section {
                Button("Reset All Settings") {
                    showConfirmReset = true
                }
                .foregroundStyle(.red)
            } header: {
                Text("Reset")
            } footer: {
                Text("This will reset all settings to their default values.")
            }

            Section {
                Button("Clear Application Cache") {
                    Task { await clearAppCache() }
                }

                Button("View Logs") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs"))
                }
            } header: {
                Text("Maintenance")
            }

            Section {
                LabeledContent("Data Location") {
                    Text("~/Library/Application Support/CraigOTerminator")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Storage")
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Reset Settings", isPresented: $showConfirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values?")
        }
    }

    private func clearAppCache() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("rm -rf ~/Library/Caches/com.craigtracey.CraigOTerminator/* 2>/dev/null")
    }

    private func resetAllSettings() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }
}

#Preview {
    SettingsView()
}
