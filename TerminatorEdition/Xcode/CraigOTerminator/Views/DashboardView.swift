import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var animateGauges = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Main metrics
                metricsSection

                // Health Score
                healthScoreSection

                // Quick Actions
                quickActionsSection

                // Last Cleanup Result
                if let result = appState.lastCleanupResult {
                    lastCleanupSection(result)
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.updateMetrics() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animateGauges = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Overview")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Monitor and manage your macOS system")
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }

    private var statusColor: Color {
        if appState.healthScore >= 80 { return .green }
        if appState.healthScore >= 60 { return .yellow }
        return .red
    }

    private var statusText: String {
        if appState.healthScore >= 80 { return "Healthy" }
        if appState.healthScore >= 60 { return "Needs Attention" }
        return "Critical"
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "CPU",
                value: appState.cpuUsage,
                icon: "cpu",
                color: cpuColor,
                animate: animateGauges
            )

            MetricCard(
                title: "Memory",
                value: appState.memoryUsage,
                icon: "memorychip",
                color: memoryColor,
                animate: animateGauges
            )

            MetricCard(
                title: "Disk",
                value: appState.diskUsage,
                icon: "internaldrive",
                color: diskColor,
                animate: animateGauges
            )
        }
    }

    private var cpuColor: Color {
        if appState.cpuUsage > 80 { return .red }
        if appState.cpuUsage > 60 { return .orange }
        return .green
    }

    private var memoryColor: Color {
        if appState.memoryUsage > 85 { return .red }
        if appState.memoryUsage > 70 { return .orange }
        return .green
    }

    private var diskColor: Color {
        if appState.diskUsage > 90 { return .red }
        if appState.diskUsage > 80 { return .orange }
        return .green
    }

    // MARK: - Health Score Section

    private var healthScoreSection: some View {
        HStack(spacing: 24) {
            // Health gauge
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.1)
                    .foregroundStyle(.gray)

                Circle()
                    .trim(from: 0.0, to: animateGauges ? CGFloat(appState.healthScore) / 100.0 : 0)
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        AngularGradient(
                            gradient: Gradient(colors: [.red, .orange, .yellow, .green]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .rotationEffect(Angle(degrees: -90))

                VStack {
                    Text("\(appState.healthScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Health Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180)
            .padding()

            // Recommendations
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommendations")
                    .font(.headline)

                if appState.healthScore < 80 {
                    RecommendationRow(
                        icon: "exclamationmark.triangle",
                        text: appState.memoryUsage > 80 ? "High memory usage - consider cleanup" : "System needs attention",
                        color: .orange
                    )
                }

                if appState.diskUsage > 85 {
                    RecommendationRow(
                        icon: "externaldrive.badge.exclamationmark",
                        text: "Low disk space - clear caches",
                        color: .red
                    )
                }

                if appState.healthScore >= 80 {
                    RecommendationRow(
                        icon: "checkmark.seal.fill",
                        text: "System is running optimally",
                        color: .green
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                ActionCard(
                    title: "Quick Cleanup",
                    description: "Fast memory purge",
                    icon: "bolt.fill",
                    gradient: [.blue, .cyan]
                ) {
                    Task { await appState.performQuickCleanup() }
                }

                ActionCard(
                    title: "Full Cleanup",
                    description: "Comprehensive clean",
                    icon: "sparkles",
                    gradient: [.green, .mint]
                ) {
                    Task { await appState.performFullCleanup() }
                }

                ActionCard(
                    title: "Emergency Mode",
                    description: "Critical recovery",
                    icon: "exclamationmark.triangle.fill",
                    gradient: [.red, .orange]
                ) {
                    Task { await appState.performEmergencyCleanup() }
                }
            }
        }
    }

    // MARK: - Last Cleanup Section

    private func lastCleanupSection(_ result: AppState.CleanupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Cleanup")
                    .font(.headline)
                Spacer()
                Text(result.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                ResultItem(
                    title: "Memory Freed",
                    value: result.memoryFreedFormatted,
                    icon: "memorychip"
                )

                ResultItem(
                    title: "Disk Freed",
                    value: result.diskSpaceFreedFormatted,
                    icon: "internaldrive"
                )

                ResultItem(
                    title: "Caches Cleared",
                    value: "\(result.cachesCleared)",
                    icon: "trash"
                )

                ResultItem(
                    title: "Duration",
                    value: String(format: "%.1fs", result.duration),
                    icon: "clock"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    let animate: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: animate ? CGFloat(value) / 100.0 * 150 : 0, height: 8)
                    .animation(.easeOut(duration: 1.0), value: animate)
            }
            .frame(width: 150)

            Text("\(String(format: "%.1f", value))%")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RecommendationRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct ActionCard: View {
    let title: String
    let description: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct ResultItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState.shared)
        .frame(width: 800, height: 600)
}
