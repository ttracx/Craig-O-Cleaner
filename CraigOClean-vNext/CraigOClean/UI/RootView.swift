// File: CraigOClean-vNext/CraigOClean/UI/RootView.swift
// Craig-O-Clean - Root View
// Main application view with navigation

import SwiftUI

struct RootView: View {

    // MARK: - Properties

    @EnvironmentObject private var container: DIContainer
    @EnvironmentObject private var environment: AppEnvironment

    @State private var selectedTab: NavigationTab = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                editionBadge
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .cleanup:
            CleanupView()
        case .diagnostics:
            DiagnosticsView()
        case .settings:
            SettingsView()
        case .logs:
            LogConsoleView()
        }
    }

    // MARK: - Edition Badge

    private var editionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: environment.isPro ? "star.fill" : "star")
                .foregroundColor(environment.isPro ? .yellow : .secondary)

            Text(environment.edition.shortName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(environment.isPro ? Color.yellow.opacity(0.2) : Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Navigation Tab

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case cleanup = "Cleanup"
    case diagnostics = "Diagnostics"
    case settings = "Settings"
    case logs = "Logs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .cleanup: return "trash"
        case .diagnostics: return "stethoscope"
        case .settings: return "gearshape"
        case .logs: return "doc.text"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(DIContainer.shared)
            .environmentObject(AppEnvironment.shared)
            .environmentObject(DIContainer.shared.logStore)
    }
}
#endif
