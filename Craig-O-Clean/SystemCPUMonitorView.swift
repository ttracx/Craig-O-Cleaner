import SwiftUI
import Charts

struct SystemCPUMonitorView: View {
    @ObservedObject var processManager: ProcessManager
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("System CPU Monitor")
                            .font(.headline)

                        if let cpuInfo = processManager.systemCPUInfo {
                            Text("(\(cpuInfo.coreCount) cores)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if let cpuInfo = processManager.systemCPUInfo {
                    HStack(spacing: 16) {
                        // Overall CPU
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .foregroundColor(cpuColor(cpuInfo.totalUsage))
                            Text("Overall: \(String(format: "%.1f%%", cpuInfo.totalUsage))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(cpuColor(cpuInfo.totalUsage))
                        }

                        // System Load
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                            Text("Load: \(String(format: "%.2f, %.2f, %.2f", cpuInfo.systemLoad.0, cpuInfo.systemLoad.1, cpuInfo.systemLoad.2))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            if isExpanded, processManager.systemCPUInfo != nil {
                Divider()

                // Per-core CPU usage
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(processManager.cpuCoreData) { core in
                            CPUCoreView(coreNumber: core.id, usage: core.usage)
                        }
                    }
                    .padding()
                }
                .frame(height: 120)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // CPU Usage Chart
                if processManager.cpuCoreData.count > 0 {
                    Chart(processManager.cpuCoreData) { core in
                        BarMark(
                            x: .value("Core", "Core \(core.id)"),
                            y: .value("Usage", core.usage)
                        )
                        .foregroundStyle(cpuColor(core.usage))
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
                    .padding()
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<25:
            return .green
        case 25..<50:
            return .yellow
        case 50..<75:
            return .orange
        default:
            return .red
        }
    }
}

struct CPUCoreView: View {
    let coreNumber: Int
    let usage: Double

    var usageColor: Color {
        switch usage {
        case 0..<25:
            return .green
        case 25..<50:
            return .yellow
        case 50..<75:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Core label
            Text("Core \(coreNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: usage / 100.0)
                    .stroke(usageColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: usage)

                VStack(spacing: 2) {
                    Text("\(Int(usage))%")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(usageColor)
                }
            }
        }
        .frame(width: 80)
    }
}

#Preview {
    SystemCPUMonitorView(processManager: ProcessManager())
        .frame(width: 800, height: 400)
}
