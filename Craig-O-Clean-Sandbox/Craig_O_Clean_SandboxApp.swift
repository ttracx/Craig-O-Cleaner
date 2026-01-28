// MARK: - Craig_O_Clean_SandboxApp.swift
// Craig-O-Clean Sandbox Edition - Main Application Entry Point
// A fully sandboxed macOS utility for system optimization

import SwiftUI
import AppKit
import UserNotifications

@main
struct Craig_O_Clean_SandboxApp: App {
    @NSApplicationDelegateAdaptor(SandboxAppDelegate.self) var appDelegate

    // Core services
    @StateObject private var metricsProvider = SandboxMetricsProvider()
    @StateObject private var processManager = SandboxProcessManager()
    @StateObject private var permissionsManager = SandboxPermissionsManager()
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager()

    // Browser automation (initialized lazily with permissions manager)
    @StateObject private var browserAutomation: SandboxBrowserAutomation

    init() {
        // Initialize browser automation with permissions manager
        let permissions = SandboxPermissionsManager()
        _browserAutomation = StateObject(wrappedValue: SandboxBrowserAutomation(permissionsManager: permissions))
    }

    var body: some Scene {
        // Main window
        WindowGroup {
            SandboxMainAppView()
                .environmentObject(metricsProvider)
                .environmentObject(processManager)
                .environmentObject(permissionsManager)
                .environmentObject(bookmarkManager)
                .environmentObject(browserAutomation)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Craig-O-Clean Sandbox") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Craig-O-Clean Sandbox Edition",
                        .applicationVersion: SandboxConfiguration.appVersion,
                        .credits: NSAttributedString(string: """
                            Mac App Store Edition

                            A fully sandboxed system utility for:
                            • Monitoring system resources
                            • Managing running applications
                            • Browser tab optimization
                            • User-scoped file cleanup

                            © 2026 CraigOClean.com
                            """)
                    ])
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    // App Store apps update through the App Store
                    if let url = URL(string: "macappstore://apps.apple.com/app/idXXXXXXXXXX") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            CommandMenu("Actions") {
                Button("Refresh All Data") {
                    Task {
                        await metricsProvider.refreshAllMetrics()
                        processManager.updateProcessList()
                        await browserAutomation.fetchAllTabs()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Close Background Apps") {
                    Task {
                        await closeBackgroundApps()
                    }
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Close Heavy Browser Tabs") {
                    Task {
                        try? await browserAutomation.closeHeavyTabs()
                    }
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        // Settings window
        Settings {
            SandboxSettingsView()
                .environmentObject(permissionsManager)
                .environmentObject(bookmarkManager)
        }
    }

    // MARK: - Actions

    @MainActor
    private func closeBackgroundApps() async {
        let backgroundApps = processManager.getBackgroundApps()
        var closedCount = 0

        for app in backgroundApps.prefix(10) {
            let result = await processManager.quitApp(app)
            if case .success = result {
                closedCount += 1
            }
        }

        processManager.updateProcessList()

        // Show notification
        let content = UNMutableNotificationContent()
        content.title = "Background Apps Closed"
        content.body = "Closed \(closedCount) background applications"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - App Delegate

@MainActor
class SandboxAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    // Services (will be set from app)
    private var metricsProvider: SandboxMetricsProvider?
    private var processManager: SandboxProcessManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        requestNotificationPermissions()

        // Initialize services for menu bar
        metricsProvider = SandboxMetricsProvider()
        processManager = SandboxProcessManager()

        // Setup menu bar status item
        setupMenuBarItem()

        // Start monitoring
        metricsProvider?.startMonitoring()

        print("Craig-O-Clean Sandbox Edition launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        metricsProvider?.stopMonitoring()
        processManager?.stopAutoUpdate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show main window when dock icon is clicked
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Craig-O-Clean")
            button.image?.isTemplate = true
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover for quick status
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView()
                .environmentObject(metricsProvider ?? SandboxMetricsProvider())
                .environmentObject(processManager ?? SandboxProcessManager())
        )

        // Update status bar periodically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatusBarIcon()
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Show context menu
            showContextMenu(sender)
        } else {
            // Toggle popover
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        // Memory status
        if let memory = metricsProvider?.memoryMetrics {
            let statusItem = NSMenuItem(
                title: "Memory: \(String(format: "%.0f%%", memory.usedPercentage)) used",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Quick actions
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // Open main window
        let openItem = NSMenuItem(title: "Open Control Center", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
    }

    @objc private func refreshData() {
        Task { @MainActor in
            await metricsProvider?.refreshAllMetrics()
            processManager?.updateProcessList()
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(self)
        }
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }

        // Update tooltip with current status
        if let memory = metricsProvider?.memoryMetrics {
            button.toolTip = String(format: "Craig-O-Clean\nMemory: %.0f%% used (%@ / %@)",
                                    memory.usedPercentage,
                                    memory.formattedUsedRAM,
                                    memory.formattedTotalRAM)
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Menu Bar Popover View

struct MenuBarPopoverView: View {
    @EnvironmentObject var metricsProvider: SandboxMetricsProvider
    @EnvironmentObject var processManager: SandboxProcessManager

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Craig-O-Clean")
                    .font(.headline)
                Spacer()
                Text("Sandbox Edition")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)

            Divider()

            // Memory Status
            if let memory = metricsProvider.memoryMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: memory.pressureLevel.icon)
                            .foregroundColor(pressureColor(memory.pressureLevel))
                        Text("Memory")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.0f%%", memory.usedPercentage))
                    }

                    ProgressView(value: memory.usedPercentage / 100)
                        .progressViewStyle(.linear)
                        .tint(pressureColor(memory.pressureLevel))

                    HStack {
                        Text("\(memory.formattedUsedRAM) used")
                        Spacer()
                        Text("\(memory.formattedTotalRAM) total")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Divider()

            // Top Memory Users
            VStack(alignment: .leading, spacing: 6) {
                Text("Top Memory Users")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(processManager.getTopMemoryConsumers(limit: 3)) { process in
                    HStack {
                        if let icon = process.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        Text(process.name)
                            .lineLimit(1)
                        Spacer()
                        Text(process.formattedMemoryUsage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Quick Actions
            HStack(spacing: 8) {
                Button("Refresh") {
                    Task {
                        await metricsProvider.refreshAllMetrics()
                        processManager.updateProcessList()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Open App") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func pressureColor(_ level: SandboxMemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
