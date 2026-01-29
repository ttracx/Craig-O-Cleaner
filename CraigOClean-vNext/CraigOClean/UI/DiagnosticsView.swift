// File: CraigOClean-vNext/CraigOClean/UI/DiagnosticsView.swift
// Craig-O-Clean - Diagnostics View
// System diagnostics and reporting

import SwiftUI

struct DiagnosticsView: View {

    // MARK: - Properties

    @EnvironmentObject private var container: DIContainer
    @EnvironmentObject private var environment: AppEnvironment

    @State private var report: DiagnosticReport?
    @State private var isCollecting = false
    @State private var showingExportSheet = false
    @State private var showingProFeatureSheet = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if isCollecting {
                    collectingView
                } else if let report = report {
                    reportView(report)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await collectReport() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isCollecting)

                    Divider()

                    Button {
                        handleExport()
                    } label: {
                        Label("Export Report...", systemImage: "square.and.arrow.up")
                    }
                    .disabled(report == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingProFeatureSheet) {
            ProFeatureSheet(message: "Exporting diagnostic reports requires access not available in the App Store edition.")
        }
        .task {
            if report == nil {
                await collectReport()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        SectionCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Diagnostics")
                        .font(.headline)

                    Text("View detailed information about your Mac and Craig-O-Clean")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "stethoscope")
                    .font(.title)
                    .foregroundColor(.accentColor)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Report Available")
                .font(.headline)

            Button("Collect Diagnostics") {
                Task { await collectReport() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Collecting View

    private var collectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Collecting diagnostics...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Report View

    @ViewBuilder
    private func reportView(_ report: DiagnosticReport) -> some View {
        // System Info
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("System Information", systemImage: "desktopcomputer")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        Text("macOS Version").foregroundColor(.secondary)
                        Text("\(report.systemInfo.macOSVersion) (\(report.systemInfo.macOSBuild))")
                    }
                    GridRow {
                        Text("Hardware").foregroundColor(.secondary)
                        Text(report.systemInfo.hardwareModel)
                    }
                    GridRow {
                        Text("Processor").foregroundColor(.secondary)
                        Text(report.systemInfo.processorInfo)
                            .lineLimit(1)
                    }
                    GridRow {
                        Text("Memory").foregroundColor(.secondary)
                        Text(report.systemInfo.formattedMemorySize)
                    }
                    if let uptime = report.systemInfo.uptimeString {
                        GridRow {
                            Text("Uptime").foregroundColor(.secondary)
                            Text(uptime)
                        }
                    }
                }
                .font(.caption)
            }
        }

        // Disk Info
        if let disk = report.diskInfo {
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Disk Information", systemImage: "internaldrive")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: disk.usedPercentage / 100)

                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            GridRow {
                                Text("Volume").foregroundColor(.secondary)
                                Text(disk.volumeName)
                            }
                            GridRow {
                                Text("File System").foregroundColor(.secondary)
                                Text(disk.fileSystemType)
                            }
                            GridRow {
                                Text("Total").foregroundColor(.secondary)
                                Text(disk.formattedTotalCapacity)
                            }
                            GridRow {
                                Text("Used").foregroundColor(.secondary)
                                Text("\(disk.formattedUsedCapacity) (\(String(format: "%.1f", disk.usedPercentage))%)")
                            }
                            GridRow {
                                Text("Available").foregroundColor(.secondary)
                                Text(disk.formattedAvailableCapacity)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }

        // Cache Info
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Cache Analysis", systemImage: "folder.badge.gearshape")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        Text("User Caches").foregroundColor(.secondary)
                        Text(report.cacheInfo.formattedUserCacheSize)
                    }
                    if let systemCache = report.cacheInfo.formattedSystemCacheSize {
                        GridRow {
                            Text("System Caches").foregroundColor(.secondary)
                            Text(systemCache)
                        }
                    } else if environment.isLite {
                        GridRow {
                            Text("System Caches").foregroundColor(.secondary)
                            HStack {
                                Text("Not available")
                                Image(systemName: "lock.fill")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    GridRow {
                        Text("Logs").foregroundColor(.secondary)
                        Text(report.cacheInfo.formattedLogSize)
                    }
                    GridRow {
                        Text("Total Cleanable").foregroundColor(.secondary)
                        Text(report.cacheInfo.formattedTotalCleanableSize)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
            }
        }

        // App Info
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Application", systemImage: "app.badge")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        Text("Version").foregroundColor(.secondary)
                        Text(report.appInfo.fullVersionString)
                    }
                    GridRow {
                        Text("Edition").foregroundColor(.secondary)
                        Text(report.appInfo.edition.displayName)
                    }
                }
                .font(.caption)
            }
        }

        // Export section
        if environment.isPro {
            SectionCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export Report")
                            .font(.headline)
                        Text("Save a copy of this report to share or archive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Export...") {
                        handleExport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Actions

    private func collectReport() async {
        isCollecting = true
        defer { isCollecting = false }

        do {
            report = try await container.diagnosticsService.collectReport()
        } catch {
            container.logger.error("Failed to collect diagnostics: \(error.localizedDescription)", category: .diagnostics)
        }
    }

    private func handleExport() {
        guard environment.capabilities.canExportDiagnostics else {
            showingProFeatureSheet = true
            return
        }

        // Show save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "CraigOClean-Diagnostics-\(Date().ISO8601Format()).txt"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                if let report = report {
                    try? await container.diagnosticsService.exportReport(report, to: url)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DiagnosticsView()
        }
        .environmentObject(DIContainer.shared)
        .environmentObject(AppEnvironment.shared)
    }
}
#endif
