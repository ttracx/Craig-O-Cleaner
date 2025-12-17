// MARK: - MenuBarContentView.swift
// CraigOClean Control Center - Menu Bar Mini-Dashboard
// Provides quick access to key metrics and actions from the menu bar

import SwiftUI
import AppKit
import UserNotifications

// MARK: - Menu Bar Tab

enum MenuBarTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case memory = "Memory"
    case browser = "Browser"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .memory: return "memorychip"
        case .browser: return "safari"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Main Menu Bar Content View

struct MenuBarContentView: View {
    @StateObject private var systemMetrics = SystemMetricsService()
    @StateObject private var processManager = ProcessManager()
    @StateObject private var memoryOptimizer = MemoryOptimizerService()
    @StateObject private var browserAutomation = BrowserAutomationService()

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var userStore: LocalUserStore
    @EnvironmentObject var subscriptions: SubscriptionManager

    let onExpandClick: () -> Void

    @State private var selectedTab: MenuBarTab = .dashboard
    @State private var isRefreshing = false
    @State private var autoCleanup: AutoCleanupService?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Tab bar
            tabBar

            Divider()

            // Tab content
            tabContent
        }
        .frame(width: 380)
        .onAppear {
            systemMetrics.startMonitoring()
            processManager.updateProcessList()

            // Initialize AutoCleanupService with dependencies
            if autoCleanup == nil {
                autoCleanup = AutoCleanupService(
                    systemMetrics: systemMetrics,
                    memoryOptimizer: memoryOptimizer,
                    processManager: processManager
                )
            }

            Task {
                await memoryOptimizer.analyzeMemoryUsage()
                await browserAutomation.fetchAllTabs()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("CraigOClean")
                    .font(.headline)
                    .fontWeight(.bold)

                // Quick status
                if let memory = systemMetrics.memoryMetrics {
                    HStack(spacing: 8) {
                        StatusDot(color: pressureColor(memory.pressureLevel))
                        Text(memory.pressureLevel.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("\(Int(memory.usedPercentage))% used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if subscriptions.isPro {
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.vibePurple.opacity(0.2))
                    .foregroundColor(.vibePurple)
                    .cornerRadius(6)
            }

            Button {
                isRefreshing = true
                Task {
                    await systemMetrics.refreshAllMetrics()
                    await memoryOptimizer.analyzeMemoryUsage()
                    processManager.updateProcessList()
                    isRefreshing = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MenuBarTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .dashboard:
            MenuBarDashboardTab(
                systemMetrics: systemMetrics,
                processManager: processManager,
                memoryOptimizer: memoryOptimizer,
                onExpandClick: onExpandClick
            )
        case .memory:
            MenuBarMemoryTab(
                systemMetrics: systemMetrics,
                memoryOptimizer: memoryOptimizer
            )
        case .browser:
            MenuBarBrowserTab(
                browserAutomation: browserAutomation
            )
        case .settings:
            if let autoCleanup = autoCleanup {
                MenuBarSettingsTab(
                    autoCleanup: autoCleanup,
                    onExpandClick: onExpandClick
                )
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Helper Methods

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

// MARK: - Dashboard Tab

struct MenuBarDashboardTab: View {
    @ObservedObject var systemMetrics: SystemMetricsService
    @ObservedObject var processManager: ProcessManager
    @ObservedObject var memoryOptimizer: MemoryOptimizerService
    let onExpandClick: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // System stats
                systemStatsSection

                // Quick actions
                quickActionsSection

                // Top processes
                topProcessesSection

                // Footer
                footerSection
            }
            .padding(.vertical, 8)
        }
        .frame(height: 420)
    }

    private var systemStatsSection: some View {
        HStack(spacing: 8) {
            if let cpu = systemMetrics.cpuMetrics {
                MiniStatCard(
                    icon: "cpu",
                    title: "CPU",
                    value: "\(Int(cpu.totalUsage))%",
                    color: cpuColor(cpu.totalUsage)
                )
            }

            if let memory = systemMetrics.memoryMetrics {
                MiniStatCard(
                    icon: "memorychip",
                    title: "Memory",
                    value: "\(Int(memory.usedPercentage))%",
                    color: pressureColor(memory.pressureLevel)
                )
            }

            if let disk = systemMetrics.diskMetrics {
                MiniStatCard(
                    icon: "internaldrive",
                    title: "Disk",
                    value: "\(Int(disk.usedPercentage))%",
                    color: diskColor(disk.usedPercentage)
                )
            }
        }
        .padding(.horizontal)
    }

    private var quickActionsSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            HStack(spacing: 6) {
                QuickActionPill(icon: "sparkles", title: "Smart", color: .blue) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.smartCleanup()
                        await showCleanupResult(result)
                    }
                }

                QuickActionPill(icon: "moon.fill", title: "Background", color: .purple) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupBackground()
                        await showCleanupResult(result)
                    }
                }

                QuickActionPill(icon: "memorychip", title: "Heavy", color: .orange) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupHeavy(limit: 3)
                        await showCleanupResult(result)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var topProcessesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Running Apps")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)

            LazyVStack(spacing: 2) {
                let topProcesses = Array(processManager.processes
                    .filter { $0.isUserProcess }
                    .sorted { $0.memoryUsage > $1.memoryUsage }
                    .prefix(5))

                ForEach(topProcesses) { process in
                    MiniProcessRow(
                        process: process,
                        onQuit: { quitProcess(process) },
                        onForceQuit: { forceQuitProcess(process) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var footerSection: some View {
        HStack {
            if let lastUpdate = systemMetrics.lastUpdateTime {
                Text("Updated \(lastUpdate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onExpandClick()
            } label: {
                HStack(spacing: 4) {
                    Text("Open Full App")
                        .font(.caption)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
    }

    private func quitProcess(_ process: ProcessInfo) {
        Task {
            let success = await processManager.terminateProcess(process)
            if success {
                processManager.updateProcessList()
            }
        }
    }

    private func forceQuitProcess(_ process: ProcessInfo) {
        Task {
            let success = await processManager.forceQuitProcess(process)
            if success {
                processManager.updateProcessList()
            }
        }
    }

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<60: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func diskColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<70: return .green
        case 70..<85: return .yellow
        case 85..<95: return .orange
        default: return .red
        }
    }
}

// MARK: - Memory Tab

struct MenuBarMemoryTab: View {
    @ObservedObject var systemMetrics: SystemMetricsService
    @ObservedObject var memoryOptimizer: MemoryOptimizerService

    @State private var lastResult: CleanupResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Memory gauge
                memoryGaugeSection

                // Memory breakdown
                memoryBreakdownSection

                // Quick cleanup buttons
                cleanupButtonsSection

                // Cleanup candidates
                cleanupCandidatesSection

                // Last result
                if let result = lastResult {
                    lastResultSection(result)
                }
            }
            .padding()
        }
        .frame(height: 420)
    }

    private var memoryGaugeSection: some View {
        HStack {
            if let memory = systemMetrics.memoryMetrics {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Status")
                        .font(.headline)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(pressureColor(memory.pressureLevel))
                            .frame(width: 10, height: 10)
                        Text(memory.pressureLevel.rawValue)
                            .font(.subheadline)
                            .foregroundColor(pressureColor(memory.pressureLevel))
                    }

                    Text("\(SystemMetricsService.formatBytes(memory.availableRAM)) available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Circular gauge
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: memory.usedPercentage / 100)
                        .stroke(pressureColor(memory.pressureLevel), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(memory.usedPercentage))%")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 70, height: 70)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var memoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let memory = systemMetrics.memoryMetrics {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: segmentWidth(for: memory.activeRAM, total: memory.totalRAM, in: geometry))

                        Rectangle()
                            .fill(Color.red)
                            .frame(width: segmentWidth(for: memory.wiredRAM, total: memory.totalRAM, in: geometry))

                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: segmentWidth(for: memory.compressedRAM, total: memory.totalRAM, in: geometry))

                        Rectangle()
                            .fill(Color.green.opacity(0.5))
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)

                HStack(spacing: 12) {
                    LegendItem(color: .orange, label: "App")
                    LegendItem(color: .red, label: "Wired")
                    LegendItem(color: .purple, label: "Compressed")
                    LegendItem(color: .green.opacity(0.5), label: "Free")
                }
                .font(.caption2)
            }
        }
    }

    private var cleanupButtonsSection: some View {
        HStack(spacing: 8) {
            CleanupButton(title: "Smart Cleanup", icon: "sparkles", color: .blue) {
                Task {
                    let result = await memoryOptimizer.smartCleanup()
                    lastResult = result
                }
            }

            CleanupButton(title: "Close Background", icon: "moon.fill", color: .purple) {
                Task {
                    let result = await memoryOptimizer.quickCleanupBackground()
                    lastResult = result
                }
            }
        }
    }

    private var cleanupCandidatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cleanup Candidates")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if !memoryOptimizer.cleanupCandidates.isEmpty {
                    Text("\(memoryOptimizer.cleanupCandidates.count) apps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if memoryOptimizer.isAnalyzing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if memoryOptimizer.cleanupCandidates.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Memory is optimized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(memoryOptimizer.cleanupCandidates.prefix(4))) { candidate in
                        HStack {
                            if let icon = candidate.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(candidate.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(candidate.formattedMemoryUsage)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func lastResultSection(_ result: CleanupResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(result.success ? .green : .yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Cleanup")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Freed \(result.formattedMemoryFreed)")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Spacer()

            Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private func segmentWidth(for bytes: UInt64, total: UInt64, in geometry: GeometryProxy) -> CGFloat {
        let percentage = Double(bytes) / Double(total)
        return max(0, geometry.size.width * CGFloat(percentage) - 2)
    }
}

// MARK: - Browser Tab

struct MenuBarBrowserTab: View {
    @ObservedObject var browserAutomation: BrowserAutomationService

    @State private var selectedTabs: Set<BrowserTab> = []
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Browser summary
            browserSummarySection

            Divider()

            // Tab list
            if browserAutomation.runningBrowsers.isEmpty {
                noBrowsersView
            } else if browserAutomation.allTabs.isEmpty {
                noTabsView
            } else {
                tabListSection
            }

            // Actions
            if !browserAutomation.allTabs.isEmpty {
                actionsSection
            }
        }
        .frame(height: 420)
    }

    private var browserSummarySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser Tabs")
                    .font(.headline)

                Text("\(browserAutomation.allTabs.count) tabs across \(browserAutomation.runningBrowsers.count) browsers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                isRefreshing = true
                Task {
                    await browserAutomation.fetchAllTabs()
                    isRefreshing = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isRefreshing)
        }
        .padding()
    }

    private var noBrowsersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "safari")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No browsers running")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTabsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("No tabs found")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabListSection: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(browserAutomation.allTabs.prefix(15)) { tab in
                    BrowserTabRow(
                        tab: tab,
                        isSelected: selectedTabs.contains(tab),
                        onToggle: {
                            if selectedTabs.contains(tab) {
                                selectedTabs.remove(tab)
                            } else {
                                selectedTabs.insert(tab)
                            }
                        },
                        onClose: {
                            Task {
                                try? await browserAutomation.closeTab(tab)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var actionsSection: some View {
        HStack {
            if !selectedTabs.isEmpty {
                Button("Close \(selectedTabs.count) Selected") {
                    Task {
                        for tab in selectedTabs {
                            try? await browserAutomation.closeTab(tab)
                        }
                        selectedTabs.removeAll()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }

            Spacer()

            Button("Select All") {
                selectedTabs = Set(browserAutomation.allTabs)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Clear") {
                selectedTabs.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedTabs.isEmpty)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Settings Tab

struct MenuBarSettingsTab: View {
    @ObservedObject var autoCleanup: AutoCleanupService
    let onExpandClick: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Auto-cleanup toggle
                autoCleanupSection

                // Thresholds (if enabled)
                if autoCleanup.isEnabled {
                    thresholdsSection
                    statisticsSection
                }

                // Quick settings
                quickSettingsSection

                // Open full settings
                fullSettingsButton
            }
            .padding()
        }
        .frame(height: 420)
    }

    private var autoCleanupSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.vibePurple)
                Text("Auto-Cleanup")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { autoCleanup.isEnabled },
                    set: { newValue in
                        if newValue {
                            autoCleanup.enable()
                        } else {
                            autoCleanup.disable()
                        }
                    }
                ))
                .labelsHidden()
            }

            if autoCleanup.isEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.vibeTeal)
                        .font(.caption)
                    Text("Monitoring active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thresholds")
                .font(.caption)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                HStack {
                    Text("Memory Warning")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(autoCleanup.thresholds.memoryWarning))%")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }

                HStack {
                    Text("Memory Critical")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(autoCleanup.thresholds.memoryCritical))%")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack {
                    Text("CPU Warning")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(autoCleanup.thresholds.cpuWarning))%")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.caption)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                StatItem(label: "Cleanups", value: "\(autoCleanup.totalCleanups)")
                StatItem(label: "Memory Freed", value: formatBytes(Int64(autoCleanup.totalMemoryFreed)))
                StatItem(label: "Apps Closed", value: "\(autoCleanup.totalProcessesTerminated)")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Settings")
                .font(.caption)
                .fontWeight(.medium)

            Button {
                Task {
                    await autoCleanup.triggerImmediateCleanup()
                }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Trigger Immediate Cleanup")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.vibePurple)
            .disabled(!autoCleanup.isEnabled)
        }
    }

    private var fullSettingsButton: some View {
        Button {
            onExpandClick()
        } label: {
            HStack {
                Image(systemName: "gearshape.2")
                Text("Open Full Settings")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Supporting Views

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

struct MiniStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QuickActionPill: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isHovered ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? color : color.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MiniProcessRow: View {
    let process: ProcessInfo
    let onQuit: () -> Void
    let onForceQuit: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if let bundleId = process.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: process.isUserProcess ? "app" : "gear")
                    .frame(width: 18, height: 18)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(process.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(process.formattedMemoryUsage)
                .font(.caption)
                .foregroundColor(.secondary)

            if isHovered {
                Button {
                    onForceQuit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Quit") { onQuit() }
            Button("Force Quit") { onForceQuit() }
        }
    }
}

struct CleanupButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct BrowserTabRow: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onToggle: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .onTapGesture { onToggle() }

            Image(systemName: tab.browser.icon)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(tab.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(tab.domain)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Function

private func showCleanupResult(_ result: CleanupResult) async {
    if result.appsTerminated > 0 {
        let content = UNMutableNotificationContent()
        content.title = "Cleanup Complete"
        content.body = "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) apps"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView(onExpandClick: {})
        .environmentObject(AuthManager.shared)
        .environmentObject(LocalUserStore.shared)
        .environmentObject(SubscriptionManager.shared)
}
