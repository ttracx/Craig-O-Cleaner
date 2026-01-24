import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(.blue)
                Text("Craig-O-Clean")
                    .fontWeight(.semibold)
                Spacer()
                HealthIndicator(score: appState.healthScore)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Quick Stats
            VStack(spacing: 8) {
                QuickStatRow(title: "CPU", value: "\(Int(appState.cpuUsage))%", icon: "cpu", color: colorFor(appState.cpuUsage))
                QuickStatRow(title: "Memory", value: "\(Int(appState.memoryUsage))%", icon: "memorychip", color: colorFor(appState.memoryUsage))
                QuickStatRow(title: "Disk", value: "\(Int(appState.diskUsage))%", icon: "internaldrive", color: colorFor(appState.diskUsage))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Quick Actions
            VStack(spacing: 2) {
                MenuBarButton(title: "Quick Cleanup", icon: "hare.fill", shortcut: "⌘Q") {
                    Task { await appState.performQuickCleanup() }
                }

                MenuBarButton(title: "Full Cleanup", icon: "tornado", shortcut: "⌘F") {
                    Task { await appState.performFullCleanup() }
                }

                MenuBarButton(title: "Purge Memory", icon: "memorychip", shortcut: "⌘M") {
                    Task { await purgeMemory() }
                }

                MenuBarButton(title: "Flush DNS", icon: "network", shortcut: "⌘D") {
                    Task { await flushDNS() }
                }
            }
            .padding(.vertical, 4)

            Divider()

            // Window Actions
            VStack(spacing: 2) {
                MenuBarButton(title: "Open Main Window", icon: "macwindow", shortcut: "⌘O") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }

                MenuBarButton(title: "Settings...", icon: "gear", shortcut: "⌘,") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            .padding(.vertical, 4)

            Divider()

            // Status
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

                Divider()
            }

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit Craig-O-Clean")
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
        .frame(width: 280)
    }

    private func colorFor(_ value: Double) -> Color {
        if value > 85 { return .red }
        if value > 70 { return .orange }
        return .green
    }

    @MainActor
    private func purgeMemory() async {
        appState.isLoading = true
        appState.currentOperation = "Purging memory..."
        let executor = CommandExecutor.shared
        _ = try? await executor.executePrivileged("purge")
        await appState.updateMetrics()
        appState.isLoading = false
    }

    @MainActor
    private func flushDNS() async {
        appState.isLoading = true
        appState.currentOperation = "Flushing DNS..."
        let executor = CommandExecutor.shared
        _ = try? await executor.executePrivileged("dscacheutil -flushcache && killall -HUP mDNSResponder")
        appState.isLoading = false
        appState.showAlertMessage("DNS cache flushed")
    }
}

struct HealthIndicator: View {
    let score: Int

    var color: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(score)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct QuickStatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
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
    }
}

struct MenuBarButton: View {
    let title: String
    let icon: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                Text(title)

                Spacer()

                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}
