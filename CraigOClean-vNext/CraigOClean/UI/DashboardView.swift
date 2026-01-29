// File: CraigOClean-vNext/CraigOClean/UI/DashboardView.swift
// Craig-O-Clean - Dashboard View
// Main dashboard showing overview and capabilities

import SwiftUI

struct DashboardView: View {

    // MARK: - Properties

    @EnvironmentObject private var container: DIContainer
    @EnvironmentObject private var environment: AppEnvironment

    @State private var diskInfo: DiskInfo?
    @State private var cacheInfo: CacheInfo?
    @State private var isLoading = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                welcomeSection

                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        diskUsageCard
                        cacheOverviewCard
                        capabilitiesCard
                        quickActionsCard
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await refresh()
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        SectionCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Craig-O-Clean")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Keep your Mac clean and running smoothly")
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Label(environment.edition.displayName, systemImage: "checkmark.seal.fill")
                            .foregroundColor(environment.isPro ? .yellow : .blue)

                        Label("v\(environment.fullVersionString)", systemImage: "info.circle")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
        }
    }

    // MARK: - Disk Usage Card

    private var diskUsageCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Disk Usage", systemImage: "internaldrive")
                    .font(.headline)

                if let disk = diskInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: disk.usedPercentage / 100)
                            .progressViewStyle(.linear)

                        HStack {
                            Text("Used: \(disk.formattedUsedCapacity)")
                            Spacer()
                            Text("Free: \(disk.formattedAvailableCapacity)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Text("\(String(format: "%.1f", disk.usedPercentage))% used of \(disk.formattedTotalCapacity)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Loading disk information...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Cache Overview Card

    private var cacheOverviewCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Cleanable Space", systemImage: "trash")
                    .font(.headline)

                if let cache = cacheInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cache.formattedTotalCleanableSize)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            cacheRow("User Caches", size: cache.formattedUserCacheSize)
                            cacheRow("Logs", size: cache.formattedLogSize)
                            if let systemCache = cache.formattedSystemCacheSize {
                                cacheRow("System Caches", size: systemCache)
                            }
                        }

                        NavigationLink(value: NavigationTab.cleanup) {
                            Text("Start Cleanup")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func cacheRow(_ label: String, size: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(size)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Capabilities Card

    private var capabilitiesCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Capabilities", systemImage: "checkmark.shield")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(environment.capabilityInfo().prefix(5)) { info in
                        HStack {
                            Image(systemName: info.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(info.isEnabled ? .green : .secondary)
                                .font(.caption)

                            Text(info.name)
                                .font(.caption)
                                .foregroundColor(info.isEnabled ? .primary : .secondary)

                            Spacer()
                        }
                    }
                }

                if environment.isLite {
                    Text("Upgrade to Pro for more features")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quick Actions", systemImage: "bolt")
                    .font(.headline)

                VStack(spacing: 8) {
                    actionButton("Scan for Cleanup", icon: "magnifyingglass", tab: .cleanup)
                    actionButton("Run Diagnostics", icon: "stethoscope", tab: .diagnostics)
                    actionButton("View Logs", icon: "doc.text", tab: .logs)
                }
            }
        }
    }

    private func actionButton(_ title: String, icon: String, tab: NavigationTab) -> some View {
        NavigationLink(value: tab) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let diagnostics = container.diagnosticsService

        async let disk = diagnostics.collectDiskInfo()
        async let cache = diagnostics.collectCacheInfo()

        diskInfo = await disk
        cacheInfo = await cache
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DashboardView()
        }
        .environmentObject(DIContainer.shared)
        .environmentObject(AppEnvironment.shared)
    }
}
#endif
