// EnhancedMenuBarView.swift
// ClearMind Control Center
//
// Enhanced menu bar popup with system metrics, quick actions, and process list
// Provides at-a-glance system status and one-click optimizations

import SwiftUI

struct EnhancedMenuBarView: View {
    @StateObject private var processManager = ProcessManager()
    @StateObject private var metricsService = SystemMetricsService()
    @StateObject private var browserService = BrowserAutomationService()
    @State private var searchText = ""
    @State private var showingQuickCleanup = false
    @State private var isCleaningUp = false

    var onExpandClick: () -> Void
    var onQuickCleanup: () -> Void

    var filteredProcesses: [ProcessInfo] {
        let topProcesses = processManager.processes
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(8)

        if searchText.isEmpty {
            return Array(topProcesses)
        } else {
            return Array(topProcesses.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with system health
            headerView
            
            Divider()
            
            // System metrics cards
            metricsCardsView
            
            Divider()
            
            // Quick actions
            quickActionsView
            
            Divider()

            // Search bar
            searchBarView

            Divider()

            // Top processes list
            processListView

            Divider()

            // Footer with expand button
            footerView
        }
        .frame(width: 380)
        .onAppear {
            processManager.updateProcessList()
            metricsService.updateAllMetrics()
            browserService.updateRunningBrowsers()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // App icon and name
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClearMind")
                    .font(.headline)
                    .fontWeight(.bold)

                Text(healthStatusText)
                    .font(.caption2)
                    .foregroundColor(healthStatusColor)
            }

            Spacer()

            // Refresh button
            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(processManager.isLoading || metricsService.isUpdating)
        }
        .padding()
        .background(healthStatusColor.opacity(0.1))
    }
    
    // MARK: - Metrics Cards View
    
    private var metricsCardsView: some View {
        HStack(spacing: 12) {
            // CPU
            MetricCardMini(
                icon: "cpu",
                title: "CPU",
                value: cpuText,
                color: cpuColor
            )
            
            // Memory
            MetricCardMini(
                icon: "memorychip",
                title: "Memory",
                value: memoryText,
                color: memoryColor
            )
            
            // Disk
            MetricCardMini(
                icon: "internaldrive",
                title: "Disk",
                value: diskText,
                color: diskColor
            )
        }
        .padding()
    }
    
    // MARK: - Quick Actions View
    
    private var quickActionsView: some View {
        HStack(spacing: 8) {
            // Quick cleanup
            Button {
                performQuickCleanup()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                    Text("Optimize")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(isCleaningUp)
            
            // Close heavy tabs
            Button {
                closeHeavyTabs()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.title3)
                    Text("Close Tabs")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(browserService.runningBrowsers.isEmpty)
            
            // Full dashboard
            Button {
                onExpandClick()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.expand.vertical")
                        .font(.title3)
                    Text("Dashboard")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Search Bar View
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)

            TextField("Search processes...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Process List View
    
    private var processListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredProcesses) { process in
                    CompactProcessRowEnhanced(process: process)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }

                if filteredProcesses.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No processes found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                }
            }
        }
        .frame(height: 220)
    }

    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            // Process count
            Text("\(processManager.processes.count) processes")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Browser tabs
            if browserService.totalTabCount > 0 {
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(browserService.totalTabCount) tabs")
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
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var healthStatusText: String {
        guard let health = metricsService.healthSummary?.overallHealth else {
            return "Checking..."
        }
        return "System: \(health.rawValue)"
    }
    
    private var healthStatusColor: Color {
        guard let health = metricsService.healthSummary?.overallHealth else {
            return .gray
        }
        switch health {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private var cpuText: String {
        guard let cpu = metricsService.cpuMetrics else { return "--" }
        return String(format: "%.0f%%", cpu.overallUsage)
    }
    
    private var cpuColor: Color {
        guard let cpu = metricsService.cpuMetrics else { return .gray }
        if cpu.overallUsage < 50 { return .green }
        else if cpu.overallUsage < 80 { return .orange }
        else { return .red }
    }
    
    private var memoryText: String {
        guard let memory = metricsService.memoryMetrics else { return "--" }
        return String(format: "%.0f%%", memory.usedPercentage)
    }
    
    private var memoryColor: Color {
        guard let memory = metricsService.memoryMetrics else { return .gray }
        if memory.usedPercentage < 60 { return .green }
        else if memory.usedPercentage < 80 { return .orange }
        else { return .red }
    }
    
    private var diskText: String {
        guard let disk = metricsService.diskMetrics else { return "--" }
        return String(format: "%.0f%%", disk.usedPercentage)
    }
    
    private var diskColor: Color {
        guard let disk = metricsService.diskMetrics else { return .gray }
        if disk.usedPercentage < 70 { return .green }
        else if disk.usedPercentage < 85 { return .orange }
        else { return .red }
    }
    
    // MARK: - Actions
    
    private func refresh() {
        processManager.updateProcessList()
        metricsService.updateAllMetrics()
        Task {
            await browserService.fetchAllTabs()
        }
    }
    
    private func performQuickCleanup() {
        isCleaningUp = true
        onQuickCleanup()
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isCleaningUp = false
            refresh()
        }
    }
    
    private func closeHeavyTabs() {
        Task {
            _ = await browserService.closeHeavyTabs(limit: 5)
            await browserService.fetchAllTabs()
        }
    }
}

// MARK: - Supporting Views

struct MetricCardMini: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CompactProcessRowEnhanced: View {
    let process: ProcessInfo

    var memoryColor: Color {
        let mb = Double(process.memoryUsage) / 1024.0 / 1024.0
        if mb < 200 { return .green }
        else if mb < 500 { return .orange }
        else { return .red }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            if let bundleIdentifier = process.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "gear")
                    .frame(width: 16, height: 16)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            // CPU
            HStack(spacing: 2) {
                Text(String(format: "%.1f%%", process.cpuUsage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 40, alignment: .trailing)

            // Memory
            Text(String(format: "%.0f MB", Double(process.memoryUsage) / 1024.0 / 1024.0))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(memoryColor)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(4)
    }
}

#Preview {
    EnhancedMenuBarView(
        onExpandClick: {},
        onQuickCleanup: {}
    )
}
