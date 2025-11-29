// MARK: - ProcessManagerView.swift
// CraigOClean Control Center - Process Manager View
// Lists and manages running applications and processes

import SwiftUI
import AppKit

// MARK: - Sort Options

enum ProcessSortOption: String, CaseIterable {
    case name = "Name"
    case cpu = "CPU Usage"
    case memory = "Memory"
    case pid = "Process ID"
}

// MARK: - Filter Options

enum ProcessFilterOption: String, CaseIterable {
    case all = "All Processes"
    case userApps = "User Apps"
    case system = "System Processes"
    case heavy = "Heavy (>100MB)"
}

struct ProcessManagerView: View {
    @EnvironmentObject var processManager: ProcessManager
    
    @State private var searchText = ""
    @State private var sortOption: ProcessSortOption = .memory
    @State private var sortAscending = false
    @State private var filterOption: ProcessFilterOption = .userApps
    @State private var selectedProcess: ProcessInfo?
    @State private var showingTerminateAlert = false
    @State private var showingForceQuitAlert = false
    @State private var showingProcessDetails = false
    @State private var processToTerminate: ProcessInfo?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var filteredAndSortedProcesses: [ProcessInfo] {
        var processes = processManager.processes
        
        // Apply filter
        switch filterOption {
        case .all:
            break
        case .userApps:
            processes = processes.filter { $0.isUserProcess }
        case .system:
            processes = processes.filter { !$0.isUserProcess }
        case .heavy:
            processes = processes.filter { $0.memoryUsage > 100 * 1024 * 1024 }
        }
        
        // Apply search
        if !searchText.isEmpty {
            processes = processes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply sort
        processes.sort { lhs, rhs in
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = lhs.name.lowercased() < rhs.name.lowercased()
            case .cpu:
                comparison = lhs.cpuUsage > rhs.cpuUsage
            case .memory:
                comparison = lhs.memoryUsage > rhs.memoryUsage
            case .pid:
                comparison = lhs.id < rhs.id
            }
            return sortAscending ? !comparison : comparison
        }
        
        return processes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarSection
            
            Divider()
            
            // Process list
            processListSection
            
            Divider()
            
            // Footer stats
            footerSection
        }
        .navigationTitle("Processes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    processManager.updateProcessList()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                
                Button {
                    exportProcessList()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .alert("Terminate Process", isPresented: $showingTerminateAlert, presenting: processToTerminate) { process in
            Button("Cancel", role: .cancel) { }
            Button("Terminate", role: .destructive) {
                Task {
                    await terminateProcess(process)
                }
            }
        } message: { process in
            Text("Are you sure you want to terminate '\(process.name)'? Unsaved data may be lost.")
        }
        .alert("Force Quit Process", isPresented: $showingForceQuitAlert, presenting: processToTerminate) { process in
            Button("Cancel", role: .cancel) { }
            Button("Force Quit", role: .destructive) {
                Task {
                    await forceQuitProcess(process)
                }
            }
        } message: { process in
            VStack {
                Text("Are you sure you want to force quit '\(process.name)'?")
                if isCriticalProcess(process) {
                    Text("⚠️ Warning: This appears to be a critical system process. Force quitting may cause system instability.")
                }
            }
        }
        .alert("Process Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingProcessDetails) {
            if let process = selectedProcess {
                ProcessDetailsSheet(process: process, processManager: processManager)
            }
        }
    }
    
    // MARK: - Toolbar Section
    
    private var toolbarSection: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search processes...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 300)
            
            // Filter picker
            Picker("Filter", selection: $filterOption) {
                ForEach(ProcessFilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            
            // Sort picker
            Menu {
                ForEach(ProcessSortOption.allCases, id: \.self) { option in
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
            
            Spacer()
            
            // Process count
            Text("\(filteredAndSortedProcesses.count) processes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Process List Section
    
    private var processListSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 60)
                Text("CPU")
                    .frame(width: 70)
                Text("Memory")
                    .frame(width: 90)
                Text("Threads")
                    .frame(width: 60)
                Text("Actions")
                    .frame(width: 140)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Process rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredAndSortedProcesses) { process in
                        ProcessRowItem(
                            process: process,
                            isSelected: selectedProcess?.id == process.id,
                            onSelect: {
                                selectedProcess = process
                            },
                            onDoubleClick: {
                                selectedProcess = process
                                showingProcessDetails = true
                            },
                            onTerminate: {
                                processToTerminate = process
                                showingTerminateAlert = true
                            },
                            onForceQuit: {
                                processToTerminate = process
                                showingForceQuitAlert = true
                            }
                        )
                        
                        Divider()
                    }
                }
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            // Memory summary
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .foregroundColor(.orange)
                    Text("Total Memory: \(formatBytes(processManager.totalMemoryUsage))")
                        .font(.caption)
                }
                
                if let cpu = processManager.systemCPUInfo {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .foregroundColor(.blue)
                        Text("CPU: \(String(format: "%.1f%%", cpu.totalUsage))")
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            // Selected process info
            if let selected = selectedProcess {
                HStack(spacing: 8) {
                    Text("Selected: \(selected.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Details") {
                        showingProcessDetails = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func terminateProcess(_ process: ProcessInfo) async {
        let success = await processManager.terminateProcess(process)
        await MainActor.run {
            alertMessage = success ?
                "'\(process.name)' terminated successfully." :
                "Failed to terminate '\(process.name)'."
            showingAlert = true
            if success {
                selectedProcess = nil
            }
        }
    }
    
    private func forceQuitProcess(_ process: ProcessInfo) async {
        let success = await processManager.forceQuitProcess(process)
        await MainActor.run {
            alertMessage = success ?
                "'\(process.name)' force quit successfully." :
                "Failed to force quit '\(process.name)'."
            showingAlert = true
            if success {
                selectedProcess = nil
            }
        }
    }
    
    private func isCriticalProcess(_ process: ProcessInfo) -> Bool {
        let criticalNames = ["kernel_task", "launchd", "WindowServer", "loginwindow", "SystemUIServer", "Dock", "Finder"]
        return criticalNames.contains { process.name.contains($0) }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1024.0 / 1024.0 / 1024.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(bytes) / 1024.0 / 1024.0
            return String(format: "%.0f MB", mb)
        }
    }
    
    private func exportProcessList() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "processes_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvContent = "Process Name,PID,CPU %,Memory (MB),Bundle ID,User Process,Threads\n"
            
            for process in filteredAndSortedProcesses {
                let memoryMB = Double(process.memoryUsage) / 1024.0 / 1024.0
                let row = "\"\(process.name)\",\(process.id),\(String(format: "%.1f", process.cpuUsage)),\(String(format: "%.1f", memoryMB)),\"\(process.bundleIdentifier ?? "")\",\(process.isUserProcess),\(process.threads)\n"
                csvContent += row
            }
            
            try? csvContent.write(to: url, atomically: true, encoding: .utf8)
            
            alertMessage = "Process list exported to \(url.lastPathComponent)"
            showingAlert = true
        }
    }
}

// MARK: - Process Row Item

struct ProcessRowItem: View {
    let process: ProcessInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let onTerminate: () -> Void
    let onForceQuit: () -> Void
    
    @State private var isHovered = false
    
    var cpuColor: Color {
        switch process.cpuUsage {
        case 0..<20: return .green
        case 20..<50: return .yellow
        case 50..<80: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack {
            // Process icon and name
            HStack(spacing: 8) {
                if let bundleId = process.bundleIdentifier,
                   let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: process.isUserProcess ? "app" : "gear")
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(process.name)
                            .lineLimit(1)
                        
                        if process.cpuUsage > 80 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                    }
                    
                    if !process.isUserProcess {
                        Text("System Process")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // PID
            Text("\(process.id)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60)
            
            // CPU
            HStack(spacing: 4) {
                Circle()
                    .fill(cpuColor)
                    .frame(width: 8, height: 8)
                Text(String(format: "%.1f%%", process.cpuUsage))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(cpuColor)
            }
            .frame(width: 70)
            
            // Memory
            Text(process.formattedMemoryUsage)
                .font(.system(.body, design: .monospaced))
                .frame(width: 90)
            
            // Threads
            Text("\(process.threads)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60)
            
            // Actions
            HStack(spacing: 4) {
                Button("Quit") {
                    onTerminate()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    onForceQuit()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Force Quit")
            }
            .frame(width: 140)
            .opacity(isHovered ? 1.0 : 0.6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Group {
                if isSelected {
                    Color.accentColor.opacity(0.2)
                } else if isHovered {
                    Color.secondary.opacity(0.1)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Terminate") { onTerminate() }
            Button("Force Quit") { onForceQuit() }
            Divider()
            Button("Copy PID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(process.id)", forType: .string)
            }
            if let path = process.executablePath {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
            }
        }
    }
}

// MARK: - Process Details Sheet

struct ProcessDetailsSheet: View {
    let process: ProcessInfo
    let processManager: ProcessManager
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let bundleId = process.bundleIdentifier,
                   let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: process.isUserProcess ? "app" : "gear")
                        .font(.system(size: 36))
                        .frame(width: 48, height: 48)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("PID: \(process.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Details
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Resource Usage
                    GroupBox("Resource Usage") {
                        VStack(spacing: 12) {
                            DetailRow(label: "CPU Usage", value: String(format: "%.2f%%", process.cpuUsage))
                            DetailRow(label: "Memory", value: process.formattedMemoryUsage)
                            DetailRow(label: "Threads", value: "\(process.threads)")
                            DetailRow(label: "Ports", value: "\(process.ports)")
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Process Info
                    GroupBox("Process Information") {
                        VStack(spacing: 12) {
                            DetailRow(label: "Process ID", value: "\(process.id)")
                            if let parentPID = process.parentPID {
                                DetailRow(label: "Parent PID", value: "\(parentPID)")
                            }
                            DetailRow(label: "User ID", value: "\(process.uid)")
                            DetailRow(label: "Type", value: process.isUserProcess ? "User Application" : "System Process")
                            if let creationTime = process.creationTime {
                                DetailRow(label: "Started", value: creationTime.formatted())
                                DetailRow(label: "Running for", value: process.formattedAge)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Path Info
                    if let bundleId = process.bundleIdentifier {
                        GroupBox("Application") {
                            VStack(spacing: 12) {
                                DetailRow(label: "Bundle ID", value: bundleId)
                                if let path = process.executablePath {
                                    DetailRow(label: "Path", value: path)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Arguments
                    if !process.arguments.isEmpty {
                        GroupBox("Launch Arguments") {
                            ScrollView(.horizontal) {
                                Text(process.arguments.joined(separator: " "))
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Preview

#Preview {
    ProcessManagerView()
        .environmentObject(ProcessManager())
        .frame(width: 900, height: 600)
}
