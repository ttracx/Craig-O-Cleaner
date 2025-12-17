// MARK: - MenuBarContentView.swift
// CraigOClean Control Center - Menu Bar Mini-Dashboard
// Provides quick access to key metrics and actions from the menu bar

import SwiftUI
import AppKit
import UserNotifications

struct MenuBarContentView: View {
    @StateObject private var systemMetrics = SystemMetricsService()
    @StateObject private var processManager = ProcessManager()
    @StateObject private var memoryOptimizer = MemoryOptimizerService()
    @StateObject private var browserAutomation = BrowserAutomationService()

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var userStore: LocalUserStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    
    let onExpandClick: () -> Void
    
    @State private var isRefreshing = false
    @State private var showingQuickCleanup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // System stats
            systemStatsSection
            
            Divider()
            
            // Quick actions
            quickActionsSection
            
            Divider()
            
            // Top processes
            topProcessesSection
            
            Divider()
            
            // Footer
            footerSection
        }
        .frame(width: 360)
        .onAppear {
            systemMetrics.startMonitoring()
            processManager.updateProcessList()
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

                HStack(spacing: 6) {
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

                    if auth.isSignedIn {
                        Text(userStore.profile?.displayName ?? "Signed in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Not signed in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if !subscriptions.isPro {
                Button {
                    onExpandClick()
                } label: {
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.vibePurple)
            }

            Button {
                isRefreshing = true
                Task {
                    await systemMetrics.refreshAllMetrics()
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
    
    // MARK: - System Stats Section
    
    private var systemStatsSection: some View {
        HStack(spacing: 12) {
            // CPU
            if let cpu = systemMetrics.cpuMetrics {
                MiniStatCard(
                    icon: "cpu",
                    title: "CPU",
                    value: "\(Int(cpu.totalUsage))%",
                    color: cpuColor(cpu.totalUsage)
                )
            }
            
            // Memory
            if let memory = systemMetrics.memoryMetrics {
                MiniStatCard(
                    icon: "memorychip",
                    title: "Memory",
                    value: "\(Int(memory.usedPercentage))%",
                    color: pressureColor(memory.pressureLevel)
                )
            }
            
            // Disk
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
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // First row of actions
            HStack(spacing: 6) {
                QuickActionPill(
                    icon: "sparkles",
                    title: "Smart Cleanup",
                    color: .blue
                ) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.smartCleanup()
                        showCleanupResult(result)
                    }
                }

                QuickActionPill(
                    icon: "moon.fill",
                    title: "Background",
                    color: .purple
                ) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupBackground()
                        showCleanupResult(result)
                    }
                }

                QuickActionPill(
                    icon: "memorychip",
                    title: "Memory",
                    color: .green
                ) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupHeavy(limit: 3)
                        showCleanupResult(result)
                    }
                }
            }

            // Second row of actions
            HStack(spacing: 6) {
                if browserAutomation.runningBrowsers.count > 0 {
                    QuickActionPill(
                        icon: "safari",
                        title: "Browser Tabs",
                        color: .cyan
                    ) {
                        onExpandClick()
                    }
                }

                QuickActionPill(
                    icon: "clock.arrow.circlepath",
                    title: "Auto Clean",
                    color: .orange
                ) {
                    Task {
                        await performAutoCleanup()
                    }
                }

                QuickActionPill(
                    icon: "arrow.clockwise.circle",
                    title: "Refresh",
                    color: .gray
                ) {
                    Task {
                        await systemMetrics.refreshAllMetrics()
                        processManager.updateProcessList()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func showCleanupResult(_ result: CleanupResult) {
        if result.appsTerminated > 0 {
            let content = UNMutableNotificationContent()
            content.title = "Cleanup Complete"
            content.body = "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) apps"
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    private func performAutoCleanup() async {
        await memoryOptimizer.analyzeMemoryUsage()

        // Close heavy background apps
        let backgroundResult = await memoryOptimizer.quickCleanupBackground()

        // If memory pressure is still high, do smart cleanup
        if let memory = systemMetrics.memoryMetrics, memory.pressureLevel != .normal {
            let smartResult = await memoryOptimizer.smartCleanup()
            let totalApps = backgroundResult.appsTerminated + smartResult.appsTerminated
            let totalMemory = backgroundResult.memoryFreed + smartResult.memoryFreed

            let content = UNMutableNotificationContent()
            content.title = "Auto Cleanup Complete"
            content.body = "Freed \(ByteCountFormatter.string(fromByteCount: totalMemory, countStyle: .file)) by closing \(totalApps) apps"
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in }
        } else {
            showCleanupResult(backgroundResult)
        }
    }
    
    // MARK: - Top Processes Section

    private var topProcessesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Running Apps")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("(Right-click to quit)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    let topProcesses = Array(processManager.processes
                        .filter { $0.isUserProcess }
                        .sorted { $0.memoryUsage > $1.memoryUsage }
                        .prefix(8))

                    ForEach(topProcesses) { process in
                        MiniProcessRow(
                            process: process,
                            onQuit: {
                                quitProcess(process)
                            },
                            onForceQuit: {
                                forceQuitProcess(process)
                            }
                        )
                    }

                    if topProcesses.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "app.dashed")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No apps running")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 220)
        }
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
                let content = UNMutableNotificationContent()
                content.title = "App Force Quit"
                content.body = "\(process.name) has been force quit"
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { _ in }
            }
        }
    }
    
    // MARK: - Footer Section
    
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
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
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
            // Icon
            if let bundleId = process.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: process.isUserProcess ? "app" : "gear")
                    .frame(width: 20, height: 20)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(process.name)
                    .font(.caption)
                    .lineLimit(1)
                Text("PID: \(process.pid)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Memory
            Text(process.formattedMemoryUsage)
                .font(.caption)
                .foregroundColor(.secondary)

            // Quick action buttons (show on hover)
            if isHovered {
                Button {
                    onQuit()
                } label: {
                    Text("Quit")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button {
                    onForceQuit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help("Force Quit")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Quit") {
                onQuit()
            }
            Button("Force Quit") {
                onForceQuit()
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView(onExpandClick: {})
}
