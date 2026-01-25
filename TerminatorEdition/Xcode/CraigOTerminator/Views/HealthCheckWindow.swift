import SwiftUI

/// Health check diagnostic window
struct HealthCheckWindow: View {
    @StateObject private var healthCheck = HealthCheckService.shared
    @State private var selectedCategory: String?
    @Environment(\.dismiss) private var dismiss

    var categories: [String] {
        Array(Set(healthCheck.results.map { $0.category })).sorted()
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar - Categories
            List(selection: $selectedCategory) {
                Section("Health Check") {
                    ForEach(categories, id: \.self) { category in
                        CategoryRow(
                            category: category,
                            results: healthCheck.results.filter { $0.category == category }
                        )
                        .tag(category)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await healthCheck.runFullHealthCheck()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(healthCheck.isRunning)
                }
            }

        } detail: {
            // Detail - Results
            if let category = selectedCategory {
                ResultsDetailView(
                    category: category,
                    results: healthCheck.results.filter { $0.category == category }
                )
            } else {
                // Overview
                OverviewView(healthCheck: healthCheck)
            }
        }
        .navigationTitle("System Health Check")
        .frame(minWidth: 700, minHeight: 500)
        .task {
            if healthCheck.results.isEmpty {
                await healthCheck.runFullHealthCheck()
            }
        }
    }
}

// MARK: - Overview

struct OverviewView: View {
    @ObservedObject var healthCheck: HealthCheckService

    var passCount: Int {
        healthCheck.results.filter { $0.status == .pass }.count
    }

    var warningCount: Int {
        healthCheck.results.filter { $0.status == .warning }.count
    }

    var failCount: Int {
        healthCheck.results.filter { $0.status == .fail }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red.gradient)

                    Text("System Health Check")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let lastRun = healthCheck.lastRunTime {
                        Text("Last run: \(lastRun.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 40)

                // Summary Cards
                HStack(spacing: 16) {
                    StatCard(
                        title: "Passed",
                        count: passCount,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    StatCard(
                        title: "Warnings",
                        count: warningCount,
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )

                    StatCard(
                        title: "Failed",
                        count: failCount,
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)

                // Status
                if healthCheck.isRunning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Running diagnostics...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                } else if healthCheck.results.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No diagnostics run yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button("Run Health Check") {
                            Task {
                                await healthCheck.runFullHealthCheck()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 12) {
                        Text("Select a category to view details")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button("Export Report") {
                            exportReport()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func exportReport() {
        let report = healthCheck.exportReport()

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "CraigO-HealthCheck-\(Date().formatted(date: .numeric, time: .omitted)).txt"
        savePanel.message = "Export health check report"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try report.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export report: \(error)")
                }
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: String
    let results: [HealthCheckService.HealthCheckResult]

    var statusIcon: (icon: String, color: Color) {
        let hasFail = results.contains { $0.status == .fail }
        let hasWarning = results.contains { $0.status == .warning }

        if hasFail {
            return ("xmark.circle.fill", .red)
        } else if hasWarning {
            return ("exclamationmark.triangle.fill", .orange)
        } else {
            return ("checkmark.circle.fill", .green)
        }
    }

    var body: some View {
        HStack {
            Image(systemName: statusIcon.icon)
                .foregroundStyle(statusIcon.color)

            Text(category)

            Spacer()

            Text("\(results.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Results Detail

struct ResultsDetailView: View {
    let category: String
    let results: [HealthCheckService.HealthCheckResult]

    var body: some View {
        List {
            ForEach(results) { result in
                ResultRow(result: result)
            }
        }
        .navigationTitle(category)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Copy All Results") {
                        copyResults()
                    }

                    Button("Export Report") {
                        exportCategoryReport()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func copyResults() {
        var text = "\(category)\n\n"
        for result in results {
            text += "• \(result.name): \(result.message)\n"
            if let details = result.details {
                text += "  → \(details)\n"
            }
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportCategoryReport() {
        var report = "\(category) Health Check\n"
        report += String(repeating: "=", count: category.count + 13) + "\n\n"

        for result in results {
            let icon = result.status == .pass ? "✅" : result.status == .warning ? "⚠️" : result.status == .fail ? "❌" : "ℹ️"
            report += "\(icon) \(result.name): \(result.message)\n"
            if let details = result.details {
                report += "   → \(details)\n"
            }
            report += "\n"
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(category)-Report.txt"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? report.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Result Row

struct ResultRow: View {
    let result: HealthCheckService.HealthCheckResult

    var statusColor: Color {
        switch result.status {
        case .pass: return .green
        case .warning: return .orange
        case .fail: return .red
        case .info: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.status.icon)
                    .foregroundStyle(statusColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.headline)

                    Text(result.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let details = result.details {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text("\(count)")
                .font(.system(size: 36, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HealthCheckWindow()
        .frame(width: 800, height: 600)
}
