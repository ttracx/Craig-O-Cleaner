//
//  ContentView.swift
//  Craig-O-Clean Lite
//
//  Simplified system monitoring and cleanup
//

import SwiftUI

struct ContentView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var showingCleanupAlert = false
    @State private var cleanupMessage = ""
    @State private var showingUpgrade = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "brain")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Craig-O-Clean")
                            .font(.headline)
                        Text("Lite Edition")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { showingUpgrade = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("Upgrade")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button(action: { systemMonitor.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()

                Divider()
            }

            // System Stats
            VStack(alignment: .leading, spacing: 12) {
                StatRow(icon: "cpu", label: "CPU", value: String(format: "%.1f%%", systemMonitor.cpuUsage))
                StatRow(icon: "memorychip", label: "Memory", value: systemMonitor.memoryUsage)
                StatRow(icon: "internaldrive", label: "Disk", value: systemMonitor.diskUsage)
            }
            .padding()

            Divider()

            // Top Processes
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Memory Users")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(systemMonitor.topProcesses.prefix(10)) { process in
                            ProcessRow(process: process)
                        }
                    }
                }
            }

            Divider()

            // Quick Actions
            HStack(spacing: 12) {
                Button(action: performCleanup) {
                    Label("Quick Clean", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)

                Button(action: quitApp) {
                    Text("Quit")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            systemMonitor.startMonitoring()
        }
        .alert("Cleanup Complete", isPresented: $showingCleanupAlert) {
            Button("OK") { }
        } message: {
            Text(cleanupMessage)
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
        }
    }

    private func performCleanup() {
        let freedMemory = systemMonitor.performQuickCleanup()
        cleanupMessage = "Freed approximately \(freedMemory) MB of memory"
        showingCleanupAlert = true
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

struct ProcessRow: View {
    let process: ProcessInfo

    var body: some View {
        HStack {
            Text(process.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(process.memoryFormatted)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
