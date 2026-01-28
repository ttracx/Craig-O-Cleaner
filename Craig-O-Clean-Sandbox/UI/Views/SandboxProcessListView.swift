// MARK: - SandboxProcessListView.swift
// Craig-O-Clean Sandbox Edition - Process List View
// Displays running processes with safe termination options

import SwiftUI

struct SandboxProcessListView: View {
    @EnvironmentObject var processManager: SandboxProcessManager

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .memory
    @State private var showingConfirmation = false
    @State private var processToTerminate: SandboxProcessInfo?
    @State private var terminationResult: TerminationResult?
    @State private var showingResult = false

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case memory = "Memory"
        case cpu = "CPU"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView

            Divider()

            // Process List
            if processManager.isLoading && processManager.processes.isEmpty {
                loadingView
            } else if filteredProcesses.isEmpty {
                emptyView
            } else {
                processListView
            }
        }
        .navigationTitle("Running Processes")
        .alert("Terminate Process", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                Task {
                    await terminateProcess(force: false)
                }
            }
            Button("Force Quit", role: .destructive) {
                Task {
                    await terminateProcess(force: true)
                }
            }
        } message: {
            if let process = processToTerminate {
                Text("Are you sure you want to quit \"\(process.name)\"?\n\nAny unsaved work may be lost.")
            }
        }
        .alert("Result", isPresented: $showingResult) {
            Button("OK") { }
        } message: {
            if let result = terminationResult {
                Text(result.message)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search processes...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)

            Spacer()

            // Sort Picker
            Picker("Sort by", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Refresh Button
            Button {
                processManager.updateProcessList()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh process list")
        }
        .padding()
    }

    // MARK: - Process List

    private var processListView: some View {
        List {
            // Header
            HStack {
                Text("Process")
                    .fontWeight(.semibold)
                Spacer()
                Text("CPU")
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .trailing)
                Text("Memory")
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .trailing)
                Text("Actions")
                    .fontWeight(.semibold)
                    .frame(width: 100, alignment: .center)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)

            ForEach(filteredProcesses) { process in
                ProcessRowView(
                    process: process,
                    onTerminate: {
                        processToTerminate = process
                        showingConfirmation = true
                    }
                )
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading processes...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No processes found")
                .font(.headline)
            Text("Try adjusting your search")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredProcesses: [SandboxProcessInfo] {
        var processes = processManager.processes

        // Filter by search
        if !searchText.isEmpty {
            processes = processes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Sort
        switch sortOrder {
        case .name:
            processes.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .memory:
            processes.sort { $0.memoryUsage > $1.memoryUsage }
        case .cpu:
            processes.sort { $0.cpuUsage > $1.cpuUsage }
        }

        return processes
    }

    // MARK: - Actions

    private func terminateProcess(force: Bool) async {
        guard let process = processToTerminate else { return }

        let result: TerminationResult
        if force {
            result = await processManager.forceQuitApp(process)
        } else {
            result = await processManager.quitApp(process)
        }

        terminationResult = result
        showingResult = true
        processToTerminate = nil

        // Refresh list
        processManager.updateProcessList()
    }
}

// MARK: - Process Row View

struct ProcessRowView: View {
    let process: SandboxProcessInfo
    let onTerminate: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            // Icon and Name
            HStack(spacing: 10) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: process.isUserApp ? "app.fill" : "gearshape.fill")
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .lineLimit(1)

                    if let bundleId = process.bundleIdentifier {
                        Text(bundleId)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // CPU Usage
            Text(process.formattedCPUUsage)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(cpuColor)
                .frame(width: 60, alignment: .trailing)

            // Memory Usage
            Text(process.formattedMemoryUsage)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(memoryColor)
                .frame(width: 80, alignment: .trailing)

            // Actions
            HStack(spacing: 8) {
                Button {
                    onTerminate()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Quit \(process.name)")
            }
            .frame(width: 100, alignment: .center)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var cpuColor: Color {
        if process.cpuUsage > 50 { return .red }
        if process.cpuUsage > 25 { return .orange }
        return .primary
    }

    private var memoryColor: Color {
        if process.memoryUsage > 1_000_000_000 { return .red }  // > 1 GB
        if process.memoryUsage > 500_000_000 { return .orange } // > 500 MB
        return .primary
    }
}

// MARK: - Preview

#Preview {
    SandboxProcessListView()
        .environmentObject(SandboxProcessManager())
        .frame(width: 800, height: 600)
}
