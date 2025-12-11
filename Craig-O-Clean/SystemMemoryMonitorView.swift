import SwiftUI
import Charts

struct SystemMemoryMonitorView: View {
    @ObservedObject var memoryManager: SystemMemoryManager
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
                        
                        Text("System Memory Monitor")
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Current Stats
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .foregroundColor(memoryColor(memoryManager.memoryPercentage))
                        Text(String(format: "%.1f GB Used", memoryManager.usedMemory))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(memoryColor(memoryManager.memoryPercentage))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gauge")
                            .foregroundColor(pressureColor(memoryManager.memoryPressure))
                        Text(memoryManager.memoryPressure)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            if isExpanded {
                Divider()
                
                // History Chart
                if !memoryManager.memoryHistory.isEmpty {
                    Chart(memoryManager.memoryHistory) { point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Usage", point.percentage)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [memoryColor(memoryManager.memoryPercentage).opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Usage", point.percentage)
                        )
                        .foregroundStyle(memoryColor(memoryManager.memoryPercentage))
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
                } else {
                     Text("Collecting data...")
                        .padding()
                        .frame(height: 150)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func memoryColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<50: return .green
        case 50..<75: return .orange
        default: return .red
        }
    }
    
    private func pressureColor(_ pressure: String) -> Color {
        switch pressure {
        case "Normal": return .green
        case "Moderate": return .orange
        default: return .red
        }
    }
}
