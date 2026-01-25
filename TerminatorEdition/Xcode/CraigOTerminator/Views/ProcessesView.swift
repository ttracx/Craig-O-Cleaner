import SwiftUI

struct ProcessesView: View {
    @EnvironmentObject var appState: AppState
    @State private var processes: [ProcessInfo] = []
    @State private var selectedProcess: ProcessInfo?
    @State private var sortOrder: SortOrder = .memory
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var showSystemProcesses = false

    enum SortOrder: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
        case name = "Name"
        case pid = "PID"
    }

    struct ProcessInfo: Identifiable, Hashable {
        let id: Int32  // PID
        let name: String
        let cpuPercent: Double
        let memoryMB: Double
        let user: String
        let isSystemProcess: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
            lhs.id == rhs.id
        }
    }

    var filteredProcesses: [ProcessInfo] {
        var result = processes

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
            result.sort { $0.id < $1.id }
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
                            await refreshProcesses()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
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
                if isRefreshing && processes.isEmpty {
                    VStack {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading processes...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if processes.isEmpty {
                    VStack {
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No processes found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Button("Refresh") {
                            Task { @MainActor in
                                await refreshProcesses()
                            }
                        }
                        .padding(.top)
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

                    let totalCPU = processes.reduce(0) { $0 + $1.cpuPercent }
                    let totalMem = processes.reduce(0) { $0 + $1.memoryMB }
                    Text("Total: \(String(format: "%.1f", totalCPU))% CPU, \(String(format: "%.0f", totalMem)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(minWidth: 500)

            // Process details
            if let process = selectedProcess {
                ProcessDetailView(process: process) {
                    Task { @MainActor in
                        await refreshProcesses()
                    }
                }
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
        .task {
            // Use yield to defer completely outside view update cycle
            await Task.yield()
            await Task.yield()
            await Task.yield() // Triple yield for extra safety with processes

            // Refresh processes in detached task
            Task.detached {
                await refreshProcesses()
            }
        }
    }

    private func refreshProcesses() async {
        // Check isRefreshing without touching @State
        let alreadyRefreshing = await MainActor.run { isRefreshing }
        guard !alreadyRefreshing else {
            print("ProcessesView: Already refreshing, skipping")
            return
        }

        print("ProcessesView: Starting refresh...")

        // Collect data off main actor
        let processArray = await Task.detached {
            let executor = CommandExecutor.shared

            // Execute ps command to get process list
            guard let result = try? await executor.execute("ps aux") else {
                print("ProcessesView: Failed to execute ps command")
                return [ProcessInfo]()
            }

            guard result.isSuccess else {
                print("ProcessesView: ps command failed")
                return [ProcessInfo]()
            }

            print("ProcessesView: Got output, processing \(result.output.components(separatedBy: "\n").count) lines")

            // Process the result
            var array: [ProcessInfo] = []
            let lines = result.output.components(separatedBy: "\n")

            for (index, line) in lines.enumerated() {
                // Skip header line
                if index == 0 { continue }

                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 11 else { continue }

                let user = String(parts[0])
                let pid = Int32(parts[1]) ?? 0
                let cpuPercent = Double(parts[2]) ?? 0
                let name = String(parts[10...].joined(separator: " ").split(separator: "/").last ?? "")
                    .trimmingCharacters(in: .whitespaces)

                // Calculate memory in MB (RSS is in KB on macOS)
                let memoryMB = (Double(parts[5]) ?? 0) / 1024

                let isSystem = user == "root" ||
                              user == "_windowserver" ||
                              user.hasPrefix("_") ||
                              name.hasPrefix("com.apple")

                array.append(ProcessInfo(
                    id: pid,
                    name: name.isEmpty ? "Unknown" : name,
                    cpuPercent: cpuPercent,
                    memoryMB: memoryMB,
                    user: user,
                    isSystemProcess: isSystem
                ))
            }

            print("ProcessesView: Processed \(array.count) processes")
            return array
        }.value

        // Use yield for proper deferral before state updates
        await Task.yield()
        await Task.yield()

        // Update ALL @State on main actor in one batch
        await MainActor.run {
            isRefreshing = true
            processes = processArray
        }

        // Yield before final update
        await Task.yield()

        await MainActor.run {
            isRefreshing = false
        }

        print("ProcessesView: Refresh complete")
    }
}

struct ProcessRow: View {
    let process: ProcessesView.ProcessInfo

    var body: some View {
        HStack {
            Text(process.name)
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)

            Text("\(process.id)")
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
    let process: ProcessesView.ProcessInfo
    let onAction: () -> Void
    @State private var processDetails: String = ""

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

                Text("PID: \(process.id)")
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
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("kill \(process.id)")

        try? await Task.sleep(nanoseconds: 500_000_000)
        onAction()
    }

    private func forceKillProcess() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("kill -9 \(process.id)")

        try? await Task.sleep(nanoseconds: 500_000_000)
        onAction()
    }

    private func openInActivityMonitor() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("open -a 'Activity Monitor'")
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
