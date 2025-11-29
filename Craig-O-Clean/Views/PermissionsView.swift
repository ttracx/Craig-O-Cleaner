// PermissionsView.swift
// ClearMind Control Center
//
// View for managing app permissions, security settings, and preferences
// Shows permission status and provides guidance for enabling required access

import SwiftUI

struct PermissionsView: View {
    @StateObject private var permissionsService = PermissionsService()
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("showInDock") private var showInDock: Bool = false
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @State private var selectedSection: SettingsSection = .permissions
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case permissions = "Permissions"
        case general = "General"
        case advanced = "Advanced"
        case about = "About"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .permissions: return "lock.shield"
            case .general: return "gearshape"
            case .advanced: return "slider.horizontal.3"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("SETTINGS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding()
                
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack {
                            Image(systemName: section.icon)
                                .frame(width: 20)
                            Text(section.rawValue)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(selectedSection == section ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedSection {
                    case .permissions:
                        permissionsSection
                    case .general:
                        generalSection
                    case .advanced:
                        advancedSection
                    case .about:
                        aboutSection
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions & Security")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("ClearMind Control Center needs certain permissions to manage your system effectively.")
                    .foregroundColor(.secondary)
            }
            
            // Permission status overview
            HStack(spacing: 16) {
                PermissionStatusCard(
                    title: "Granted",
                    count: permissionsService.grantedPermissionsCount,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                PermissionStatusCard(
                    title: "Denied",
                    count: permissionsService.deniedPermissionsCount,
                    color: .red,
                    icon: "xmark.circle.fill"
                )
                
                Spacer()
                
                Button {
                    Task {
                        await permissionsService.checkAllPermissions()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(permissionsService.isChecking)
            }
            
            Divider()
            
            // General permissions
            VStack(alignment: .leading, spacing: 16) {
                Text("Required Permissions")
                    .font(.headline)
                
                ForEach(permissionsService.permissions) { permission in
                    PermissionRowView(
                        permission: permission,
                        onOpenSettings: {
                            permissionsService.openSettings(for: permission.type)
                        }
                    )
                }
            }
            
            Divider()
            
            // Automation permissions
            VStack(alignment: .leading, spacing: 16) {
                Text("Browser Automation")
                    .font(.headline)
                
                Text("To manage browser tabs, ClearMind needs permission to control each browser.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(permissionsService.automationPermissions) { detail in
                    AutomationPermissionRow(detail: detail)
                }
                
                Button("Open Automation Settings") {
                    permissionsService.openAutomationSettings()
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // How to grant permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Grant Permissions")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: 1, text: "Click \"Open Settings\" next to the permission you want to grant")
                    InstructionStep(number: 2, text: "Click the lock icon in System Settings to make changes")
                    InstructionStep(number: 3, text: "Find ClearMind Control Center and enable the toggle")
                    InstructionStep(number: 4, text: "You may need to restart the app for changes to take effect")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            // Launch at login
            SettingsGroup(title: "Startup") {
                Toggle(isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { newValue in
                        launchAtLoginManager.isEnabled = newValue
                        launchAtLoginManager.toggleLaunchAtLogin()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at Login")
                            .font(.body)
                        Text("Start ClearMind Control Center when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Appearance
            SettingsGroup(title: "Appearance") {
                Toggle(isOn: $showInDock) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show in Dock")
                            .font(.body)
                        Text("Display app icon in the Dock when the main window is open")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Notifications
            SettingsGroup(title: "Notifications") {
                Toggle(isOn: $showNotifications) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Notifications")
                            .font(.body)
                        Text("Get alerts for high memory usage and other important events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Refresh interval
            SettingsGroup(title: "Performance") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Update Interval")
                        Spacer()
                        Text("\(Int(refreshInterval)) seconds")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $refreshInterval, in: 1...10, step: 1)
                    
                    Text("How often to refresh system metrics. Lower values use more CPU.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Advanced Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            // Memory management
            SettingsGroup(title: "Memory Management") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Purge Memory Cache")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Clears inactive memory cache. This requires administrator privileges and may briefly impact system performance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Use only when experiencing memory issues")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Privacy
            SettingsGroup(title: "Privacy") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.blue)
                        Text("No Data Collection")
                            .fontWeight(.medium)
                    }
                    
                    Text("ClearMind Control Center does not collect, transmit, or store any personal data. All monitoring happens locally on your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Reset
            SettingsGroup(title: "Reset") {
                Button(role: .destructive) {
                    resetSettings()
                } label: {
                    Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                
                Text("Restore all settings to their default values")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App info
            HStack(spacing: 20) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("ClearMind Control Center")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 2.0")
                        .foregroundColor(.secondary)
                    
                    Text("A powerful macOS utility for monitoring system resources, managing processes, and optimizing memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Features
            SettingsGroup(title: "Features") {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureItem(icon: "chart.line.uptrend.xyaxis", title: "System Dashboard", description: "Real-time CPU, memory, disk, and network monitoring")
                    FeatureItem(icon: "list.bullet.rectangle", title: "Process Manager", description: "View and manage running applications and processes")
                    FeatureItem(icon: "memorychip", title: "Memory Cleanup", description: "Guided cleanup workflows to free up memory")
                    FeatureItem(icon: "globe", title: "Browser Tab Manager", description: "View and close tabs across Safari, Chrome, and Edge")
                    FeatureItem(icon: "menubar.rectangle", title: "Menu Bar App", description: "Quick access from the menu bar")
                }
            }
            
            Divider()
            
            // System info
            SettingsGroup(title: "System Information") {
                VStack(alignment: .leading, spacing: 8) {
                    SystemInfoRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    SystemInfoRow(label: "Processor", value: getProcessorInfo())
                    SystemInfoRow(label: "Memory", value: getMemoryInfo())
                }
            }
            
            Divider()
            
            // Credits
            VStack(alignment: .leading, spacing: 8) {
                Text("Built with ❤️ using SwiftUI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("© 2025 ClearMind Control Center")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetSettings() {
        refreshInterval = 2.0
        showInDock = false
        showNotifications = true
    }
    
    private func getProcessorInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        return String(cString: brand).trimmingCharacters(in: .whitespaces)
    }
    
    private func getMemoryInfo() -> String {
        let memory = ProcessInfo.processInfo.physicalMemory
        let gb = Double(memory) / 1_073_741_824.0
        return String(format: "%.0f GB", gb)
    }
}

// MARK: - Supporting Views

struct PermissionStatusCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PermissionRowView: View {
    let permission: PermissionInfo
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: permission.status.icon)
                .font(.title2)
                .foregroundColor(statusColor)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(permission.type.rawValue)
                        .fontWeight(.medium)
                    
                    if permission.importance == .required {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                
                Text(permission.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status & Action
            VStack(alignment: .trailing, spacing: 4) {
                Text(permission.status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                if permission.status != .granted {
                    Button("Open Settings") {
                        onOpenSettings()
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch permission.status {
        case .granted: return .green
        case .denied: return .red
        case .unknown, .notDetermined: return .orange
        }
    }
}

struct AutomationPermissionRow: View {
    let detail: AutomationPermissionDetail
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = detail.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app")
                    .frame(width: 24, height: 24)
            }
            
            Text(detail.appName)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(detail.status))
                    .frame(width: 8, height: 8)
                Text(detail.status.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .unknown, .notDetermined: return .gray
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SystemInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PermissionsView()
        .frame(width: 800, height: 700)
}
