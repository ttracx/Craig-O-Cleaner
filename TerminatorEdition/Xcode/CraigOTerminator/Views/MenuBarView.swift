import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var showBrowserActions = false
    @State private var showProcessActions = false
    @State private var showAIPanel = false
    @State private var browserCount = 0
    @State private var topProcesses: [(name: String, cpu: Double)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            MenuBarHeader(appState: appState)

            Divider()

            // MARK: - System Metrics
            MenuBarMetrics(appState: appState)

            Divider()

            // MARK: - Cleanup Actions
            MenuBarCleanupSection(appState: appState)

            Divider()

            // MARK: - Browser Management
            MenuBarBrowserSection(
                browserCount: $browserCount,
                showBrowserActions: $showBrowserActions
            )

            Divider()

            // MARK: - Process Management
            MenuBarProcessSection(
                topProcesses: $topProcesses,
                showProcessActions: $showProcessActions
            )

            Divider()

            // MARK: - AI Features
            if appState.isAIEnabled {
                MenuBarAISection(appState: appState, showAIPanel: $showAIPanel)
                Divider()
            }

            // MARK: - Quick Utilities
            MenuBarUtilitiesSection()

            Divider()

            // MARK: - App Controls
            MenuBarAppControls(appState: appState)
        }
        .frame(width: 320)
        .task {
            await refreshBrowserCount()
            await refreshTopProcesses()
        }
    }

    // MARK: - Helper Functions

    @MainActor
    private func refreshBrowserCount() async {
        let executor = CommandExecutor.shared
        var count = 0

        // Check Safari tabs
        if let result = try? await executor.executeAppleScript("""
            tell application "Safari"
                if it is running then
                    set tabCount to 0
                    repeat with w in windows
                        set tabCount to tabCount + (count of tabs of w)
                    end repeat
                    return tabCount
                end if
            end tell
            """) {
            count += Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }

        // Check Chrome tabs
        if let result = try? await executor.executeAppleScript("""
            tell application "Google Chrome"
                if it is running then
                    set tabCount to 0
                    repeat with w in windows
                        set tabCount to tabCount + (count of tabs of w)
                    end repeat
                    return tabCount
                end if
            end tell
            """) {
            count += Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }

        browserCount = count
    }

    @MainActor
    private func refreshTopProcesses() async {
        let executor = CommandExecutor.shared

        if let result = try? await executor.execute("ps aux | tail -n +2 | sort -nrk 3 | head -5") {
            var processes: [(String, Double)] = []

            for line in result.output.components(separatedBy: "\n").prefix(5) {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 11 else { continue }

                let cpuPercent = Double(parts[2]) ?? 0
                let name = String(parts[10...].joined(separator: " ").split(separator: "/").last ?? "")
                    .trimmingCharacters(in: .whitespaces)

                if !name.isEmpty && cpuPercent > 0 {
                    processes.append((name, cpuPercent))
                }
            }

            topProcesses = processes
        }
    }
}

// MARK: - Menu Bar Header

struct MenuBarHeader: View {
    let appState: AppState

    var body: some View {
        HStack {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Craig-O-Clean")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Terminator Edition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HealthBadge(score: appState.healthScore)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct HealthBadge: View {
    let score: Int

    var color: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text("Health")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Metrics Section

struct MenuBarMetrics: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            MetricRow(
                title: "CPU",
                value: "\(Int(appState.cpuUsage))%",
                icon: "cpu",
                color: colorFor(appState.cpuUsage),
                progress: appState.cpuUsage / 100
            )

            MetricRow(
                title: "Memory",
                value: "\(Int(appState.memoryUsage))%",
                icon: "memorychip",
                color: colorFor(appState.memoryUsage),
                progress: appState.memoryUsage / 100
            )

            MetricRow(
                title: "Disk",
                value: "\(Int(appState.diskUsage))%",
                icon: "internaldrive",
                color: colorFor(appState.diskUsage),
                progress: appState.diskUsage / 100
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func colorFor(_ value: Double) -> Color {
        if value > 85 { return .red }
        if value > 70 { return .orange }
        return .green
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)

                Text(title)
                    .font(.caption)

                Spacer()

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }

            ProgressView(value: progress)
                .tint(color)
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
        }
    }
}

// MARK: - Cleanup Section

struct MenuBarCleanupSection: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 2) {
            MenuBarSectionHeader(title: "Cleanup Actions", icon: "sparkles")

            MenuBarButton(title: "Quick Cleanup", icon: "hare.fill", shortcut: "⌘⇧K") {
                Task { await appState.performQuickCleanup() }
            }

            MenuBarButton(title: "Full Cleanup", icon: "tornado", shortcut: "⌘⇧C") {
                Task { await appState.performFullCleanup() }
            }

            MenuBarButton(title: "Emergency Mode", icon: "exclamationmark.triangle.fill", shortcut: "⌘⇧E") {
                Task { await appState.performEmergencyCleanup() }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Browser Section

struct MenuBarBrowserSection: View {
    @Binding var browserCount: Int
    @Binding var showBrowserActions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showBrowserActions.toggle()
            } label: {
                HStack {
                    MenuBarSectionHeader(title: "Browsers", icon: "globe")
                    Spacer()
                    Text("\(browserCount) tabs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: showBrowserActions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if showBrowserActions {
                VStack(spacing: 2) {
                    MenuBarButton(title: "Close Inactive Tabs", icon: "xmark.circle", shortcut: nil) {
                        Task { await closeInactiveTabs() }
                    }

                    MenuBarButton(title: "Clear All Caches", icon: "trash", shortcut: nil) {
                        Task { await clearAllBrowserCaches() }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func closeInactiveTabs() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.executeAppleScript("""
            tell application "Safari"
                repeat with w in windows
                    set urlList to {}
                    repeat with t in tabs of w
                        set tabURL to URL of t
                        if urlList contains tabURL then
                            close t
                        else
                            set end of urlList to tabURL
                        end if
                    end repeat
                end repeat
            end tell
            """)
    }

    @MainActor
    private func clearAllBrowserCaches() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("rm -rf ~/Library/Caches/com.apple.Safari/* ~/Library/Caches/Google/Chrome/* ~/Library/Caches/Firefox/* 2>/dev/null")
    }
}

// MARK: - Process Section

struct MenuBarProcessSection: View {
    @Binding var topProcesses: [(name: String, cpu: Double)]
    @Binding var showProcessActions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showProcessActions.toggle()
            } label: {
                HStack {
                    MenuBarSectionHeader(title: "Top Processes", icon: "cpu")
                    Spacer()
                    Image(systemName: showProcessActions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if showProcessActions {
                VStack(spacing: 2) {
                    ForEach(topProcesses.prefix(3), id: \.name) { process in
                        HStack {
                            Text(process.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", process.cpu))
                                .font(.caption)
                                .foregroundStyle(process.cpu > 50 ? .red : .secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 2)
                    }

                    MenuBarButton(title: "Kill Heavy Processes", icon: "bolt.slash", shortcut: nil) {
                        Task { await killHeavyProcesses() }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func killHeavyProcesses() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("pkill -9 -f 'Chrome Helper' 2>/dev/null")
        _ = try? await executor.execute("pkill -9 -f 'Safari Web Content' 2>/dev/null")
    }
}

// MARK: - AI Section

struct MenuBarAISection: View {
    let appState: AppState
    @Binding var showAIPanel: Bool

    var body: some View {
        VStack(spacing: 2) {
            Button {
                showAIPanel.toggle()
            } label: {
                HStack {
                    MenuBarSectionHeader(title: "AI Assistant", icon: "brain")
                    Spacer()
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if showAIPanel {
                VStack(spacing: 2) {
                    MenuBarButton(title: "Optimize System", icon: "sparkles", shortcut: nil) {
                        Task { await optimizeSystem() }
                    }

                    MenuBarButton(title: "Analyze Performance", icon: "chart.bar", shortcut: nil) {
                        Task { await analyzePerformance() }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func optimizeSystem() async {
        appState.showAlertMessage("AI optimization started...")
        // AI optimization logic would go here
    }

    @MainActor
    private func analyzePerformance() async {
        appState.showAlertMessage("AI analyzing system performance...")
        // AI analysis logic would go here
    }
}

// MARK: - Utilities Section

struct MenuBarUtilitiesSection: View {
    var body: some View {
        VStack(spacing: 2) {
            MenuBarSectionHeader(title: "Utilities", icon: "wrench.and.screwdriver")

            MenuBarButton(title: "Purge Memory", icon: "memorychip", shortcut: "⌘M") {
                Task { await purgeMemory() }
            }

            MenuBarButton(title: "Flush DNS Cache", icon: "network", shortcut: "⌘D") {
                Task { await flushDNS() }
            }

            MenuBarButton(title: "Rebuild Launch Services", icon: "arrow.triangle.2.circlepath", shortcut: nil) {
                Task { await rebuildLaunchServices() }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func purgeMemory() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.executePrivileged("purge")
        await AppState.shared.updateMetrics()
    }

    @MainActor
    private func flushDNS() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.executePrivileged("dscacheutil -flushcache && killall -HUP mDNSResponder")
    }

    @MainActor
    private func rebuildLaunchServices() async {
        let executor = CommandExecutor.shared
        _ = try? await executor.execute("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user")
    }
}

// MARK: - App Controls

struct MenuBarAppControls: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 2) {
            MenuBarButton(title: "Open Main Window", icon: "macwindow", shortcut: "⌘O") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }

            MenuBarButton(title: "Settings...", icon: "gear", shortcut: "⌘,") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Divider()
                .padding(.horizontal, 12)

            if appState.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(appState.currentOperation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit Craig-O-Clean")
                        .foregroundStyle(.red)
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reusable Components

struct MenuBarSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct MenuBarButton: View {
    let title: String
    let icon: String
    let shortcut: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                Text(title)
                    .font(.caption)

                Spacer()

                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}
