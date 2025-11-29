// MARK: - SettingsPermissionsView.swift
// ClearMind Control Center - Settings and Permissions View
// App configuration, permission management, and diagnostics

import SwiftUI

struct SettingsPermissionsView: View {
    @EnvironmentObject var systemMetrics: SystemMetricsService
    @EnvironmentObject var permissions: PermissionsService
    
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("memoryWarningThreshold") private var memoryWarningThreshold: Double = 80.0
    
    @State private var showingDiagnostics = false
    @State private var showingAbout = false
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // General Settings
                generalSettingsSection
                
                // Monitoring Settings
                monitoringSettingsSection
                
                // Permissions Section
                permissionsSection
                
                // Privacy Section
                privacySection
                
                // Diagnostics Section
                diagnosticsSection
                
                // About Section
                aboutSection
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await permissions.checkAllPermissions()
                    }
                } label: {
                    Label("Refresh Permissions", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsSheet()
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicySheet()
        }
    }
    
    // MARK: - General Settings Section
    
    private var generalSettingsSection: some View {
        SettingsSection(title: "General", icon: "gearshape") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Show in Dock",
                    description: "Display app icon in the Dock when main window is open",
                    isOn: $showInDock
                )
                
                SettingsToggle(
                    title: "Launch at Login",
                    description: "Start ClearMind automatically when you log in",
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setLaunchAtLogin(newValue)
                }
                
                SettingsToggle(
                    title: "Enable Notifications",
                    description: "Show alerts for high memory pressure or system issues",
                    isOn: $enableNotifications
                )
            }
        }
    }
    
    // MARK: - Monitoring Settings Section
    
    private var monitoringSettingsSection: some View {
        SettingsSection(title: "Monitoring", icon: "gauge.with.dots.needle.bottom.50percent") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Refresh Interval")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(String(format: "%.1f", refreshInterval)) seconds")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $refreshInterval, in: 1...10, step: 0.5)
                    
                    Text("How often to update system metrics. Lower values provide more real-time data but use slightly more resources.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onChange(of: refreshInterval) { _, newValue in
                    systemMetrics.refreshInterval = newValue
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Warning Threshold")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(memoryWarningThreshold))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $memoryWarningThreshold, in: 50...95, step: 5)
                    
                    Text("Show warning when memory usage exceeds this percentage.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        SettingsSection(title: "Permissions", icon: "lock.shield") {
            VStack(spacing: 16) {
                // Status summary
                HStack {
                    Image(systemName: permissions.hasRequiredPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(permissions.hasRequiredPermissions ? .green : .yellow)
                    
                    Text(permissions.getStatusSummary())
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if permissions.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding()
                .background(permissions.hasRequiredPermissions ? Color.green.opacity(0.1) : Color.yellow.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                
                // Accessibility
                PermissionRow(
                    title: "Accessibility",
                    description: "Required for advanced system interactions",
                    status: permissions.accessibilityStatus,
                    onRequest: {
                        permissions.requestAccessibilityPermission()
                    }
                )
                
                Divider()
                
                // Automation targets
                Text("Browser Automation")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(permissions.automationTargets) { target in
                    AutomationPermissionRow(
                        target: target,
                        onRequest: {
                            permissions.requestAutomationPermission(for: target)
                        }
                    )
                }
                
                // Open settings button
                Button("Open System Settings") {
                    permissions.openPrivacySettings()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        SettingsSection(title: "Privacy", icon: "hand.raised") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Data Stays on Your Mac")
                            .font(.headline)
                        Text("ClearMind does not collect, transmit, or store any personal data or usage analytics.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("No analytics or tracking", systemImage: "xmark.circle")
                    Label("No cloud storage", systemImage: "xmark.circle")
                    Label("No network connections required", systemImage: "xmark.circle")
                    Label("All processing happens locally", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("View Privacy Policy") {
                    showingPrivacyPolicy = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Diagnostics Section
    
    private var diagnosticsSection: some View {
        SettingsSection(title: "Diagnostics", icon: "wrench.and.screwdriver") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Troubleshooting")
                            .font(.headline)
                        Text("View error logs and export diagnostic information")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("View Diagnostics") {
                        showingDiagnostics = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Settings")
                            .font(.headline)
                        Text("Restore all settings to their default values")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        resetSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle") {
            HStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ClearMind Control Center")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0 (Build 1)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("A macOS system utility for Apple Silicon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("About") {
                    showingAbout = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetSettings() {
        refreshInterval = 2.0
        showInDock = false
        launchAtLogin = false
        enableNotifications = true
        memoryWarningThreshold = 80.0
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            content()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .foregroundColor(statusColor)
                
                Text(status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                if status != .granted {
                    Button("Grant") {
                        onRequest()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .yellow
        case .restricted: return .orange
        }
    }
}

struct AutomationPermissionRow: View {
    let target: AutomationTarget
    let onRequest: () -> Void
    
    var body: some View {
        HStack {
            Text(target.name)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: target.status.icon)
                    .foregroundColor(statusColor)
                
                Text(target.status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                if target.status != .granted {
                    Button("Request") {
                        onRequest()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch target.status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .yellow
        case .restricted: return .orange
        }
    }
}

struct DiagnosticsSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var diagnosticText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Diagnostics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // System Info
                    GroupBox("System Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            DiagnosticRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                            DiagnosticRow(label: "Processor", value: "Apple Silicon")
                            DiagnosticRow(label: "Physical Memory", value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .file))
                            DiagnosticRow(label: "Active Processors", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // App Info
                    GroupBox("App Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            DiagnosticRow(label: "App Version", value: "1.0 (1)")
                            DiagnosticRow(label: "Bundle ID", value: "com.clearmind.controlcenter")
                            DiagnosticRow(label: "Uptime", value: formatUptime())
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Error Log (placeholder)
                    GroupBox("Recent Errors") {
                        Text("No recent errors")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Export button
            HStack {
                Spacer()
                
                Button("Export Diagnostics...") {
                    exportDiagnostics()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 500)
    }
    
    private func formatUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "clearmind_diagnostics.txt"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            let diagnostics = """
            ClearMind Control Center Diagnostics
            Generated: \(Date())
            
            System Information
            ==================
            macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            Physical Memory: \(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .file))
            Processors: \(ProcessInfo.processInfo.activeProcessorCount)
            
            App Information
            ================
            Version: 1.0 (1)
            Bundle ID: com.clearmind.controlcenter
            """
            
            try? diagnostics.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }
}

struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("ClearMind Control Center")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text("A powerful macOS utility for monitoring system resources, managing processes, optimizing memory, and controlling browser tabs. Built for Apple Silicon.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            // Credits
            VStack(spacing: 8) {
                Text("Built with Swift & SwiftUI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("© 2024 ClearMind")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 450, height: 400)
    }
}

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Privacy Policy")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ClearMind Control Center Privacy Policy")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Last updated: November 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Collection")
                            .font(.headline)
                        
                        Text("ClearMind Control Center does NOT collect, store, or transmit any personal data or usage information. All data processing happens locally on your Mac.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Access")
                            .font(.headline)
                        
                        Text("The app accesses system information (CPU, memory, processes) solely to display metrics and provide cleanup functionality. This information is never stored or shared.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Browser Integration")
                            .font(.headline)
                        
                        Text("Browser tab information is accessed only when you use the Browser Tabs feature and is never stored or transmitted. Access requires explicit permission via macOS Automation.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Network")
                            .font(.headline)
                        
                        Text("ClearMind does not make any network connections. There are no analytics, crash reporting, or update checks that transmit data.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Questions")
                            .font(.headline)
                        
                        Text("If you have questions about this privacy policy, please contact us through the app's support channels.")
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Preview

#Preview {
    SettingsPermissionsView()
        .environmentObject(SystemMetricsService())
        .environmentObject(PermissionsService())
        .frame(width: 700, height: 800)
}
