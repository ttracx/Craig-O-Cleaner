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
            // TODO: Fix AccountSettingsView TabContent conformance issue
            // Group {
            //     AccountSettingsView()
            // }
            // .tabItem {
            //     Label("Account", systemImage: "person.circle")
            // }

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

            LegacyAISettingsView(
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

                Picker("Check interval", selection: Binding(
                    get: {
                        // Ensure the value is valid, default to 300.0 (5 minutes) if not
                        let validValues: [Double] = [60.0, 300.0, 900.0, 1800.0, 3600.0]
                        return validValues.contains(checkInterval) ? checkInterval : 300.0
                    },
                    set: { newValue in
                        checkInterval = newValue
                    }
                )) {
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
            .disabled(!autonomousMode)
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct LegacyAISettingsView: View {
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
            // Defer initialization to avoid publishing changes during view updates
            await Task.yield()

            // Run initialization asynchronously to avoid state updates during view rendering
            await checkOllamaInstallation()

            let installed = await MainActor.run { ollamaInstalled }
            if installed {
                await loadAvailableModels()
                await checkRunningModels()
            }
        }
    }

    private func testConnection() async {
        await MainActor.run {
            isTestingConnection = true
            connectionStatus = .unknown
        }

        let task = Process()
        task.launchPath = "/usr/bin/curl"
        task.arguments = ["-s", "http://\(ollamaHost):\(ollamaPort)/api/tags"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        try? task.run()
        task.waitUntilExit()

        let status: ConnectionStatus
        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                status = output.contains("models") ? .connected : .failed
            } else {
                status = .failed
            }
        } else {
            status = .failed
        }

        await MainActor.run {
            connectionStatus = status
            isTestingConnection = false
        }
    }

    private func checkOllamaInstallation() async {
        await MainActor.run {
            isCheckingOllama = true
        }

        // Check if ollama exists at the standard installation path
        let fileManager = FileManager.default
        var installed = fileManager.fileExists(atPath: "/usr/local/bin/ollama")

        // If not found in /usr/local/bin, try using which as fallback
        if !installed {
            let task = Process()
            task.launchPath = "/usr/bin/which"
            task.arguments = ["ollama"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            try? task.run()
            task.waitUntilExit()

            installed = task.terminationStatus == 0
        }

        await MainActor.run {
            ollamaInstalled = installed
            isCheckingOllama = false
        }
    }

    private func downloadAndInstallOllama() async {
        await MainActor.run {
            isInstallingOllama = true
        }

        // Download Ollama installer
        let installTask = Process()
        installTask.launchPath = "/bin/sh"
        installTask.arguments = ["-c", "curl -fsSL https://ollama.ai/install.sh | sh"]
        installTask.standardOutput = Pipe()
        installTask.standardError = Pipe()

        try? installTask.run()
        installTask.waitUntilExit()

        // Wait a moment for installation to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Verify installation
        await checkOllamaInstallation()

        let installed = await MainActor.run { ollamaInstalled }
        if installed {
            // Start Ollama service
            let serveTask = Process()
            serveTask.launchPath = "/bin/sh"
            serveTask.arguments = ["-c", "ollama serve > /dev/null 2>&1 &"]
            serveTask.standardOutput = Pipe()
            serveTask.standardError = Pipe()

            try? serveTask.run()
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Load models after installation
            await loadAvailableModels()

            // Auto-install default model if not present
            let models = await MainActor.run { availableModels }
            if !models.contains("lfm2.5-thinking") {
                await downloadDefaultModel()
            }
        }

        await MainActor.run {
            isInstallingOllama = false
        }
    }

    private func loadAvailableModels() async {
        await MainActor.run {
            isLoadingModels = true
        }

        // First ensure Ollama is running
        let checkTask = Process()
        checkTask.launchPath = "/bin/sh"
        checkTask.arguments = ["-c", "pgrep -x ollama > /dev/null || ollama serve > /dev/null 2>&1 &"]
        checkTask.standardOutput = Pipe()
        checkTask.standardError = Pipe()

        try? checkTask.run()
        checkTask.waitUntilExit()
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Get list of installed models
        let listTask = Process()
        listTask.launchPath = "/usr/local/bin/ollama"
        listTask.arguments = ["list"]
        let pipe = Pipe()
        listTask.standardOutput = pipe
        listTask.standardError = Pipe()

        try? listTask.run()
        listTask.waitUntilExit()

        if listTask.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                var models: Set<String> = []

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

                await MainActor.run {
                    availableModels = sortedModels

                    // If no model is selected and we have models, select the first one or lfm2.5-thinking
                    if ollamaModel.isEmpty && !sortedModels.isEmpty {
                        if sortedModels.contains("lfm2.5-thinking") {
                            ollamaModel = "lfm2.5-thinking"
                        } else if let firstModel = sortedModels.first {
                            ollamaModel = firstModel
                        }
                    }
                }
            }
        }

        await MainActor.run {
            isLoadingModels = false
        }
    }

    private func checkRunningModels() async {
        // Check which models are currently running
        let task = Process()
        task.launchPath = "/usr/local/bin/ollama"
        task.arguments = ["ps"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        try? task.run()
        task.waitUntilExit()

        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
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

                await MainActor.run {
                    runningModels = running
                }
            }
        }
    }

    private func downloadDefaultModel() async {
        await MainActor.run {
            isDownloadingModel = true
            downloadProgress = "Starting download..."
        }

        // Ensure Ollama is running
        let checkTask = Process()
        checkTask.launchPath = "/bin/sh"
        checkTask.arguments = ["-c", "pgrep -x ollama > /dev/null || ollama serve > /dev/null 2>&1 &"]
        checkTask.standardOutput = Pipe()
        checkTask.standardError = Pipe()

        try? checkTask.run()
        checkTask.waitUntilExit()
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        await MainActor.run {
            downloadProgress = "Downloading lfm2.5-thinking model... This may take a few minutes."
        }

        // Download the model
        let pullTask = Process()
        pullTask.launchPath = "/usr/local/bin/ollama"
        pullTask.arguments = ["pull", "lfm2.5-thinking"]
        pullTask.standardOutput = Pipe()
        pullTask.standardError = Pipe()

        try? pullTask.run()
        pullTask.waitUntilExit()

        if pullTask.terminationStatus == 0 {
            await MainActor.run {
                downloadProgress = "Model downloaded successfully!"
                ollamaModel = "lfm2.5-thinking"
            }

            // Reload available models
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await loadAvailableModels()
        } else {
            await MainActor.run {
                downloadProgress = "Download failed. Please try manually: ollama pull lfm2.5-thinking"
            }
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            downloadProgress = ""
            isDownloadingModel = false
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
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "rm -rf ~/Library/Caches/com.vibecaas.CraigOTerminator/* 2>/dev/null"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        try? task.run()
        task.waitUntilExit()
    }

    private func resetAllSettings() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }
}

#Preview {
    SettingsView()
}
