// MARK: - MenuBarContentView.swift
// CraigOClean Control Center - Menu Bar Mini-Dashboard
// Modern, visually appealing design with glass morphism and animations

import SwiftUI
import AppKit
import UserNotifications

// MARK: - Menu Bar Tab

enum MenuBarTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case memory = "Memory"
    case browser = "Browser"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .memory: return "memorychip"
        case .browser: return "safari"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - AutoCleanup Holder (prevents @State with class type crash)

final class AutoCleanupHolder: ObservableObject {
    @Published var service: AutoCleanupService?
}

// MARK: - Main Menu Bar Content View

struct MenuBarContentView: View {
    @StateObject private var systemMetrics = SystemMetricsService()
    @StateObject private var processManager = ProcessManager()
    @StateObject private var memoryOptimizer = MemoryOptimizerService()
    @StateObject private var browserAutomation = BrowserAutomationService()
    @StateObject private var autoCleanupHolder = AutoCleanupHolder()

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var userStore: LocalUserStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var trialManager: TrialManager

    let onExpandClick: () -> Void

    @State private var selectedTab: MenuBarTab = .dashboard
    @State private var isRefreshing = false
    @State private var showingPaywall = false
    @Namespace private var tabAnimation

    var body: some View {
        VStack(spacing: 0) {
            // Gradient Header
            headerSection

            // Modern Tab Bar
            modernTabBar

            // Tab Content
            tabContent
        }
        .frame(width: 380)
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
        .onAppear {
            systemMetrics.startMonitoring()
            processManager.updateProcessList()

            if autoCleanupHolder.service == nil {
                autoCleanupHolder.service = AutoCleanupService(
                    systemMetrics: systemMetrics,
                    memoryOptimizer: memoryOptimizer,
                    processManager: processManager
                )
            }

            Task {
                await memoryOptimizer.analyzeMemoryUsage()
                await browserAutomation.fetchAllTabs()
            }
        }
        .onDisappear {
            // Stop auto cleanup service to prevent memory leaks
            autoCleanupHolder.service?.disable()
            systemMetrics.stopMonitoring()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.vibePurple.opacity(0.8),
                    Color.vibeTeal.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content
            HStack(spacing: 12) {
                // App Icon with glow
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)

                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Craig-O-Clean")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        // Show appropriate badge based on subscription status
                        if subscriptions.isPro {
                            ProBadge()
                        } else if trialManager.isTrialActive {
                            TrialBadge(
                                daysRemaining: trialManager.trialDaysRemaining,
                                isExpired: false
                            )
                        } else if trialManager.subscriptionStatus == .trialExpired {
                            TrialBadge(daysRemaining: 0, isExpired: true)
                        }
                    }

                    // Status indicator
                    if let memory = systemMetrics.memoryMetrics {
                        HStack(spacing: 6) {
                            PulsingStatusDot(color: pressureColor(memory.pressureLevel))
                            Text(memory.pressureLevel.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Text("\(Int(memory.usedPercentage))% used")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Refresh button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isRefreshing = true
                    }
                    Task {
                        await systemMetrics.refreshAllMetrics()
                        await memoryOptimizer.analyzeMemoryUsage()
                        processManager.updateProcessList()
                        withAnimation { isRefreshing = false }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 70)
    }

    // MARK: - Modern Tab Bar

    private var modernTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MenuBarTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.vibePurple, .vibeTeal],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .matchedGeometryEffect(id: "tabIndicator", in: tabAnimation)
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .white : .secondary)
                        }
                        .frame(width: 36, height: 36)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .dashboard:
            MenuBarDashboardTab(
                systemMetrics: systemMetrics,
                processManager: processManager,
                memoryOptimizer: memoryOptimizer,
                onExpandClick: onExpandClick
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        case .memory:
            MenuBarMemoryTab(
                systemMetrics: systemMetrics,
                memoryOptimizer: memoryOptimizer
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        case .browser:
            MenuBarBrowserTab(
                browserAutomation: browserAutomation
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        case .settings:
            if let autoCleanup = autoCleanupHolder.service {
                MenuBarSettingsTab(
                    autoCleanup: autoCleanup,
                    onExpandClick: onExpandClick
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

// MARK: - Dashboard Tab

struct MenuBarDashboardTab: View {
    @ObservedObject var systemMetrics: SystemMetricsService
    @ObservedObject var processManager: ProcessManager
    @ObservedObject var memoryOptimizer: MemoryOptimizerService
    let onExpandClick: () -> Void

    @State private var animateGauges = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // System Gauges
                systemGaugesSection
                    .padding(.top, 8)

                // Quick Actions
                quickActionsSection

                // Running Apps
                runningAppsSection

                // Footer
                footerSection
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 400)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateGauges = true
            }
        }
    }

    private var systemGaugesSection: some View {
        HStack(spacing: 10) {
            if let cpu = systemMetrics.cpuMetrics {
                AnimatedGaugeCard(
                    icon: "cpu",
                    title: "CPU",
                    value: cpu.totalUsage,
                    color: cpuColor(cpu.totalUsage),
                    animate: animateGauges
                )
            }

            if let memory = systemMetrics.memoryMetrics {
                AnimatedGaugeCard(
                    icon: "memorychip",
                    title: "Memory",
                    value: memory.usedPercentage,
                    color: pressureColor(memory.pressureLevel),
                    animate: animateGauges
                )
            }

            if let disk = systemMetrics.diskMetrics {
                AnimatedGaugeCard(
                    icon: "internaldrive",
                    title: "Disk",
                    value: disk.usedPercentage,
                    color: diskColor(disk.usedPercentage),
                    animate: animateGauges
                )
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Quick Actions", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                ModernActionButton(
                    icon: "sparkles",
                    title: "Smart Clean",
                    gradient: [.blue, .purple]
                ) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.smartCleanup()
                        await showCleanupResult(result)
                    }
                }

                ModernActionButton(
                    icon: "moon.fill",
                    title: "Background",
                    gradient: [.purple, .pink]
                ) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupBackground()
                        await showCleanupResult(result)
                    }
                }

                ModernActionButton(
                    icon: "flame.fill",
                    title: "Heavy Apps",
                    gradient: [.orange, .red]
                ) {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupHeavy(limit: 3)
                        await showCleanupResult(result)
                    }
                }
            }
        }
    }

    private var runningAppsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Running Apps", systemImage: "app.badge")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(processManager.processes.filter { $0.isUserProcess }.count) apps")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.tertiaryLabelColor).opacity(0.1))
                    .clipShape(Capsule())
            }

            VStack(spacing: 4) {
                let topProcesses = Array(processManager.processes
                    .filter { $0.isUserProcess }
                    .sorted { $0.memoryUsage > $1.memoryUsage }
                    .prefix(5))

                ForEach(topProcesses) { process in
                    ModernProcessRow(
                        process: process,
                        onQuit: { quitProcess(process) },
                        onForceQuit: { forceQuitProcess(process) }
                    )
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            if let lastUpdate = systemMetrics.lastUpdateTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(lastUpdate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                }
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }

            Spacer()

            Button {
                onExpandClick()
            } label: {
                HStack(spacing: 6) {
                    Text("Open Full App")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.vibePurple, .vibeTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func quitProcess(_ process: ProcessInfo) {
        Task {
            let success = await processManager.terminateProcess(process)
            if success {
                processManager.updateProcessList()
            }
        }
    }

    private func forceQuitProcess(_ process: ProcessInfo) {
        Task {
            let success = await processManager.forceQuitProcess(process)
            if success {
                processManager.updateProcessList()
            }
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

    private func diskColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<70: return .green
        case 70..<85: return .yellow
        case 85..<95: return .orange
        default: return .red
        }
    }
}

// MARK: - Memory Tab

struct MenuBarMemoryTab: View {
    @ObservedObject var systemMetrics: SystemMetricsService
    @ObservedObject var memoryOptimizer: MemoryOptimizerService
    @StateObject private var privilegeService = PrivilegeService()

    @State private var lastResult: CleanupResult?
    @State private var showPurgeConfirmation = false
    @State private var isPurging = false
    @State private var purgeResult: PrivilegeOperationResult?
    @State private var animateRing = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Large Memory Ring
                memoryRingSection
                    .padding(.top, 8)

                // Memory Breakdown
                memoryBreakdownSection

                // Cleanup Buttons
                cleanupButtonsSection

                // Candidates
                cleanupCandidatesSection

                // Last Result
                if let result = lastResult {
                    lastResultSection(result)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 400)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateRing = true
            }
        }
    }

    private var memoryRingSection: some View {
        GlassCard {
            HStack(spacing: 20) {
                if let memory = systemMetrics.memoryMetrics {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Status")
                            .font(.system(size: 14, weight: .semibold))

                        HStack(spacing: 6) {
                            PulsingStatusDot(color: pressureColor(memory.pressureLevel))
                            Text(memory.pressureLevel.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(pressureColor(memory.pressureLevel))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(SystemMetricsService.formatBytes(memory.availableRAM))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("Available")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Animated Ring
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 10)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: animateRing ? memory.usedPercentage / 100 : 0)
                            .stroke(
                                AngularGradient(
                                    colors: [pressureColor(memory.pressureLevel), pressureColor(memory.pressureLevel).opacity(0.5)],
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(270)
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        // Center text
                        VStack(spacing: 0) {
                            Text("\(Int(memory.usedPercentage))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 90, height: 90)
                }
            }
            .padding(16)
        }
    }

    private var memoryBreakdownSection: some View {
        VStack(spacing: 8) {
            if let memory = systemMetrics.memoryMetrics {
                // Segmented bar
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        MemorySegment(
                            width: segmentWidth(for: memory.activeRAM, total: memory.totalRAM, in: geometry),
                            color: .orange
                        )
                        MemorySegment(
                            width: segmentWidth(for: memory.wiredRAM, total: memory.totalRAM, in: geometry),
                            color: .red
                        )
                        MemorySegment(
                            width: segmentWidth(for: memory.compressedRAM, total: memory.totalRAM, in: geometry),
                            color: .purple
                        )
                        Spacer(minLength: 0)
                    }
                    .background(Color.green.opacity(0.3))
                    .clipShape(Capsule())
                }
                .frame(height: 8)

                // Legend
                HStack(spacing: 16) {
                    ModernLegendItem(color: .orange, label: "App")
                    ModernLegendItem(color: .red, label: "Wired")
                    ModernLegendItem(color: .purple, label: "Compressed")
                    ModernLegendItem(color: .green.opacity(0.5), label: "Free")
                }
            }
        }
    }

    private var cleanupButtonsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                GradientCleanupButton(
                    title: "Smart Clean",
                    icon: "sparkles",
                    gradient: [.blue, .purple]
                ) {
                    Task {
                        // Refresh analysis before cleanup to ensure accurate candidate list
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.smartCleanup()
                        lastResult = result
                    }
                }

                GradientCleanupButton(
                    title: "Background",
                    icon: "moon.fill",
                    gradient: [.purple, .pink]
                ) {
                    Task {
                        // Refresh analysis before cleanup to ensure accurate candidate list
                        await memoryOptimizer.analyzeMemoryUsage()
                        let result = await memoryOptimizer.quickCleanupBackground()
                        lastResult = result
                    }
                }
            }

            // Memory Purge Button
            memoryPurgeButton
        }
    }

    private var memoryPurgeButton: some View {
        Button {
            showPurgeConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isPurging {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory Clean")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Flush buffers & purge inactive memory")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.vibePurple.opacity(0.15))
            .foregroundColor(.vibePurple)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isPurging)
        .alert("Memory Clean", isPresented: $showPurgeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                performMemoryPurge()
            }
        } message: {
            Text("This will run system commands to flush file system buffers and purge inactive memory.\n\nResults may vary depending on your system state. You may be prompted for your administrator password.")
        }
        .sheet(item: Binding(
            get: { purgeResult.map { PurgeResultWrapper(result: $0) } },
            set: { _ in purgeResult = nil }
        )) { wrapper in
            PurgeResultSheet(result: wrapper.result, onDismiss: { purgeResult = nil })
        }
    }

    private func performMemoryPurge() {
        isPurging = true
        Task {
            // Check helper status first
            await privilegeService.checkHelperStatus()

            // Execute memory cleanup
            let result = await privilegeService.executeMemoryCleanup()
            purgeResult = result
            isPurging = false

            // Refresh metrics after purge
            await systemMetrics.refreshAllMetrics()
        }
    }

    private var cleanupCandidatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Cleanup Candidates", systemImage: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if !memoryOptimizer.cleanupCandidates.isEmpty {
                    Text("\(memoryOptimizer.cleanupCandidates.count) apps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if memoryOptimizer.isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if memoryOptimizer.cleanupCandidates.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Memory is optimized")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(memoryOptimizer.cleanupCandidates.prefix(4))) { candidate in
                        CandidateRow(candidate: candidate)
                    }
                }
            }
        }
    }

    private func lastResultSection(_ result: CleanupResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(result.success ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: result.success ? "checkmark" : "exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(result.success ? .green : .yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Cleanup Complete")
                    .font(.system(size: 12, weight: .semibold))
                Text("Freed \(result.formattedMemoryFreed)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private func segmentWidth(for bytes: UInt64, total: UInt64, in geometry: GeometryProxy) -> CGFloat {
        let percentage = Double(bytes) / Double(total)
        return max(0, geometry.size.width * CGFloat(percentage) - 2)
    }
}

// MARK: - Browser Tab

struct MenuBarBrowserTab: View {
    @ObservedObject var browserAutomation: BrowserAutomationService

    @State private var selectedTabs: Set<BrowserTab> = []
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            browserHeaderSection

            // Content
            if browserAutomation.isLoading && browserAutomation.allTabs.isEmpty {
                // Show loading state when fetching tabs
                loadingStateView
            } else if browserAutomation.runningBrowsers.isEmpty {
                emptyStateView(icon: "safari", title: "No Browsers Running", subtitle: "Open a browser to manage tabs")
            } else if browserAutomation.allTabs.isEmpty, let error = browserAutomation.lastError {
                // Show error state only when tab fetch fails AND no tabs were retrieved
                errorStateView(error: error)
            } else if browserAutomation.allTabs.isEmpty {
                emptyStateView(icon: "checkmark.circle", title: "No Tabs Found", subtitle: "All tabs are already optimized")
            } else {
                tabListSection
                actionsSection
            }
        }
        .frame(height: 400)
        .onAppear {
            // Refresh tabs when browser tab view appears
            if browserAutomation.allTabs.isEmpty && !browserAutomation.isLoading {
                Task {
                    await browserAutomation.fetchAllTabs()
                }
            }
        }
    }

    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.vibePurple.opacity(0.1))
                    .frame(width: 70, height: 70)

                ProgressView()
                    .scaleEffect(1.2)
            }

            Text("Loading Browser Tabs...")
                .font(.system(size: 14, weight: .semibold))

            Text("Fetching tabs from running browsers")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorStateView(error: BrowserAutomationError) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }

            Text("Unable to Access Tabs")
                .font(.system(size: 14, weight: .semibold))

            Text(error.localizedDescription ?? "An unknown error occurred")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if case .automationPermissionDenied = error {
                Button {
                    // Open System Settings to Automation
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 11))
                        Text("Open System Settings")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.vibePurple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                Task {
                    await browserAutomation.fetchAllTabs()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Try Again")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.vibePurple)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.vibePurple.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var browserHeaderSection: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Browser Tabs")
                            .font(.system(size: 14, weight: .semibold))

                        if browserAutomation.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        }
                    }

                    if browserAutomation.isLoading {
                        Text("Fetching tabs...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(browserAutomation.allTabs.count) tabs across \(browserAutomation.runningBrowsers.count) browsers")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring()) { isRefreshing = true }
                    // Clear selected tabs to prevent stale references after refresh
                    selectedTabs.removeAll()
                    Task {
                        await browserAutomation.fetchAllTabs()
                        withAnimation { isRefreshing = false }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.vibePurple.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.vibePurple)
                            .rotationEffect((isRefreshing || browserAutomation.isLoading) ? .degrees(360) : .degrees(0))
                            .animation((isRefreshing || browserAutomation.isLoading) ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing || browserAutomation.isLoading)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing || browserAutomation.isLoading)
            }
            .padding(14)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabListSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(browserAutomation.allTabs.prefix(15)) { tab in
                    ModernBrowserTabRow(
                        tab: tab,
                        isSelected: selectedTabs.contains(tab),
                        onToggle: {
                            if selectedTabs.contains(tab) {
                                selectedTabs.remove(tab)
                            } else {
                                selectedTabs.insert(tab)
                            }
                        },
                        onClose: {
                            Task {
                                try? await browserAutomation.closeTab(tab)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 10) {
            if !selectedTabs.isEmpty {
                Button {
                    Task {
                        for tab in selectedTabs {
                            try? await browserAutomation.closeTab(tab)
                        }
                        selectedTabs.removeAll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Close \(selectedTabs.count)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Select All") {
                selectedTabs = Set(browserAutomation.allTabs)
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Clear") {
                selectedTabs.removeAll()
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedTabs.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
    }
}

// MARK: - Settings Tab

struct MenuBarSettingsTab: View {
    @ObservedObject var autoCleanup: AutoCleanupService
    let onExpandClick: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Auto-cleanup toggle
                autoCleanupCard
                    .padding(.top, 8)

                // Stats (if enabled)
                if autoCleanup.isEnabled {
                    statsCard
                    thresholdsCard
                }

                // Actions
                actionsSection

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 400)
    }

    private var autoCleanupCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.vibePurple, .vibeTeal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Cleanup")
                            .font(.system(size: 14, weight: .semibold))
                        Text(autoCleanup.isEnabled ? "Actively monitoring" : "Currently disabled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { autoCleanup.isEnabled },
                        set: { newValue in
                            if newValue {
                                autoCleanup.enable()
                            } else {
                                autoCleanup.disable()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.vibePurple)
                }

                if autoCleanup.isEnabled {
                    HStack(spacing: 8) {
                        PulsingStatusDot(color: .green)
                        Text("System protection active")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(14)
        }
    }

    private var statsCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Label("Statistics", systemImage: "chart.bar.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 0) {
                    StatBox(value: "\(autoCleanup.totalCleanups)", label: "Cleanups", color: .blue)
                    Divider().frame(height: 40)
                    StatBox(value: formatBytes(Int64(autoCleanup.totalMemoryFreed)), label: "Freed", color: .green)
                    Divider().frame(height: 40)
                    StatBox(value: "\(autoCleanup.totalProcessesTerminated)", label: "Closed", color: .orange)
                }
            }
            .padding(14)
        }
    }

    private var thresholdsCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack {
                    Label("Thresholds", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                ThresholdRow(label: "Memory Warning", value: Int(autoCleanup.thresholds.memoryWarning), color: .yellow)
                ThresholdRow(label: "Memory Critical", value: Int(autoCleanup.thresholds.memoryCritical), color: .red)
                ThresholdRow(label: "CPU Warning", value: Int(autoCleanup.thresholds.cpuWarning), color: .orange)
            }
            .padding(14)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await autoCleanup.triggerImmediateCleanup()
                }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Trigger Immediate Cleanup")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: autoCleanup.isEnabled ? [.vibePurple, .vibeTeal] : [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!autoCleanup.isEnabled)

            Button {
                onExpandClick()
            } label: {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                    Text("Open Full Settings")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1fG", mb / 1024.0)
        } else if mb >= 1 {
            return String(format: "%.0fM", mb)
        } else {
            return "0"
        }
    }
}

// MARK: - Supporting Views

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
    }
}

struct PulsingStatusDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 12, height: 12)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct AnimatedGaugeCard: View {
    let icon: String
    let title: String
    let value: Double
    let color: Color
    let animate: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 5)

                // Progress circle
                Circle()
                    .trim(from: 0, to: animate ? value / 100 : 0)
                    .stroke(
                        AngularGradient(
                            colors: [color, color.opacity(0.5)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Value text
                Text("\(Int(value))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(width: 50, height: 50)

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

struct ModernActionButton: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: gradient[0].opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 1 : 0.6))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ModernProcessRow: View {
    let process: ProcessInfo
    let onQuit: () -> Void
    let onForceQuit: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // App Icon
            if let bundleId = process.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 24, height: 24)

                    Image(systemName: process.isUserProcess ? "app.fill" : "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Name
            Text(process.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            // Memory usage
            Text(process.formattedMemoryUsage)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            // Close button (on hover)
            if isHovered {
                Button(action: onForceQuit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Quit") { onQuit() }
            Button("Force Quit") { onForceQuit() }
        }
    }
}

struct MemorySegment: View {
    let width: CGFloat
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, width))
    }
}

struct ModernLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct GradientCleanupButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: gradient[0].opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CandidateRow: View {
    let candidate: CleanupCandidate

    var body: some View {
        HStack(spacing: 10) {
            if let icon = candidate.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 20, height: 20)
            }

            Text(candidate.name)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Text(candidate.formattedMemoryUsage)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ModernBrowserTabRow: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onToggle: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Selection indicator
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .vibePurple : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Browser icon
            Image(systemName: tab.browser.icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            // Tab info
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                Text(tab.domain)
                    .font(.system(size: 9))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .lineLimit(1)
            }

            Spacer()

            // Close button
            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.vibePurple.opacity(0.1) : (isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.2) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.vibePurple.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ThresholdRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Legacy Supporting Views (kept for compatibility)

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

struct MiniStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QuickActionPill: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isHovered ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? color : color.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MiniProcessRow: View {
    let process: ProcessInfo
    let onQuit: () -> Void
    let onForceQuit: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if let bundleId = process.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: process.isUserProcess ? "app" : "gear")
                    .frame(width: 18, height: 18)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(process.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(process.formattedMemoryUsage)
                .font(.caption)
                .foregroundColor(.secondary)

            if isHovered {
                Button {
                    onForceQuit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Quit") { onQuit() }
            Button("Force Quit") { onForceQuit() }
        }
    }
}

struct CleanupButton: View {
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
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct BrowserTabRow: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onToggle: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .onTapGesture { onToggle() }

            Image(systemName: tab.browser.icon)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(tab.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(tab.domain)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Function

private func showCleanupResult(_ result: CleanupResult) async {
    if result.appsTerminated > 0 {
        let content = UNMutableNotificationContent()
        content.title = "Cleanup Complete"
        content.body = "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) apps"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Log notification failure but don't disrupt user experience
            await AppLogger.shared.warning("Failed to show cleanup notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - Purge Result Support

struct PurgeResultWrapper: Identifiable {
    let id = UUID()
    let result: PrivilegeOperationResult
}

struct PurgeResultSheet: View {
    let result: PrivilegeOperationResult
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Status icon
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(result.success ? .vibeTeal : .vibeAmber)

            // Title
            Text(result.success ? "Memory Clean Complete" : "Memory Clean Issue")
                .font(.headline)

            // Message
            Text(result.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Output (if any)
            if let output = result.output, !output.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Details")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

            // Dismiss button
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(result.success ? .vibeTeal : .vibePurple)
        }
        .padding(24)
        .frame(width: 320)
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView(onExpandClick: {})
        .environmentObject(AuthManager.shared)
        .environmentObject(LocalUserStore.shared)
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(TrialManager.shared)
}
