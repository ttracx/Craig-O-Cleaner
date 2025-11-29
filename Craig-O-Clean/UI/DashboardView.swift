// MARK: - DashboardView.swift
// CraigOClean Control Center - System Dashboard
// Displays comprehensive system health metrics in a card-based layout

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var systemMetrics: SystemMetricsService
    @EnvironmentObject var processManager: ProcessManager
    
    @State private var showingDetailedCPU = false
    @State private var showingDetailedMemory = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with refresh info
                headerSection
                
                // Main metrics cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    // CPU Card
                    cpuCard
                    
                    // Memory Card
                    memoryCard
                    
                    // Disk Card
                    diskCard
                    
                    // Network Card
                    networkCard
                }
                
                // Bottom section with quick stats
                HStack(spacing: 16) {
                    // Top Processes
                    topProcessesCard
                    
                    // System Info
                    systemInfoCard
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await systemMetrics.refreshAllMetrics()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(systemMetrics.isMonitoring == false)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Health")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let lastUpdate = systemMetrics.lastUpdateTime {
                    Text("Last updated: \(lastUpdate.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Overall health indicator
            if let memory = systemMetrics.memoryMetrics {
                HealthIndicator(level: memory.pressureLevel)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - CPU Card
    
    private var cpuCard: some View {
        MetricCard(title: "CPU", icon: "cpu", color: .blue) {
            if let cpu = systemMetrics.cpuMetrics {
                VStack(spacing: 16) {
                    // Main gauge
                    CircularGauge(
                        value: cpu.totalUsage,
                        maxValue: 100,
                        color: cpuColor(cpu.totalUsage),
                        label: "\(Int(cpu.totalUsage))%"
                    )
                    .frame(height: 120)
                    
                    // Breakdown
                    HStack(spacing: 20) {
                        MetricItem(label: "User", value: String(format: "%.1f%%", cpu.userUsage))
                        MetricItem(label: "System", value: String(format: "%.1f%%", cpu.systemUsage))
                        MetricItem(label: "Idle", value: String(format: "%.1f%%", cpu.idleUsage))
                    }
                    
                    // Core count and load
                    HStack {
                        Label("\(cpu.coreCount) Cores", systemImage: "square.grid.3x3")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Load: \(String(format: "%.2f", cpu.loadAverage.one))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Memory Card
    
    private var memoryCard: some View {
        MetricCard(title: "Memory", icon: "memorychip", color: .orange) {
            if let memory = systemMetrics.memoryMetrics {
                VStack(spacing: 16) {
                    // Main gauge
                    CircularGauge(
                        value: memory.usedPercentage,
                        maxValue: 100,
                        color: pressureColor(memory.pressureLevel),
                        label: "\(Int(memory.usedPercentage))%"
                    )
                    .frame(height: 120)
                    
                    // Memory breakdown bar
                    MemoryBreakdownBar(memory: memory)
                    
                    // Details
                    HStack(spacing: 12) {
                        MetricItem(label: "Used", value: SystemMetricsService.formatBytes(memory.usedRAM))
                        MetricItem(label: "Free", value: SystemMetricsService.formatBytes(memory.freeRAM))
                        MetricItem(label: "Total", value: SystemMetricsService.formatBytes(memory.totalRAM))
                    }
                    
                    // Pressure and swap
                    HStack {
                        PressureBadge(level: memory.pressureLevel)
                        
                        Spacer()
                        
                        if memory.swapUsed > 0 {
                            Text("Swap: \(SystemMetricsService.formatBytes(memory.swapUsed))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Disk Card
    
    private var diskCard: some View {
        MetricCard(title: "Disk", icon: "internaldrive", color: .green) {
            if let disk = systemMetrics.diskMetrics {
                VStack(spacing: 16) {
                    // Usage bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(disk.usedPercentage))% Used")
                                .font(.headline)
                            Spacer()
                            Text(disk.fileSystem)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.2))
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(diskColor(disk.usedPercentage))
                                    .frame(width: geometry.size.width * (disk.usedPercentage / 100))
                            }
                        }
                        .frame(height: 24)
                    }
                    
                    Divider()
                    
                    // Space details
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(SystemMetricsService.formatBytes(disk.usedSpace))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Free")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(SystemMetricsService.formatBytes(disk.freeSpace))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(SystemMetricsService.formatBytes(disk.totalSpace))
                                .font(.headline)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Network Card
    
    private var networkCard: some View {
        MetricCard(title: "Network", icon: "network", color: .purple) {
            if let network = systemMetrics.networkMetrics {
                VStack(spacing: 16) {
                    // Speed indicators
                    HStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            Text(SystemMetricsService.formatBytesPerSecond(network.bytesInPerSecond))
                                .font(.headline)
                            Text("Download")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text(SystemMetricsService.formatBytesPerSecond(network.bytesOutPerSecond))
                                .font(.headline)
                            Text("Upload")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Total traffic
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Received")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(SystemMetricsService.formatBytes(network.bytesIn))
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total Sent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(SystemMetricsService.formatBytes(network.bytesOut))
                                .font(.caption)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Top Processes Card
    
    private var topProcessesCard: some View {
        MetricCard(title: "Top Processes", icon: "list.number", color: .cyan) {
            let topProcesses = Array(processManager.processes
                .sorted { $0.memoryUsage > $1.memoryUsage }
                .prefix(5))
            
            if topProcesses.isEmpty {
                Text("Loading processes...")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(topProcesses) { process in
                        HStack {
                            if let bundleId = process.bundleIdentifier,
                               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
                               let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 20, height: 20)
                            }
                            
                            Text(process.name)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(process.formattedMemoryUsage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    
    // MARK: - System Info Card
    
    private var systemInfoCard: some View {
        MetricCard(title: "System Info", icon: "desktopcomputer", color: .gray) {
            VStack(alignment: .leading, spacing: 12) {
                if let snapshot = systemMetrics.getSnapshot() {
                    InfoRow(label: "Uptime", value: SystemMetricsService.formatUptime(snapshot.uptime))
                }
                
                InfoRow(label: "macOS", value: Foundation.ProcessInfo.processInfo.operatingSystemVersionString)
                
                InfoRow(label: "Processor", value: "Apple Silicon")
                
                if let cpu = systemMetrics.cpuMetrics {
                    InfoRow(label: "CPU Cores", value: "\(cpu.coreCount)")
                }
                
                if let memory = systemMetrics.memoryMetrics {
                    InfoRow(label: "Total RAM", value: SystemMetricsService.formatBytes(memory.totalRAM))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<60: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
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

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct CircularGauge: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let label: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 12)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(value / maxValue, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: value)
            
            Text(label)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
}

struct MetricItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MemoryBreakdownBar: View {
    let memory: MemoryMetrics
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                // App Memory (Active)
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: segmentWidth(for: memory.activeRAM, in: geometry))
                
                // Wired
                Rectangle()
                    .fill(Color.red)
                    .frame(width: segmentWidth(for: memory.wiredRAM, in: geometry))
                
                // Compressed
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: segmentWidth(for: memory.compressedRAM, in: geometry))
                
                // Cached
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: segmentWidth(for: memory.cachedFiles, in: geometry))
                
                // Free
                Rectangle()
                    .fill(Color.green.opacity(0.3))
            }
            .cornerRadius(4)
        }
        .frame(height: 8)
    }
    
    private func segmentWidth(for bytes: UInt64, in geometry: GeometryProxy) -> CGFloat {
        let percentage = Double(bytes) / Double(memory.totalRAM)
        return geometry.size.width * CGFloat(percentage)
    }
}

struct PressureBadge: View {
    let level: MemoryPressureLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(level.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var color: Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

struct HealthIndicator: View {
    let level: MemoryPressureLevel
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("System Health")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(level.rawValue)
                    .font(.headline)
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var color: Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    private var iconName: String {
        switch level {
        case .normal: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .critical: return "xmark.shield.fill"
        }
    }
}

struct InfoRow: View {
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

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(SystemMetricsService())
        .environmentObject(ProcessManager())
        .frame(width: 800, height: 700)
}
