// MARK: - CapabilityMenuBarView.swift
// Craig-O-Clean - Capability-Based Menu Bar View
// Organized sections: Status, Quick Actions, Deep Clean, Browsers, System

import SwiftUI

struct CapabilityMenuBarView: View {
    @ObservedObject var catalog: CapabilityCatalog
    @ObservedObject var coordinator: CapabilityCoordinator
    @EnvironmentObject var systemMetrics: SystemMetricsService

    @State private var confirmCapability: Capability?
    @State private var showActivityLog = false
    @State private var showPermissions = false
    @State private var executionOutput: String = ""
    @State private var showOutput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Header
            headerSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Status Section
                    statusSection

                    Divider().padding(.vertical, 4)

                    // Quick Actions
                    menuSection(title: "Quick Actions", group: .quickClean, icon: "bolt")

                    Divider().padding(.vertical, 4)

                    // Deep Clean
                    menuSection(title: "Deep Clean", group: .deepClean, icon: "trash")

                    Divider().padding(.vertical, 4)

                    // Browser Management
                    menuSection(title: "Browsers", group: .browsers, icon: "globe")

                    Divider().padding(.vertical, 4)

                    // Developer Tools
                    menuSection(title: "Developer Tools", group: .devTools, icon: "hammer")

                    Divider().padding(.vertical, 4)

                    // Memory
                    menuSection(title: "Memory", group: .memory, icon: "memorychip")

                    Divider().padding(.vertical, 4)

                    // System
                    menuSection(title: "System", group: .system, icon: "gearshape.2")
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 500)

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 340)
        .sheet(item: $confirmCapability) { cap in
            CapabilityConfirmationDialog(
                capability: cap,
                onConfirm: { executeCapability(cap) ; confirmCapability = nil },
                onCancel: { confirmCapability = nil },
                onPreview: nil
            )
        }
        .sheet(isPresented: $showActivityLog) {
            ActivityLogView()
                .frame(minWidth: 550, minHeight: 450)
        }
        .sheet(isPresented: $showPermissions) {
            CapabilityPermissionStatusView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showOutput) {
            executionOutputSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "paintbrush.fill")
                .foregroundColor(.vibePurple)
            Text("Craig-O-Clean")
                .font(.headline)
            Spacer()
            if coordinator.isExecuting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(title: "Status", icon: "gauge")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Memory:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(systemMetrics.memoryUsageSummary)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Disk:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(systemMetrics.diskUsageSummary)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Menu Section

    private func menuSection(title: String, group: CapabilityGroup, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader(title: title, icon: icon)

            ForEach(catalog.capabilities(in: group)) { capability in
                capabilityRow(capability)
            }
        }
    }

    private func capabilityRow(_ capability: Capability) -> some View {
        Button(action: { handleCapabilityTap(capability) }) {
            HStack(spacing: 10) {
                Image(systemName: capability.icon)
                    .frame(width: 16)
                    .foregroundColor(iconColor(for: capability))

                Text(capability.title)
                    .font(.callout)

                Spacer()

                if capability.riskClass == .destructive {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if capability.privilegeLevel == .elevated {
                    Image(systemName: "lock.shield")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if capability.privilegeLevel == .automation {
                    Image(systemName: "gearshape")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(coordinator.isExecuting)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.vibePurple)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 16) {
            Button(action: { showActivityLog = true }) {
                Label("Log", systemImage: "list.bullet.rectangle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Button(action: { showPermissions = true }) {
                Label("Permissions", systemImage: "lock.shield")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Execution Output Sheet

    private var executionOutputSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Output")
                    .font(.headline)
                Spacer()
                Button("Close") { showOutput = false }
                    .buttonStyle(.bordered)
            }
            ScrollView {
                Text(executionOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 400)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 300)
    }

    // MARK: - Actions

    private func handleCapabilityTap(_ capability: Capability) {
        switch capability.riskClass {
        case .safe:
            executeCapability(capability)
        case .moderate, .destructive:
            confirmCapability = capability
        }
    }

    private func executeCapability(_ capability: Capability) {
        Task {
            do {
                let result = try await coordinator.execute(capability) { progress in
                    if let stdout = progress.stdout {
                        executionOutput += stdout
                    }
                }
                executionOutput = result.stdout
                if !result.stdout.isEmpty {
                    showOutput = true
                }
            } catch {
                executionOutput = "Error: \(error.localizedDescription)"
                showOutput = true
            }
        }
    }

    private func iconColor(for capability: Capability) -> Color {
        switch capability.riskClass {
        case .safe: return .green
        case .moderate: return .orange
        case .destructive: return .red
        }
    }
}

// MARK: - SystemMetricsService Helpers

extension SystemMetricsService {
    var memoryUsageSummary: String {
        guard let mem = memoryMetrics else { return "N/A" }
        let used = Double(mem.usedRAM) / (1024 * 1024 * 1024)
        let total = Double(mem.totalRAM) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB / %.1f GB", used, total)
    }

    var diskUsageSummary: String {
        guard let disk = diskMetrics else { return "N/A" }
        let free = Double(disk.freeSpace) / (1024 * 1024 * 1024)
        return String(format: "%.0f GB free", free)
    }
}
