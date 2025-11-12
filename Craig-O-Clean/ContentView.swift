import SwiftUI

struct ContentView: View {
    @StateObject private var processManager = ProcessManager()
    @StateObject private var systemMemoryManager = SystemMemoryManager()
    @State private var selectedProcess: ProcessInfo?
    @State private var searchText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var selectedTab = 0
    
    var filteredProcesses: [ProcessInfo] {
        if searchText.isEmpty {
            return processManager.processes
        } else {
            return processManager.processes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            mainView
                .tabItem {
                    Label("Processes", systemImage: "memorychip")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
        }
        .frame(width: 420, height: 550)
        .padding(.top, 8)
        .onAppear {
            systemMemoryManager.refreshMemoryInfo()
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // System Memory Info
            systemMemoryView
            
            Divider()
            
            // Search bar
            searchBar
            
            // Process list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredProcesses) { process in
                        ProcessRow(
                            process: process,
                            isSelected: selectedProcess?.id == process.id,
                            onSelect: { selectedProcess = process },
                            onForceQuit: {
                                forceQuitProcess(process)
                            }
                        )
                    }
                }
            }
            
            Divider()
            
            // Footer with Purge button
            footerView
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Craig-O-Clean")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    processManager.refreshProcesses()
                    systemMemoryManager.refreshMemoryInfo()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(processManager.isRefreshing)
                .opacity(processManager.isRefreshing ? 0.5 : 1.0)
            }
            
            if let lastUpdate = processManager.lastUpdateTime {
                Text("Last updated: \(lastUpdate, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var systemMemoryView: some View {
        VStack(spacing: 12) {
            // Total system memory bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("System Memory")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.1f%%", systemMemoryManager.memoryPercentage))
                        .font(.headline)
                        .foregroundColor(memoryColor(for: systemMemoryManager.memoryPercentage))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // Used memory bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(memoryColor(for: systemMemoryManager.memoryPercentage))
                            .frame(width: geometry.size.width * CGFloat(systemMemoryManager.memoryPercentage / 100))
                    }
                }
                .frame(height: 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Used: \(String(format: "%.2f GB", systemMemoryManager.usedMemory))")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Available: \(String(format: "%.2f GB", systemMemoryManager.availableMemory))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Total: \(String(format: "%.2f GB", systemMemoryManager.totalMemory))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Pressure: \(systemMemoryManager.memoryPressure)")
                        .font(.caption2)
                        .foregroundColor(pressureColor(for: systemMemoryManager.memoryPressure))
                }
            }
            
            // Process memory usage
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Processes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f GB", processManager.totalMemoryUsage))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Count")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(processManager.processes.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func memoryColor(for percentage: Double) -> Color {
        if percentage < 50 {
            return .green
        } else if percentage < 75 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func pressureColor(for pressure: String) -> Color {
        switch pressure {
        case "Normal":
            return .green
        case "Moderate":
            return .orange
        default:
            return .red
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search processes...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Button(action: {
                purgeMemory()
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Purge Memory (sync && sudo purge)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("This will flush inactive memory and may require admin privileges")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func forceQuitProcess(_ process: ProcessInfo) {
        let alert = NSAlert()
        alert.messageText = "Force Quit Process?"
        alert.informativeText = "Are you sure you want to force quit \"\(process.name)\" (PID: \(process.pid))?\n\nMemory usage: \(process.formattedMemory)\n\nThis action cannot be undone and may cause data loss."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Force Quit")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            processManager.forceQuitProcess(pid: process.pid)
            
            alertTitle = "Success"
            alertMessage = "Process \(process.name) has been terminated."
            showingAlert = true
        }
    }
    
    private func purgeMemory() {
        processManager.purgeMemory { success, message in
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            showingAlert = true
        }
    }
}

struct ProcessRow: View {
    let process: ProcessInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onForceQuit: () -> Void
    
    private var isMemoryIntensive: Bool {
        process.memoryUsage >= 500 // 500 MB or more
    }
    
    var body: some View {
        HStack {
            // Warning indicator for memory-intensive processes
            if isMemoryIntensive {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(process.name)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if isMemoryIntensive {
                        Text("HIGH")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }
                
                Text("PID: \(process.pid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(process.formattedMemory)
                    .font(.headline)
                    .foregroundColor(isMemoryIntensive ? .orange : .primary)
                    .fontWeight(isMemoryIntensive ? .bold : .regular)
                
                Button(action: onForceQuit) {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                        Text("Force Quit")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundForRow)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .hoverEffect()
    }
    
    private var backgroundForRow: Color {
        if isSelected {
            return Color.blue.opacity(0.1)
        } else if isMemoryIntensive {
            return Color.orange.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}

extension View {
    func hoverEffect() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.clear, lineWidth: 0)
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
