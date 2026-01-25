import SwiftUI

struct ProcessesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var processMonitor = ProcessMonitorService.shared
    @State private var selectedProcess: ProcessMonitorService.ProcessInfo?
    @State private var sortOrder: SortOrder = .memory
    @State private var searchText = ""
    @State private var showSystemProcesses = false

    enum SortOrder: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
        case name = "Name"
        case pid = "PID"
    }

    var filteredProcesses: [ProcessMonitorService.ProcessInfo] {
        var result = processMonitor.processes

        if !showSystemProcesses {
            result = result.filter { !$0.isSystemProcess }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOrder {
        case .cpu:
            result.sort { $0.cpuPercent > $1.cpuPercent }
        case .memory:
            result.sort { $0.memoryMB > $1.memoryMB }
        case .name:
            result.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .pid:
            result.sort { $0.pid < $1.pid }
        }

        return result
    }

    var body: some View {
        HSplitView {
            // Process list
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    TextField("Search processes...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)

                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    Toggle("System", isOn: $showSystemProcesses)
                        .toggleStyle(.checkbox)

                    Spacer()

                    Button {
                        Task { @MainActor in
                            await processMonitor.fetchProcesses()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!processMonitor.isMonitoring)
                }
                .padding()

                // List header
                HStack {
                    Text("Name")
                        .frame(width: 180, alignment: .leading)
                    Text("PID")
                        .frame(width: 60)
                    Text("CPU")
                        .frame(width: 60)
                    Text("Memory")
                        .frame(width: 80)
                    Text("User")
                        .frame(width: 80, alignment: .leading)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                Divider()

                // Process list
                if processMonitor.processes.isEmpty {
                    VStack {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading processes...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredProcesses, selection: $selectedProcess) { process in
                        ProcessRow(process: process)
                            .tag(process)
                    }
                    .listStyle(.plain)
                }

                // Footer
                HStack {
                    Text("\(filteredProcesses.count) processes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Total: \(String(format: "%.1f", processMonitor.cpuUsageTotal))% CPU, \(String(format: "%.1f", processMonitor.memoryUsageTotal))% Memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastUpdate = processMonitor.lastUpdateTime {
                        Text("• Updated \(timeAgo(lastUpdate))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }
            .frame(minWidth: 500)

            // Process details
            if let process = selectedProcess {
                ProcessDetailView(process: process, processMonitor: processMonitor)
            } else {
                VStack {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a process")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Processes")
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

struct ProcessRow: View {
    let process: ProcessMonitorService.ProcessInfo

    var body: some View {
        HStack {
            Text(process.name)
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .foregroundStyle(process.cpuPercent > 50 ? .red : (process.cpuPercent > 20 ? .orange : .primary))
                .frame(width: 60)

            Text(String(format: "%.0f MB", process.memoryMB))
                .foregroundStyle(process.memoryMB > 500 ? .red : (process.memoryMB > 200 ? .orange : .primary))
                .frame(width: 80)

            Text(process.user)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

struct ProcessDetailView: View {
    let process: ProcessMonitorService.ProcessInfo
    @ObservedObject var processMonitor: ProcessMonitorService
    @State private var isTerminating = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: process.isSystemProcess ? "gear" : "app")
                    .font(.system(size: 48))
                    .foregroundStyle(process.isSystemProcess ? .orange : .blue)

                Text(process.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("PID: \(process.pid)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Metrics
            HStack(spacing: 24) {
                MetricBox(title: "CPU", value: String(format: "%.1f%%", process.cpuPercent), color: process.cpuPercent > 50 ? .red : .blue)
                MetricBox(title: "Memory", value: String(format: "%.0f MB", process.memoryMB), color: process.memoryMB > 500 ? .red : .green)
                MetricBox(title: "User", value: process.user, color: .purple)
            }

            Divider()

            // Actions
            VStack(spacing: 12) {
                Text("Actions")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Button {
                        Task { @MainActor in
                            await terminateProcess()
                        }
                    } label: {
                        Label("Terminate", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTerminating)

                    Button {
                        Task { @MainActor in
                            await forceKillProcess()
                        }
                    } label: {
                        Label("Force Kill", systemImage: "bolt.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isTerminating)
                }

                if !process.isSystemProcess {
                    Button {
                        Task { @MainActor in
                            await openInActivityMonitor()
                        }
                    } label: {
                        Label("Open in Activity Monitor", systemImage: "gauge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            if process.isSystemProcess {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("System process - terminating may cause instability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 280)
    }

    private func terminateProcess() async {
        isTerminating = true
        defer { isTerminating = false }

        let result = await processMonitor.killProcess(pid: process.pid, force: false)

        switch result {
        case .success:
            print("ProcessDetailView: Process \(process.pid) terminated successfully")
        case .failure(let error):
            print("ProcessDetailView: Failed to terminate process \(process.pid): \(error)")
        }
    }

    private func forceKillProcess() async {
        isTerminating = true
        defer { isTerminating = false }

        let result = await processMonitor.killProcess(pid: process.pid, force: true)

        switch result {
        case .success:
            print("ProcessDetailView: Process \(process.pid) force killed successfully")
        case .failure(let error):
            print("ProcessDetailView: Failed to force kill process \(process.pid): \(error)")
        }
    }

    private func openInActivityMonitor() async {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Activity Monitor"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        try? task.run()
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ProcessesView()
        .environmentObject(AppState.shared)
        .frame(width: 900, height: 600)
}
