// MARK: - SandboxDashboardView.swift
// Craig-O-Clean Sandbox Edition - Main Dashboard
// Displays system status and provides quick actions

import SwiftUI

struct SandboxDashboardView: View {
    @EnvironmentObject var metricsProvider: SandboxMetricsProvider
    @EnvironmentObject var processManager: SandboxProcessManager
    @EnvironmentObject var browserAutomation: SandboxBrowserAutomation
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager

    @State private var showingPermissionSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with status
                headerSection

                // Quick Stats Grid
                statsGridSection

                // Memory Pressure Indicator
                memoryPressureSection

                // Top Consumers
                topConsumersSection

                // Quick Actions
                quickActionsSection

                // Permission Status (if any missing)
                if permissionsManager.permissionSummary.criticalMissing {
                    permissionAlertSection
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .onAppear {
            metricsProvider.startMonitoring()
            processManager.startAutoUpdate()
        }
        .sheet(isPresented: $showingPermissionSetup) {
            PermissionSetupView()
                .environmentObject(permissionsManager)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Health")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 12, height: 12)

                    Text(healthStatus)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            Spacer()

            if let lastUpdate = metricsProvider.lastUpdateTime {
                Text("Updated \(lastUpdate, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Stats Grid

    private var statsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // CPU
            StatCard(
                title: "CPU",
                value: metricsProvider.cpuMetrics?.formattedUsage ?? "--",
                icon: "cpu",
                color: cpuColor
            )

            // Memory
            StatCard(
                title: "Memory",
                value: String(format: "%.0f%%", metricsProvider.memoryMetrics?.usedPercentage ?? 0),
                icon: "memorychip",
                color: memoryColor
            )

            // Disk
            StatCard(
                title: "Disk Free",
                value: metricsProvider.diskMetrics?.formattedFreeSpace ?? "--",
                icon: "internaldrive",
                color: .blue
            )

            // Browser Tabs
            StatCard(
                title: "Browser Tabs",
                value: "\(browserAutomation.totalTabCount)",
                icon: "safari",
                color: .purple
            )
        }
    }

    // MARK: - Memory Pressure Section

    private var memoryPressureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metricsProvider.memoryMetrics?.pressureLevel.icon ?? "checkmark.circle")
                    .foregroundColor(memoryColor)
                Text("Memory Pressure")
                    .font(.headline)
                Spacer()
            }

            if let memory = metricsProvider.memoryMetrics {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(memoryColor)
                            .frame(width: geo.size.width * CGFloat(memory.usedPercentage / 100), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(memory.formattedUsedRAM) used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(memory.formattedTotalRAM) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(memory.pressureLevel.description)
                    .font(.caption)
                    .foregroundColor(memoryColor)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Top Consumers Section

    private var topConsumersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                Text("Top Memory Users")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    SandboxProcessListView()
                        .environmentObject(processManager)
                }
                .font(.caption)
            }

            ForEach(processManager.getTopMemoryConsumers(limit: 5)) { process in
                ProcessRow(process: process)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Close Background Apps",
                    icon: "moon.fill",
                    color: .indigo
                ) {
                    Task {
                        await closeBackgroundApps()
                    }
                }

                QuickActionButton(
                    title: "Close Heavy Tabs",
                    icon: "safari",
                    color: .orange
                ) {
                    Task {
                        try? await browserAutomation.closeHeavyTabs()
                    }
                }

                QuickActionButton(
                    title: "Refresh Stats",
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    Task {
                        await metricsProvider.refreshAllMetrics()
                        processManager.updateProcessList()
                    }
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Permission Alert

    private var permissionAlertSection: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading) {
                Text("Permissions Needed")
                    .font(.headline)
                Text("Some features require additional permissions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Set Up") {
                showingPermissionSetup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var healthStatus: String {
        guard let memory = metricsProvider.memoryMetrics else { return "Checking..." }
        switch memory.pressureLevel {
        case .normal: return "Healthy"
        case .warning: return "Elevated"
        case .critical: return "High Pressure"
        }
    }

    private var healthColor: Color {
        guard let memory = metricsProvider.memoryMetrics else { return .gray }
        switch memory.pressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var cpuColor: Color {
        guard let cpu = metricsProvider.cpuMetrics else { return .blue }
        if cpu.totalUsage > 80 { return .red }
        if cpu.totalUsage > 60 { return .orange }
        return .blue
    }

    private var memoryColor: Color {
        guard let memory = metricsProvider.memoryMetrics else { return .green }
        switch memory.pressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    // MARK: - Actions

    private func closeBackgroundApps() async {
        let backgroundApps = processManager.getBackgroundApps()
        for app in backgroundApps.prefix(5) {
            _ = await processManager.quitApp(app)
        }
        processManager.updateProcessList()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct ProcessRow: View {
    let process: SandboxProcessInfo

    var body: some View {
        HStack {
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 20, height: 20)
            }

            Text(process.name)
                .lineLimit(1)

            Spacer()

            Text(process.formattedMemoryUsage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    SandboxDashboardView()
        .environmentObject(SandboxMetricsProvider())
        .environmentObject(SandboxProcessManager())
        .environmentObject(SandboxBrowserAutomation(permissionsManager: SandboxPermissionsManager()))
        .environmentObject(SandboxPermissionsManager())
}
