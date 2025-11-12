import SwiftUI

struct ContentView: View {
    @StateObject private var processManager = ProcessManager()
    @State private var selectedProcess: ProcessInfo?
    @State private var searchText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
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
        VStack(spacing: 0) {
            // Header
            headerView
            
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
        .frame(width: 400, height: 500)
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
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(processManager.isRefreshing)
                .opacity(processManager.isRefreshing ? 0.5 : 1.0)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f GB", processManager.totalMemoryUsage))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Processes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(processManager.processes.count)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
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
        alertTitle = "Force Quit"
        alertMessage = "Force quit \(process.name) (PID: \(process.pid))?"
        showingAlert = true
        
        processManager.forceQuitProcess(pid: process.pid)
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(process.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text("PID: \(process.pid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(process.formattedMemory)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: onForceQuit) {
                    Text("Force Quit")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .hoverEffect()
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
