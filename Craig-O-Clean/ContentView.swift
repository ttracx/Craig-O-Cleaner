import SwiftUI
import AppKit

enum SortOption: String, CaseIterable {
    case name = "Name"
    case cpu = "CPU Usage"
    case memory = "Memory"
    case pid = "Process ID"
}

struct ContentView: View {
    @StateObject private var processManager = ProcessManager()
    @StateObject private var systemMemoryManager = SystemMemoryManager()
    @State private var selectedProcess: ProcessInfo?
    @State private var searchText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showOnlyUserProcesses = true
    @State private var showProcessDetails = false
    @State private var processToTerminate: ProcessInfo?
    @State private var showTerminateConfirmation = false
    @State private var terminationAction: (() async -> Void)?
    @State private var sortOption: SortOption = .cpu
    @State private var sortAscending = false
    @State private var groupByType = false
    @State private var showHeavyProcessesOnly = false

    var filteredProcesses: [ProcessInfo] {
        var processes = processManager.processes
        
        if showOnlyUserProcesses {
            processes = processes.filter { $0.isUserProcess }
        }
        
        if showHeavyProcessesOnly {
            processes = processes.filter { $0.memoryUsage > 500 * 1024 * 1024 }
        }

        let searched = searchText.isEmpty ? processes : processes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) == true
        }

        return sortedProcesses(searched)
    }

    func sortedProcesses(_ processes: [ProcessInfo]) -> [ProcessInfo] {
        let sorted = processes.sorted { lhs, rhs in
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = lhs.name.lowercased() < rhs.name.lowercased()
            case .cpu:
                comparison = lhs.cpuUsage > rhs.cpuUsage
            case .memory:
                comparison = lhs.memoryUsage > rhs.memoryUsage
            case .pid:
                comparison = lhs.pid < rhs.pid
            }
            return sortAscending ? !comparison : comparison
        }
        return sorted
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                TextField("Search processes...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 300)

                Spacer()

                // Sort controls
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            if sortOption == option {
                                sortAscending.toggle()
                            } else {
                                sortOption = option
                                sortAscending = false
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sort: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)

                Toggle("Group by Type", isOn: $groupByType)

                Toggle("User Processes Only", isOn: $showOnlyUserProcesses)
                
                Toggle("Heavy Only", isOn: $showHeavyProcessesOnly)

                Button("Export...") {
                    exportProcessList()
                }
                .buttonStyle(.bordered)

                Button("Refresh") {
                    processManager.updateProcessList()
                }
                .buttonStyle(.borderedProminent)

                if processManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // System CPU Monitor
            SystemCPUMonitorView(processManager: processManager)

            Divider()

            // System Memory Monitor
            SystemMemoryMonitorView(memoryManager: systemMemoryManager)

            Divider()

            // Process list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Process Name")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("PID")
                        .font(.headline)
                        .frame(width: 60, alignment: .center)

                    Text("CPU %")
                        .font(.headline)
                        .frame(width: 80, alignment: .trailing)

                    Text("Memory")
                        .font(.headline)
                        .frame(width: 100, alignment: .trailing)

                    Text("Bundle ID")
                        .font(.headline)
                        .frame(width: 180, alignment: .leading)

                    Text("Actions")
                        .font(.headline)
                        .frame(width: 140, alignment: .center)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Process rows
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if groupByType {
                            ForEach([true, false], id: \.self) { isUserProcess in
                                let groupedProcesses = filteredProcesses.filter { $0.isUserProcess == isUserProcess }
                                if !groupedProcesses.isEmpty {
                                    Section(header: GroupHeaderView(
                                        title: isUserProcess ? "User Applications" : "System Processes",
                                        count: groupedProcesses.count
                                    )) {
                                        ForEach(groupedProcesses) { process in
                                            ProcessRowView(
                                                process: process,
                                                isSelected: selectedProcess?.id == process.id,
                                                onSelect: {
                                                    selectedProcess = process
                                                    showProcessDetails = true
                                                },
                                                onTerminate: { confirmTerminate(process, force: false) },
                                                onForceQuit: { confirmTerminate(process, force: true) }
                                            )
                                            .background(selectedProcess?.id == process.id ?
                                                       Color.accentColor.opacity(0.2) : Color.clear)
                                        }
                                    }
                                }
                            }
                        } else {
                            ForEach(filteredProcesses) { process in
                                ProcessRowView(
                                    process: process,
                                    isSelected: selectedProcess?.id == process.id,
                                    onSelect: {
                                        selectedProcess = process
                                        showProcessDetails = true
                                    },
                                    onTerminate: { confirmTerminate(process, force: false) },
                                    onForceQuit: { confirmTerminate(process, force: true) }
                                )
                                .background(selectedProcess?.id == process.id ?
                                           Color.accentColor.opacity(0.2) : Color.clear)
                            }
                        }
                    }
                }
            }

            // Bottom status bar
            HStack {
                Text("\(filteredProcesses.count) processes")
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: 20)

                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("System CPU: \(String(format: "%.1f%%", processManager.totalCPUUsage))")
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 20)

                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .foregroundColor(.orange)
                    Text("Total Memory: \(formatBytes(processManager.totalMemoryUsage))")
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let selected = selectedProcess {
                    Text("Selected: \(selected.name) (PID: \(selected.pid))")
                        .foregroundColor(.secondary)
                    Button("Details") {
                        showProcessDetails = true
                    }
                    .buttonStyle(.link)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .alert("Process Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Confirm Termination", isPresented: $showTerminateConfirmation, presenting: processToTerminate) { process in
            Button("Cancel", role: .cancel) {
                processToTerminate = nil
                terminationAction = nil
            }
            Button(isCriticalProcess(process) ? "Force Terminate" : "Terminate", role: .destructive) {
                if let action = terminationAction {
                    Task {
                        await action()
                    }
                }
                processToTerminate = nil
                terminationAction = nil
            }
        } message: { process in
            VStack(alignment: .leading, spacing: 8) {
                Text("Are you sure you want to terminate '\(process.name)'?")
                if isCriticalProcess(process) {
                    Text("Warning: This appears to be a critical system process. Terminating it may cause system instability.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showProcessDetails) {
            if let process = selectedProcess {
                ProcessDetailsView(processDetails: processManager.getProcessDetails(for: process))
            }
        }
        .onAppear {
            processManager.updateProcessList()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1024.0 / 1024.0 / 1024.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(bytes) / 1024.0 / 1024.0
            return String(format: "%.1f MB", mb)
        }
    }

    private func isCriticalProcess(_ process: ProcessInfo) -> Bool {
        let criticalProcesses = [
            "kernel_task", "launchd", "WindowServer", "loginwindow",
            "SystemUIServer", "Dock", "Finder"
        ]
        return criticalProcesses.contains { process.name.contains($0) }
    }

    private func confirmTerminate(_ process: ProcessInfo, force: Bool) {
        processToTerminate = process
        if force {
            terminationAction = { await forceQuitProcess(process) }
        } else {
            terminationAction = { await terminateProcess(process) }
        }
        showTerminateConfirmation = true
    }

    private func exportProcessList() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "processes_\(Date().formatted(date: .numeric, time: .omitted)).csv"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            var csvContent = "Process Name,PID,CPU %,Memory (MB),Bundle ID,User Process,Threads\n"

            for process in filteredProcesses {
                let memoryMB = Double(process.memoryUsage) / 1024.0 / 1024.0
                let row = "\"\(process.name)\",\(process.pid),\(String(format: "%.1f", process.cpuUsage)),\(String(format: "%.1f", memoryMB)),\"\(process.bundleIdentifier ?? "")\",\(process.isUserProcess),\(process.threads)\n"
                csvContent += row
            }

            try? csvContent.write(to: url, atomically: true, encoding: .utf8)

            alertMessage = "Process list exported successfully to \(url.lastPathComponent)"
            showingAlert = true
        }
    }

    private func terminateProcess(_ process: ProcessInfo) async {
        let success = await processManager.terminateProcess(process)
        await MainActor.run {
            alertMessage = success ?
                "Process '\(process.name)' terminated successfully." :
                "Failed to terminate process '\(process.name)'."
            showingAlert = true

            if success {
                selectedProcess = nil
                processManager.updateProcessList()
            }
        }
    }

    private func forceQuitProcess(_ process: ProcessInfo) async {
        // First try standard force quit
        let success = await processManager.forceQuitProcess(process)

        if success {
            await MainActor.run {
                alertMessage = "Process '\(process.name)' force quit successfully."
                showingAlert = true
                selectedProcess = nil
                processManager.updateProcessList()
            }
        } else {
            // Standard method failed, try with admin privileges as fallback
            let adminSuccess = await processManager.forceQuitWithAdminPrivileges(process)

            await MainActor.run {
                if adminSuccess {
                    alertMessage = "Process '\(process.name)' force quit successfully using administrator privileges."
                    selectedProcess = nil
                    processManager.updateProcessList()
                } else {
                    alertMessage = "Failed to force quit process '\(process.name)' even with administrator privileges. The process may be protected by the system."
                }
                showingAlert = true
            }
        }
    }
}

struct ProcessRowView: View {
    let process: ProcessInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onTerminate: () -> Void
    let onForceQuit: () -> Void

    @State private var isHovered = false

    var cpuUsageColor: Color {
        switch process.cpuUsage {
        case 0..<20:
            return .green
        case 20..<50:
            return .yellow
        case 50..<80:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        HStack {
            // Process icon and name
            HStack {
                if let bundleIdentifier = process.bundleIdentifier,
                   let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "gear")
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(process.name)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)

                        if process.cpuUsage > 80 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    if !process.isUserProcess {
                        Text("System Process")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // PID
            Text("\(process.pid)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .center)

            // CPU usage with color indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(cpuUsageColor)
                    .frame(width: 8, height: 8)
                Text(String(format: "%.1f", process.cpuUsage))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(cpuUsageColor)
            }
            .frame(width: 80, alignment: .trailing)

            // Memory usage
            Text(String(format: "%.0f MB", Double(process.memoryUsage) / 1024.0 / 1024.0))
                .font(.system(.body, design: .monospaced))
                .frame(width: 100, alignment: .trailing)

            // Bundle ID
            Text(process.bundleIdentifier ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)

            // Action buttons
            HStack(spacing: 4) {
                Button("Quit") {
                    onTerminate()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Force Quit") {
                    onForceQuit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
            .frame(width: 140)
            .opacity(isHovered ? 1.0 : 0.6)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .background(
            Rectangle()
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
    }
}

struct GroupHeaderView: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(count) process\(count == 1 ? "" : "es")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 700)
}
