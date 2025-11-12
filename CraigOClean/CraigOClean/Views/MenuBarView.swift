//
//  MenuBarView.swift
//  Craig-O-Clean
//
//  Main menu bar view showing memory stats and process list
//

import SwiftUI

struct MenuBarView: View {
    @StateObject private var processMonitor = ProcessMonitor()
    @StateObject private var memoryManager = MemoryManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedProcess: ProcessInfo?
    @State private var showingForceQuitAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Memory Stats
            memoryStatsView
            
            Divider()
            
            // Process List
            processListView
            
            Divider()
            
            // Actions
            actionsView
        }
        .frame(width: 400, height: 500)
        .alert("Force Quit Application?", isPresented: $showingForceQuitAlert, presenting: selectedProcess) { process in
            Button("Cancel", role: .cancel) { }
            Button("Force Quit", role: .destructive) {
                processMonitor.forceQuitProcess(process)
            }
        } message: { process in
            Text("Are you sure you want to force quit '\(process.name)'? Any unsaved changes will be lost.")
        }
        .alert("Craig-O-Clean", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Craig-O-Clean")
                .font(.title2)
                .fontWeight(.bold)
            Text("Memory Management")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }
    
    private var memoryStatsView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f GB", processMonitor.totalMemoryGB))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f GB", processMonitor.totalMemoryUsageGB))
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f GB", processMonitor.availableMemoryGB))
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            
            // Memory usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * CGFloat(processMonitor.totalMemoryUsageGB / processMonitor.totalMemoryGB), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
            
            Text(String(format: "%.1f%% Memory Used", (processMonitor.totalMemoryUsageGB / processMonitor.totalMemoryGB) * 100))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }
    
    private var processListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Top Memory Users")
                    .font(.headline)
                Spacer()
                Text("\(processMonitor.processes.count) apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(processMonitor.processes) { process in
                        ProcessRowView(process: process) {
                            selectedProcess = process
                            showingForceQuitAlert = true
                        }
                        Divider()
                    }
                }
            }
        }
    }
    
    private var actionsView: some View {
        VStack(spacing: 12) {
            if !memoryManager.purgeStatus.isEmpty {
                Text(memoryManager.purgeStatus)
                    .font(.caption)
                    .foregroundColor(memoryManager.purgeStatus.contains("Failed") ? .red : .green)
            }
            
            Button(action: executePurge) {
                HStack {
                    if memoryManager.isPurging {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                    }
                    Text(memoryManager.isPurging ? "Purging..." : "Purge Memory")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(memoryManager.isPurging)
            .padding(.horizontal)
            
            if let lastPurge = memoryManager.lastPurgeTime {
                Text("Last purge: \(formatLastPurgeTime(lastPurge))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button("Quit Craig-O-Clean") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding(.vertical, 12)
    }
    
    private func executePurge() {
        memoryManager.executePurge { success, message in
            if !success {
                alertMessage = message
                showingAlert = true
            }
        }
    }
    
    private func formatLastPurgeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
    }
}
