// MARK: - MainAppView.swift
// Craig-O-Clean - Main Application View
// Provides sidebar navigation to all major screens

import SwiftUI

// MARK: - Navigation Items

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case processes = "Processes"
    case memoryCleanup = "Memory Cleanup"
    case autoCleanup = "Auto-Cleanup"
    case browserTabs = "Browser Tabs"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .processes: return "list.bullet.rectangle"
        case .memoryCleanup: return "memorychip"
        case .autoCleanup: return "wand.and.stars"
        case .browserTabs: return "safari"
        case .settings: return "gearshape"
        }
    }

    var description: String {
        switch self {
        case .dashboard: return "System overview"
        case .processes: return "Running apps & processes"
        case .memoryCleanup: return "Free up memory"
        case .autoCleanup: return "Automatic resource management"
        case .browserTabs: return "Manage browser tabs"
        case .settings: return "App settings & permissions"
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    @StateObject private var systemMetrics = SystemMetricsService()
    @StateObject private var processManager = ProcessManager()
    @StateObject private var memoryOptimizer = MemoryOptimizerService()
    @StateObject private var browserAutomation = BrowserAutomationService()
    @StateObject private var permissions = PermissionsService()
    @StateObject private var autoCleanup: AutoCleanupService

    @State private var selectedItem: NavigationItem = .dashboard
    @State private var showOnboarding = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let systemMetrics = SystemMetricsService()
        let processManager = ProcessManager()
        let memoryOptimizer = MemoryOptimizerService()

        _systemMetrics = StateObject(wrappedValue: systemMetrics)
        _processManager = StateObject(wrappedValue: processManager)
        _memoryOptimizer = StateObject(wrappedValue: memoryOptimizer)
        _browserAutomation = StateObject(wrappedValue: BrowserAutomationService())
        _permissions = StateObject(wrappedValue: PermissionsService())
        _autoCleanup = StateObject(wrappedValue: AutoCleanupService(
            systemMetrics: systemMetrics,
            memoryOptimizer: memoryOptimizer,
            processManager: processManager
        ))
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(NavigationItem.allCases, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.rawValue)
                                .font(.headline)
                            Text(item.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundColor(iconColor(for: item))
                            .frame(width: 24)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .safeAreaInset(edge: .top) {
                // App header in sidebar
                VStack(spacing: 8) {
                    HStack {
                        if let appIcon = NSApp.applicationIconImage {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.vibePurple)
                        }

                        Text("Craig-O-Clean")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Quick status indicators
                    if let memory = systemMetrics.memoryMetrics {
                        HStack(spacing: 8) {
                            StatusPill(
                                icon: "memorychip",
                                value: SystemMetricsService.formatPercentage(memory.usedPercentage),
                                color: pressureColor(memory.pressureLevel)
                            )
                            
                            if let cpu = systemMetrics.cpuMetrics {
                                StatusPill(
                                    icon: "cpu",
                                    value: SystemMetricsService.formatPercentage(cpu.totalUsage),
                                    color: cpuColor(cpu.totalUsage)
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            .safeAreaInset(edge: .bottom) {
                // Version info
                VStack(spacing: 4) {
                    Divider()
                    Text("Craig-O-Clean")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Version 1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        } detail: {
            // Detail view based on selection
            detailView(for: selectedItem)
                .frame(minWidth: 600, minHeight: 500)
        }
        .onAppear {
            systemMetrics.startMonitoring()
            
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding) {
                hasCompletedOnboarding = true
            }
        }
        .environmentObject(systemMetrics)
        .environmentObject(processManager)
        .environmentObject(memoryOptimizer)
        .environmentObject(browserAutomation)
        .environmentObject(permissions)
        .environmentObject(autoCleanup)
    }

    // MARK: - Detail View Builder

    @ViewBuilder
    private func detailView(for item: NavigationItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .processes:
            ProcessManagerView()
        case .memoryCleanup:
            MemoryCleanupView()
        case .autoCleanup:
            AutoCleanupSettingsView(autoCleanup: autoCleanup)
        case .browserTabs:
            BrowserTabsView()
        case .settings:
            SettingsPermissionsView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func iconColor(for item: NavigationItem) -> Color {
        switch item {
        case .dashboard: return .blue
        case .processes: return .green
        case .memoryCleanup: return .orange
        case .autoCleanup: return .vibePurple
        case .browserTabs: return .purple
        case .settings: return .gray
        }
    }
    
    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<60: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Status Pill Component

struct StatusPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    
    private let pages: [(title: String, description: String, icon: String, color: Color)] = [
        ("Welcome to CraigOClean", "Your intelligent system monitor and memory optimizer for macOS", "brain.head.profile", .blue),
        ("Monitor System Health", "Keep track of CPU, memory, disk, and network usage in real-time", "gauge.with.dots.needle.bottom.50percent", .green),
        ("Manage Processes", "View and control running applications with ease", "list.bullet.rectangle", .orange),
        ("Optimize Memory", "Free up RAM safely with guided cleanup workflows", "memorychip", .purple),
        ("Browser Tab Management", "Control tabs across Safari, Chrome, Edge, and more", "safari", .cyan),
        ("Permissions Required", "CraigOClean needs Automation permission to control browsers. You can configure this in Settings.", "lock.shield", .red)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: page.icon)
                            .font(.system(size: 80))
                            .foregroundColor(page.color)
                        
                        Text(page.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(page.description)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            
            // Navigation controls
            HStack {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            onComplete()
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Preview

#Preview {
    MainAppView()
        .frame(width: 1000, height: 700)
}
