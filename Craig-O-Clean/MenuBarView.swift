import SwiftUI

struct MenuBarView: View {
    @StateObject private var processManager = ProcessManager()
    @StateObject private var systemMemoryManager = SystemMemoryManager()
    @State private var searchText = ""

    var onExpandClick: () -> Void

    var filteredProcesses: [ProcessInfo] {
        let topProcesses = processManager.processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
            .prefix(10)

        if searchText.isEmpty {
            return Array(topProcesses)
        } else {
            return Array(topProcesses.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Craig-O-Clean")
                        .font(.headline)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cpuColor(processManager.totalCPUUsage))
                                .frame(width: 6, height: 6)
                            Text("\(Int(processManager.totalCPUUsage))%")
                                .font(.caption2)
                        }

                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption2)

                        Text(formatBytes(processManager.totalMemoryUsage))
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    processManager.updateProcessList()
                    systemMemoryManager.refreshMemoryInfo()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(processManager.isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Search top processes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            // System stats
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System CPU")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cpuColor(processManager.totalCPUUsage))
                            .frame(width: 8, height: 8)
                        Text("\(String(format: "%.1f%%", processManager.totalCPUUsage))")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatBytes(processManager.totalMemoryUsage))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Processes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(processManager.processes.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Top processes list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredProcesses) { process in
                        CompactProcessRow(process: process)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }

                    if filteredProcesses.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No processes found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 100)
                    }
                }
            }
            .frame(height: 280)

            Divider()

            // Footer with expand button
            HStack {
                Text("Top \(min(10, processManager.processes.count)) by CPU")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    onExpandClick()
                } label: {
                    HStack(spacing: 4) {
                        Text("Expand")
                            .font(.caption)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 360)
        .onAppear {
            processManager.updateProcessList()
            systemMemoryManager.refreshMemoryInfo()
        }
    }

    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<25:
            return .green
        case 25..<50:
            return .yellow
        case 50..<75:
            return .orange
        default:
            return .red
        }
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
}

struct CompactProcessRow: View {
    let process: ProcessInfo

    var cpuColor: Color {
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
        HStack(spacing: 8) {
            // Icon
            if let bundleIdentifier = process.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "gear")
                    .frame(width: 16, height: 16)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.caption)
                    .lineLimit(1)

                Text("PID: \(process.id)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // CPU
            HStack(spacing: 4) {
                Circle()
                    .fill(cpuColor)
                    .frame(width: 6, height: 6)
                Text("\(String(format: "%.1f%%", process.cpuUsage))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(cpuColor)
                    .frame(width: 50, alignment: .trailing)
            }

            // Memory
            Text(String(format: "%.0f MB", Double(process.memoryUsage) / 1024.0 / 1024.0))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(4)
    }
}

#Preview {
    MenuBarView(onExpandClick: {})
}
