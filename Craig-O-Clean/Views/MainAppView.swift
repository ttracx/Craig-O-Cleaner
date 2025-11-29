// MainAppView.swift
// ClearMind Control Center
//
// Main application view with sidebar navigation
// Provides access to Dashboard, Processes, Memory Cleanup, Browser Tabs, and Settings

import SwiftUI

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case processes = "Processes"
    case memoryCleanup = "Memory Cleanup"
    case browserTabs = "Browser Tabs"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.pie"
        case .processes: return "list.bullet.rectangle.portrait"
        case .memoryCleanup: return "memorychip"
        case .browserTabs: return "globe"
        case .settings: return "gearshape"
        }
    }
    
    var color: Color {
        switch self {
        case .dashboard: return .blue
        case .processes: return .green
        case .memoryCleanup: return .orange
        case .browserTabs: return .purple
        case .settings: return .gray
        }
    }
}

struct MainAppView: View {
    @State private var selectedTab: NavigationTab = .dashboard
    @StateObject private var processManager = ProcessManager()
    @StateObject private var metricsService = SystemMetricsService()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // App header
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ClearMind")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Control Center")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Navigation items
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(NavigationTab.allCases) { tab in
                            NavigationButton(
                                tab: tab,
                                isSelected: selectedTab == tab
                            ) {
                                selectedTab = tab
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Quick stats at bottom
                quickStatsView
                    .padding()
            }
            .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
            .background(Color(NSColor.windowBackgroundColor))
        } detail: {
            // Main content
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .processes:
                    ProcessesView(processManager: processManager)
                case .memoryCleanup:
                    MemoryCleanupView()
                case .browserTabs:
                    BrowserTabsView()
                case .settings:
                    PermissionsView()
                }
            }
            .frame(minWidth: 600)
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Quick Stats View
    
    private var quickStatsView: some View {
        VStack(spacing: 12) {
            // CPU
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text("CPU")
                    .font(.caption)
                Spacer()
                Text(cpuUsageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(cpuColor)
            }
            
            // Memory
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.orange)
                    .frame(width: 20)
                Text("Memory")
                    .font(.caption)
                Spacer()
                Text(memoryUsageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(memoryColor)
            }
            
            // Processes
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.green)
                    .frame(width: 20)
                Text("Processes")
                    .font(.caption)
                Spacer()
                Text("\(processManager.processes.count)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var cpuUsageText: String {
        guard let cpu = metricsService.cpuMetrics else { return "--" }
        return String(format: "%.1f%%", cpu.overallUsage)
    }
    
    private var cpuColor: Color {
        guard let cpu = metricsService.cpuMetrics else { return .secondary }
        if cpu.overallUsage < 50 { return .green }
        else if cpu.overallUsage < 80 { return .orange }
        else { return .red }
    }
    
    private var memoryUsageText: String {
        guard let memory = metricsService.memoryMetrics else { return "--" }
        return String(format: "%.1f%%", memory.usedPercentage)
    }
    
    private var memoryColor: Color {
        guard let memory = metricsService.memoryMetrics else { return .secondary }
        if memory.usedPercentage < 60 { return .green }
        else if memory.usedPercentage < 80 { return .orange }
        else { return .red }
    }
}

// MARK: - Navigation Button

struct NavigationButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? tab.color : .secondary)
                    .frame(width: 24)
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? tab.color.opacity(0.15) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? tab.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Processes View Wrapper

struct ProcessesView: View {
    @ObservedObject var processManager: ProcessManager
    
    var body: some View {
        ContentView()
    }
}

#Preview {
    MainAppView()
        .frame(width: 1100, height: 750)
}
