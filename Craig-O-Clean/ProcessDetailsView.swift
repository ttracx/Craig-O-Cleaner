import SwiftUI
import Charts

// MARK: - Process Details Model
struct ProcessDetails {
    let process: ProcessInfo
    let cpuHistory: [CPUUsageData]
    let networkConnections: [NetworkConnection]
    let openFiles: [String]
    let environmentVariables: [String: String]
}

struct NetworkConnection {
    let localAddress: String
    let localPort: Int
    let remoteAddress: String
    let remotePort: Int
    let state: String
    let protocolType: String
}

// MARK: - Process Details View
struct ProcessDetailsView: View {
    let processDetails: ProcessDetails
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with process info and close button
            HStack {
                Text("Process Details")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Header with process info
            ProcessDetailsHeaderView(process: processDetails.process)

            Divider()

            // Tab view
            TabView(selection: $selectedTab) {
                // Overview Tab
                ProcessOverviewView(processDetails: processDetails)
                    .tabItem {
                        Image(systemName: "info.circle")
                        Text("Overview")
                    }
                    .tag(0)

                // CPU & Memory Tab
                ProcessPerformanceView(processDetails: processDetails)
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Performance")
                    }
                    .tag(1)

                // Network Tab
                ProcessNetworkView(processDetails: processDetails)
                    .tabItem {
                        Image(systemName: "network")
                        Text("Network")
                    }
                    .tag(2)

                // Files Tab
                ProcessFilesView(processDetails: processDetails)
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("Files")
                    }
                    .tag(3)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Process Details Header
struct ProcessDetailsHeaderView: View {
    let process: ProcessInfo
    
    var body: some View {
        HStack(spacing: 16) {
            // Process icon
            Group {
                if let bundleIdentifier = process.bundleIdentifier,
                   let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                } else {
                    Image(systemName: "gear")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                        .frame(width: 64, height: 64)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(process.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("PID: \(process.pid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let bundleIdentifier = process.bundleIdentifier {
                    Text(bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Running for: \(process.formattedAge)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Current stats
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Text("CPU:")
                    Text(process.formattedCPUUsage)
                        .fontWeight(.semibold)
                        .foregroundColor(cpuUsageColor(process.cpuUsage))
                }
                
                HStack {
                    Text("Memory:")
                    Text(process.formattedMemoryUsage)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Threads:")
                    Text("\(process.threads)")
                        .fontWeight(.semibold)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func cpuUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<20:
            return .green
        case 20..<50:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Process Overview Tab
struct ProcessOverviewView: View {
    let processDetails: ProcessDetails
    
    var process: ProcessInfo { processDetails.process }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Basic Information Section
                GroupBox("Basic Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProcessInfoRow(label: "Process Name", value: process.name)
                        ProcessInfoRow(label: "Process ID", value: "\(process.pid)")
                        ProcessInfoRow(label: "Parent PID", value: process.parentPID != nil ? "\(process.parentPID!)" : "Unknown")
                        ProcessInfoRow(label: "User ID", value: "\(process.uid)")
                        ProcessInfoRow(label: "Process Type", value: process.isUserProcess ? "User Application" : "System Process")
                        
                        if let bundleId = process.bundleIdentifier {
                            ProcessInfoRow(label: "Bundle ID", value: bundleId)
                        }
                        
                        if let creationTime = process.creationTime {
                            ProcessInfoRow(label: "Started", value: DateFormatter.localizedString(from: creationTime, dateStyle: .medium, timeStyle: .medium))
                        }
                    }
                }
                
                // Executable Information Section
                if let executablePath = process.executablePath {
                    GroupBox("Executable") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProcessInfoRow(label: "Path", value: executablePath)
                            
                            if let workingDir = process.workingDirectory {
                                ProcessInfoRow(label: "Working Directory", value: workingDir)
                            }
                        }
                    }
                }
                
                // Arguments Section
                if !process.arguments.isEmpty {
                    GroupBox("Command Line Arguments") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(process.arguments.enumerated()), id: \.offset) { index, arg in
                                HStack {
                                    Text("[\(index)]")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(arg)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                
                // Resource Usage Section
                GroupBox("Resource Usage") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProcessInfoRow(label: "CPU Usage", value: process.formattedCPUUsage)
                        ProcessInfoRow(label: "Memory Usage", value: process.formattedMemoryUsage)
                        ProcessInfoRow(label: "Thread Count", value: "\(process.threads)")
                        ProcessInfoRow(label: "Port Count", value: "\(process.ports)")
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Process Performance Tab with Charts
struct ProcessPerformanceView: View {
    let processDetails: ProcessDetails
    @State private var selectedTimeRange = TimeRange.oneMinute
    
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
    
    var filteredCPUHistory: [CPUUsageData] {
        let cutoffTime = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return processDetails.cpuHistory.filter { $0.timestamp >= cutoffTime }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Time range picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // CPU Usage Chart
            GroupBox("CPU Usage History") {
                if !filteredCPUHistory.isEmpty {
                    Chart(filteredCPUHistory, id: \.timestamp) { data in
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("CPU %", data.usage)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
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
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .second, count: Int(selectedTimeRange.seconds / 6))) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute().second())
                        }
                    }
                    .frame(height: 200)
                } else {
                    Text("No CPU history data available")
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                }
            }
            
            // Current Performance Metrics
            GroupBox("Current Performance") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ProcessMetricCard(
                        title: "CPU Usage",
                        value: processDetails.process.formattedCPUUsage,
                        color: cpuUsageColor(processDetails.process.cpuUsage),
                        icon: "cpu"
                    )

                    ProcessMetricCard(
                        title: "Memory",
                        value: processDetails.process.formattedMemoryUsage,
                        color: .blue,
                        icon: "memorychip"
                    )

                    ProcessMetricCard(
                        title: "Threads",
                        value: "\(processDetails.process.threads)",
                        color: .green,
                        icon: "arrow.branch"
                    )

                    ProcessMetricCard(
                        title: "Age",
                        value: processDetails.process.formattedAge,
                        color: .orange,
                        icon: "clock"
                    )
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func cpuUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<20: return .green
        case 20..<50: return .orange
        default: return .red
        }
    }
}

// MARK: - Process Network Tab
struct ProcessNetworkView: View {
    let processDetails: ProcessDetails
    
    var body: some View {
        VStack {
            if processDetails.networkConnections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Network Connections")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("This process doesn't have any active network connections.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(processDetails.networkConnections, id: \.localPort) { connection in
                    NetworkConnectionRow(connection: connection)
                }
            }
        }
        .padding()
    }
}

// MARK: - Process Files Tab
struct ProcessFilesView: View {
    let processDetails: ProcessDetails
    
    var body: some View {
        VStack {
            if processDetails.openFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Open Files")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Unable to determine open files for this process.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(processDetails.openFiles, id: \.self) { file in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundColor(.secondary)
                        
                        Text(file)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
    }
}

// MARK: - Helper Views
struct ProcessInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(minWidth: 120, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
                .foregroundColor(.secondary)

            Spacer()
        }
        .font(.caption)
    }
}

struct ProcessMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct NetworkConnectionRow: View {
    let connection: NetworkConnection
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(connection.protocolType.uppercased()) Connection")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(connection.localAddress):\(connection.localPort) → \(connection.remoteAddress):\(connection.remotePort)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(connection.state)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(stateColor(connection.state).opacity(0.2))
                .foregroundColor(stateColor(connection.state))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    private func stateColor(_ state: String) -> Color {
        switch state.uppercased() {
        case "ESTABLISHED":
            return .green
        case "LISTEN":
            return .blue
        case "TIME_WAIT", "CLOSE_WAIT":
            return .orange
        default:
            return .secondary
        }
    }
}

#Preview {
    ProcessDetailsView(processDetails: ProcessDetails(
        process: ProcessInfo(
            pid: 1234,
            name: "Sample App",
            bundleIdentifier: "com.example.app",
            cpuUsage: 15.5,
            memoryUsage: 512 * 1024 * 1024,
            creationTime: Date().addingTimeInterval(-3600),
            threads: 8,
            arguments: ["./app", "--verbose", "--config=/path/to/config"]
        ),
        cpuHistory: [],
        networkConnections: [],
        openFiles: [],
        environmentVariables: [:]
    ))
}