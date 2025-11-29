// DashboardView.swift
// ClearMind Control Center
//
// Main dashboard showing system health, CPU, memory, disk, and network metrics
// Card-based layout with real-time updates

import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var metricsService = SystemMetricsService()
    @State private var selectedTimeRange: TimeRange = .oneMinute
    
    enum TimeRange: String, CaseIterable {
        case thirtySeconds = "30s"
        case oneMinute = "1m"
        case fiveMinutes = "5m"
        
        var seconds: TimeInterval {
            switch self {
            case .thirtySeconds: return 30
            case .oneMinute: return 60
            case .fiveMinutes: return 300
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Health Summary Card
                systemHealthCard
                
                // Main Metrics Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // CPU Card
                    cpuCard
                    
                    // Memory Card
                    memoryCard
                    
                    // Disk Card
                    diskCard
                    
                    // Network Card
                    networkCard
                }
                
                // CPU History Chart
                cpuHistoryChart
                
                // Memory History Chart
                memoryHistoryChart
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - System Health Card
    
    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: healthIcon)
                    .font(.title)
                    .foregroundColor(healthColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Health")
                        .font(.headline)
                    
                    Text(healthStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Last updated
                if metricsService.isUpdating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button {
                        metricsService.updateAllMetrics()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Quick stats
            HStack(spacing: 24) {
                QuickStatView(
                    title: "CPU",
                    value: cpuUsageString,
                    color: cpuColor
                )
                
                Divider()
                    .frame(height: 40)
                
                QuickStatView(
                    title: "Memory",
                    value: memoryUsageString,
                    color: memoryColor
                )
                
                Divider()
                    .frame(height: 40)
                
                QuickStatView(
                    title: "Disk",
                    value: diskUsageString,
                    color: diskColor
                )
                
                if let network = metricsService.networkMetrics {
                    Divider()
                        .frame(height: 40)
                    
                    QuickStatView(
                        title: "Network",
                        value: "↓ \(network.receiveRateFormatted)",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - CPU Card
    
    private var cpuCard: some View {
        MetricCard(
            title: "CPU Usage",
            icon: "cpu",
            iconColor: cpuColor
        ) {
            if let cpu = metricsService.cpuMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    // Overall usage
                    HStack {
                        Text(String(format: "%.1f%%", cpu.overallUsage))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(cpuColor)
                        
                        Spacer()
                        
                        // Load averages
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Load Average")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f, %.2f, %.2f",
                                       cpu.loadAverage.one,
                                       cpu.loadAverage.five,
                                       cpu.loadAverage.fifteen))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // User/System breakdown
                    HStack {
                        VStack(alignment: .leading) {
                            Text("User")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", cpu.userUsage))
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text("System")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", cpu.systemUsage))
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Idle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", cpu.idlePercentage))
                                .font(.caption)
                        }
                    }
                    
                    // Core count
                    Text("\(cpu.coreCount) cores")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Memory Card
    
    private var memoryCard: some View {
        MetricCard(
            title: "Memory Usage",
            icon: "memorychip",
            iconColor: memoryColor
        ) {
            if let memory = metricsService.memoryMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    // Used/Total
                    HStack(alignment: .bottom) {
                        Text(memory.usedFormatted)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(memoryColor)
                        
                        Text("/ \(memory.totalFormatted)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(memoryColor)
                                .frame(width: geometry.size.width * CGFloat(memory.usedPercentage / 100))
                        }
                    }
                    .frame(height: 8)
                    
                    // Memory breakdown
                    HStack {
                        MemoryTypeView(label: "Active", value: memory.activeFormatted, color: .blue)
                        MemoryTypeView(label: "Wired", value: memory.wiredFormatted, color: .orange)
                        MemoryTypeView(label: "Compressed", value: memory.compressedFormatted, color: .purple)
                    }
                    
                    // Pressure indicator
                    HStack {
                        Image(systemName: memory.memoryPressure.icon)
                            .foregroundColor(pressureColor(memory.memoryPressure))
                        Text("Pressure: \(memory.memoryPressure.rawValue)")
                            .font(.caption)
                            .foregroundColor(pressureColor(memory.memoryPressure))
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Disk Card
    
    private var diskCard: some View {
        MetricCard(
            title: "Disk Usage",
            icon: "internaldrive",
            iconColor: diskColor
        ) {
            if let disk = metricsService.diskMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    // Used/Total
                    HStack(alignment: .bottom) {
                        Text(disk.usedFormatted)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(diskColor)
                        
                        Text("/ \(disk.totalFormatted)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(diskColor)
                                .frame(width: geometry.size.width * CGFloat(disk.usedPercentage / 100))
                        }
                    }
                    .frame(height: 8)
                    
                    // Free space
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("\(disk.freeFormatted) available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Volume name
                    Text(disk.volumeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Network Card
    
    private var networkCard: some View {
        MetricCard(
            title: "Network Activity",
            icon: "network",
            iconColor: .blue
        ) {
            if let network = metricsService.networkMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    // Download rate
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Download")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(network.receiveRateFormatted)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Upload")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(network.sendRateFormatted)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Divider()
                    
                    // Total data
                    HStack {
                        Text("Total Received:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(network.bytesReceived))
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Total Sent:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(network.bytesSent))
                            .font(.caption)
                    }
                }
            } else {
                Text("Network data unavailable")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - CPU History Chart
    
    private var cpuHistoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("CPU History")
                    .font(.headline)
                
                Spacer()
                
                Picker("Time", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            if !filteredCPUHistory.isEmpty {
                Chart(filteredCPUHistory) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.usage)
                    )
                    .foregroundStyle(.blue.gradient)
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.usage)
                    )
                    .foregroundStyle(.blue.opacity(0.1).gradient)
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 150)
            } else {
                Text("Collecting data...")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Memory History Chart
    
    private var memoryHistoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                Text("Memory History")
                    .font(.headline)
                
                Spacer()
            }
            
            if !filteredMemoryHistory.isEmpty {
                Chart(filteredMemoryHistory) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.usedPercentage)
                    )
                    .foregroundStyle(.orange.gradient)
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.usedPercentage)
                    )
                    .foregroundStyle(.orange.opacity(0.1).gradient)
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 150)
            } else {
                Text("Collecting data...")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Filtered History
    
    private var filteredCPUHistory: [CPUHistoryPoint] {
        let cutoff = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return metricsService.cpuHistory.filter { $0.timestamp >= cutoff }
    }
    
    private var filteredMemoryHistory: [MemoryHistoryPoint] {
        let cutoff = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return metricsService.memoryHistory.filter { $0.timestamp >= cutoff }
    }
    
    // MARK: - Computed Properties
    
    private var healthIcon: String {
        metricsService.healthSummary?.overallHealth.icon ?? "heart"
    }
    
    private var healthColor: Color {
        guard let health = metricsService.healthSummary?.overallHealth else { return .gray }
        switch health {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private var healthStatus: String {
        metricsService.healthSummary?.overallHealth.rawValue ?? "Loading..."
    }
    
    private var cpuUsageString: String {
        guard let cpu = metricsService.cpuMetrics else { return "--" }
        return String(format: "%.1f%%", cpu.overallUsage)
    }
    
    private var cpuColor: Color {
        guard let cpu = metricsService.cpuMetrics else { return .gray }
        switch cpu.cpuPressure {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private var memoryUsageString: String {
        guard let memory = metricsService.memoryMetrics else { return "--" }
        return String(format: "%.1f%%", memory.usedPercentage)
    }
    
    private var memoryColor: Color {
        guard let memory = metricsService.memoryMetrics else { return .gray }
        return pressureColor(memory.memoryPressure)
    }
    
    private var diskUsageString: String {
        guard let disk = metricsService.diskMetrics else { return "--" }
        return String(format: "%.1f%%", disk.usedPercentage)
    }
    
    private var diskColor: Color {
        guard let disk = metricsService.diskMetrics else { return .gray }
        if disk.usedPercentage < 70 { return .green }
        else if disk.usedPercentage < 85 { return .orange }
        else { return .red }
    }
    
    private func pressureColor(_ pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1024 {
            return String(format: "%.1f TB", gb / 1024)
        } else if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            return String(format: "%.0f MB", Double(bytes) / 1_048_576.0)
        }
    }
}

// MARK: - Supporting Views

struct QuickStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MemoryTypeView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.caption)
        }
    }
}

#Preview {
    DashboardView()
        .frame(width: 800, height: 800)
}
