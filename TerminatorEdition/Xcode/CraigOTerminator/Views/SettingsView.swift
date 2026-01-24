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
        .frame(width: 500, height: 400)
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

            if ollamaEnabled {
                Section {
                    TextField("Host", text: $ollamaHost)
                    TextField("Port", value: $ollamaPort, format: .number)
                    TextField("Model", text: $ollamaModel)

                    HStack {
                        Button("Test Connection") {
                            Task { await testConnection() }
                        }
                        .disabled(isTestingConnection)

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
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() async {
        isTestingConnection = true
        connectionStatus = .unknown

        let executor = CommandExecutor.shared
        if let result = try? await executor.execute("curl -s http://\(ollamaHost):\(ollamaPort)/api/tags") {
            connectionStatus = result.output.contains("models") ? .connected : .failed
        } else {
            connectionStatus = .failed
        }

        isTestingConnection = false
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
