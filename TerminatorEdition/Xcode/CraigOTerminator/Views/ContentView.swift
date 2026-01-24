import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            DetailView()
                .navigationSplitViewColumnWidth(min: 600, ideal: 800)
        }
        .navigationSplitViewStyle(.balanced)
        .overlay {
            if appState.isLoading {
                LoadingOverlay()
            }
        }
        .overlay(alignment: .bottom) {
            if appState.showAlert, let message = appState.alertMessage {
                AlertBanner(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: appState.showAlert)
            }
        }
        .sheet(isPresented: $appState.showAbout) {
            AboutView()
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedTab) {
                Section {
                    ForEach(AppState.TabSelection.allCases.prefix(5), id: \.self) { tab in
                        NavigationLink(value: tab) {
                            Label(tab.rawValue, systemImage: tab.icon)
                        }
                    }
                } header: {
                    HStack {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        VStack(alignment: .leading) {
                            Text("Craig-O")
                                .font(.headline)
                            Text("Terminator")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                    .padding(.bottom, 10)
                }

                Section("AI & Automation") {
                    NavigationLink(value: AppState.TabSelection.agents) {
                        Label("Agents", systemImage: "brain.head.profile")
                    }
                }

                Section("System") {
                    NavigationLink(value: AppState.TabSelection.settings) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(spacing: 8) {
                // Quick action buttons
                HStack(spacing: 8) {
                    QuickActionButton(
                        title: "Quick",
                        icon: "bolt.fill",
                        color: .blue
                    ) {
                        Task { await appState.performQuickCleanup() }
                    }

                    QuickActionButton(
                        title: "Full",
                        icon: "sparkles",
                        color: .green
                    ) {
                        Task { await appState.performFullCleanup() }
                    }

                    QuickActionButton(
                        title: "Emergency",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    ) {
                        Task { await appState.performEmergencyCleanup() }
                    }
                }
                .padding(.horizontal)

                // Health indicator
                HStack {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 10, height: 10)
                    Text("Health: \(appState.healthScore)/100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if appState.isAIEnabled {
                        Label("AI", systemImage: "brain")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
        }
        .frame(minWidth: 220)
    }

    private var healthColor: Color {
        if appState.healthScore >= 80 { return .green }
        if appState.healthScore >= 60 { return .yellow }
        return .red
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView()
        case .cleanup:
            CleanupView()
        case .browsers:
            BrowsersView()
        case .processes:
            ProcessesView()
        case .diagnostics:
            DiagnosticsView()
        case .agents:
            AgentsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .shadow(color: .red.opacity(0.5), radius: 20)

                ProgressView(value: appState.operationProgress) {
                    Text(appState.currentOperation)
                        .font(.headline)
                }
                .progressViewStyle(.linear)
                .frame(width: 300)

                Text("\(Int(appState.operationProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Alert Banner

struct AlertBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .frame(width: 1000, height: 700)
}
