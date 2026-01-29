// File: CraigOClean-vNext/CraigOClean/UI/CleanupView.swift
// Craig-O-Clean - Cleanup View
// Main cleanup interface with scan, preview, and execute

import SwiftUI

struct CleanupView: View {

    // MARK: - Properties

    @EnvironmentObject private var container: DIContainer
    @EnvironmentObject private var environment: AppEnvironment

    @StateObject private var viewModel = CleanupViewModel()

    @State private var showingConfirmation = false
    @State private var showingResults = false
    @State private var showingProFeatureSheet = false
    @State private var proFeatureMessage = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area
            toolbarSection

            Divider()

            // Main content
            if viewModel.isScanning {
                scanningView
            } else if viewModel.scanResults.isEmpty {
                emptyStateView
            } else {
                scanResultsView
            }
        }
        .navigationTitle("Cleanup")
        .task {
            viewModel.configure(with: container)
        }
        .alert("Confirm Cleanup", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean Selected", role: .destructive) {
                Task { await viewModel.executeCleanup() }
            }
        } message: {
            Text("This will permanently delete \(viewModel.selectedCount) items (\(viewModel.selectedSizeFormatted)). This action cannot be undone.")
        }
        .sheet(isPresented: $showingResults) {
            CleanupResultsSheet(result: viewModel.lastResult)
        }
        .sheet(isPresented: $showingProFeatureSheet) {
            ProFeatureSheet(message: proFeatureMessage)
        }
    }

    // MARK: - Toolbar Section

    private var toolbarSection: some View {
        HStack(spacing: 12) {
            // Scan button
            PrimaryButton(
                title: viewModel.scanResults.isEmpty ? "Scan" : "Rescan",
                icon: "magnifyingglass",
                isLoading: viewModel.isScanning
            ) {
                Task { await viewModel.scan() }
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning)

            Spacer()

            if !viewModel.scanResults.isEmpty {
                // Selection info
                Text("\(viewModel.selectedCount) selected (\(viewModel.selectedSizeFormatted))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Clean button
                PrimaryButton(
                    title: "Clean Selected",
                    icon: "trash",
                    style: .destructive,
                    isLoading: viewModel.isCleaning
                ) {
                    showingConfirmation = true
                }
                .disabled(viewModel.selectedCount == 0 || viewModel.isCleaning)
            }
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Ready to Clean")
                .font(.title2)
                .fontWeight(.medium)

            Text("Click Scan to find cleanable files in your caches and logs")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if environment.isLite {
                Text("Some system locations are not available in the App Store edition.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning...")
                .font(.headline)

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: viewModel.progress)
                .frame(width: 200)

            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scan Results View

    private var scanResultsView: some View {
        List {
            ForEach(viewModel.scanResults) { result in
                CleanupTargetSection(
                    result: result,
                    isExpanded: viewModel.expandedTargets.contains(result.target.id),
                    onToggleExpand: { viewModel.toggleExpanded(result.target.id) },
                    onToggleSelection: { viewModel.toggleTargetSelection(result.target.id) },
                    onProFeature: { message in
                        proFeatureMessage = message
                        showingProFeatureSheet = true
                    }
                )
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Cleanup Target Section

struct CleanupTargetSection: View {
    let result: CleanupScanResult
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onToggleSelection: () -> Void
    let onProFeature: (String) -> Void

    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Section {
            // Header row
            Button(action: onToggleExpand) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle(isOn: Binding(
                        get: { result.target.isSelected },
                        set: { _ in onToggleSelection() }
                    )) {
                        HStack {
                            Image(systemName: result.target.category.icon)
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading) {
                                Text(result.target.name)
                                    .font(.headline)

                                Text("\(result.fileCount) files - \(result.formattedTotalSize)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if result.target.requiresPrivileges && environment.isLite {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(result.target.requiresPrivileges && environment.isLite)
                }
            }
            .buttonStyle(.plain)

            // Expanded file list
            if isExpanded {
                ForEach(result.files.prefix(50)) { file in
                    HStack {
                        Image(systemName: file.isDirectory ? "folder" : "doc")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.caption)
                                .lineLimit(1)

                            Text(file.path)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 24)
                }

                if result.files.count > 50 {
                    Text("... and \(result.files.count - 50) more files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
            }
        }
    }
}

// MARK: - Cleanup Results Sheet

struct CleanupResultsSheet: View {
    let result: CleanupSessionResult?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: result?.allSuccessful == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(result?.allSuccessful == true ? .green : .orange)

            Text("Cleanup Complete")
                .font(.title2)
                .fontWeight(.bold)

            if let result = result {
                VStack(spacing: 8) {
                    Text("\(result.formattedTotalBytesFreed) freed")
                        .font(.title3)
                        .foregroundColor(.green)

                    Text("\(result.totalFilesRemoved) files removed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if result.failedCount > 0 {
                        Text("\(result.failedCount) targets had errors")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 300)
    }
}

// MARK: - Cleanup View Model

@MainActor
class CleanupViewModel: ObservableObject {
    @Published var scanResults: [CleanupScanResult] = []
    @Published var expandedTargets: Set<UUID> = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var lastResult: CleanupSessionResult?

    private var container: DIContainer?
    private var cleanerService: (any CleanerService)?

    func configure(with container: DIContainer) {
        self.container = container
        self.cleanerService = container.cleanerService
    }

    var selectedCount: Int {
        scanResults.filter { $0.target.isSelected }.reduce(0) { $0 + $1.fileCount }
    }

    var selectedSizeFormatted: String {
        let total = scanResults.filter { $0.target.isSelected }.reduce(UInt64(0)) { $0 + $1.totalSize }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    func scan() async {
        guard let service = cleanerService else { return }

        isScanning = true
        progress = 0
        statusMessage = "Preparing..."

        let targets = service.availableTargets()

        do {
            scanResults = try await service.scanTargets(targets)
        } catch {
            container?.logger.error("Scan failed: \(error.localizedDescription)", category: .cleanup)
        }

        isScanning = false
    }

    func cancelScan() {
        cleanerService?.cancelCleanup()
    }

    func toggleExpanded(_ id: UUID) {
        if expandedTargets.contains(id) {
            expandedTargets.remove(id)
        } else {
            expandedTargets.insert(id)
        }
    }

    func toggleTargetSelection(_ id: UUID) {
        guard let index = scanResults.firstIndex(where: { $0.target.id == id }) else { return }
        var result = scanResults[index]
        var target = result.target
        target.isSelected.toggle()
        scanResults[index] = CleanupScanResult(
            target: target,
            files: result.files,
            totalSize: result.totalSize,
            scanTime: result.scanTime,
            errors: result.errors
        )
    }

    func executeCleanup() async {
        guard let service = cleanerService else { return }

        isCleaning = true

        let selectedTargets = scanResults.filter { $0.target.isSelected }.map { $0.target }

        do {
            lastResult = try await service.runCleanup(targets: selectedTargets, dryRun: false)
            scanResults = []  // Clear after successful cleanup
        } catch {
            container?.logger.error("Cleanup failed: \(error.localizedDescription)", category: .cleanup)
        }

        isCleaning = false
    }
}

// MARK: - Preview

#if DEBUG
struct CleanupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CleanupView()
        }
        .environmentObject(DIContainer.shared)
        .environmentObject(AppEnvironment.shared)
    }
}
#endif
