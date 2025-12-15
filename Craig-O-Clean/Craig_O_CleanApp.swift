// MARK: - Craig_O_CleanApp.swift
// Craig-O-Clean - Main Application Entry Point
// A macOS system utility for Apple Silicon Macs

import SwiftUI
import AppKit
import UserNotifications

@main
struct Craig_O_CleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene (required but hidden for menu bar apps)
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var fullWindow: NSWindow?
    var windowDelegate: WindowDelegate?
    
    // Services
    private var systemMetrics: SystemMetricsService?
    private var processManager: ProcessManager?
    
    // Menu items that need dynamic updates
    private var runningAppsMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize system metrics for menu bar updates
        systemMetrics = SystemMetricsService()
        processManager = ProcessManager()

        // Request notification permissions
        requestNotificationPermissions()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Try to use app icon, fallback to system symbol
            if let appIcon = NSApp.applicationIconImage {
                let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
                resizedIcon.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                resizedIcon.unlockFocus()
                button.image = resizedIcon
                button.image?.isTemplate = true
            } else {
                button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Craig-O-Clean")
            }
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Add memory pressure indicator
            updateStatusBarIcon()
        }

        // Create context menu
        createContextMenu()

        // Create popover with new MenuBarContentView
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 520)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarContentView(onExpandClick: { [weak self] in
                self?.openFullWindow()
            })
            .environmentObject(AuthManager.shared)
            .environmentObject(LocalUserStore.shared)
            .environmentObject(SubscriptionManager.shared)
            .environmentObject(StripeCheckoutService.shared)
        )

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
        
        // Start monitoring for status bar updates
        Task { @MainActor in
            systemMetrics?.startMonitoring()
        }
        
        // Schedule periodic status bar icon updates
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusBarIcon()
            }
        }
    }
    
    @MainActor
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        // Determine system health based on memory metrics
        var healthSymbol = "sparkles" // Default - healthy
        var healthColor: NSColor = .systemGreen
        
        if let memoryMetrics = systemMetrics?.memoryMetrics {
            switch memoryMetrics.pressureLevel {
            case .normal:
                healthSymbol = "sparkles"
                healthColor = .systemGreen
            case .warning:
                healthSymbol = "exclamationmark.triangle"
                healthColor = .systemYellow
            case .critical:
                healthSymbol = "exclamationmark.octagon"
                healthColor = .systemRed
            }
        }
        
        // Also check CPU usage if available
        if let cpuMetrics = systemMetrics?.cpuMetrics {
            if cpuMetrics.totalUsage > 90 {
                healthSymbol = "exclamationmark.octagon"
                healthColor = .systemRed
            } else if cpuMetrics.totalUsage > 75 && healthSymbol == "sparkles" {
                healthSymbol = "exclamationmark.triangle"
                healthColor = .systemYellow
            }
        }
        
        // Create the icon with health indicator
        if let baseImage = NSImage(systemSymbolName: healthSymbol, accessibilityDescription: "System Health") {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let symbolImage = baseImage.withSymbolConfiguration(config)
            
            // For template images, the color comes from the system
            // To show color, we need to create a non-template image
            if healthColor != .systemGreen {
                // Create a colored version for warning/critical states
                let coloredImage = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                    healthColor.set()
                    symbolImage?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    return true
                }
                button.image = coloredImage
                button.image?.isTemplate = false
            } else {
                // Use template mode for normal state (follows system appearance)
                button.image = symbolImage
                button.image?.isTemplate = true
            }
        }
        
        // Update tooltip with current status
        if let memory = systemMetrics?.memoryMetrics {
            button.toolTip = String(format: "Memory: %.0f%% used (%.1f GB / %.1f GB)", 
                                    memory.usedPercentage,
                                    memory.usedRAM,
                                    memory.totalRAM)
        }
    }

    func createContextMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // About menu item
        let aboutItem = NSMenuItem(
            title: "About Craig-O-Clean",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())
        
        // Running Apps submenu (for force quit)
        let runningAppsMenu = NSMenu()
        let runningAppsItem = NSMenuItem(title: "Force Quit App", action: nil, keyEquivalent: "")
        runningAppsItem.submenu = runningAppsMenu
        runningAppsMenuItem = runningAppsItem
        menu.addItem(runningAppsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Actions submenu
        let quickActionsMenu = NSMenu()
        
        let smartCleanupItem = NSMenuItem(title: "Smart Cleanup", action: #selector(performSmartCleanup), keyEquivalent: "")
        smartCleanupItem.target = self
        quickActionsMenu.addItem(smartCleanupItem)
        
        let closeBackgroundItem = NSMenuItem(title: "Close Background Apps", action: #selector(closeBackgroundApps), keyEquivalent: "")
        closeBackgroundItem.target = self
        quickActionsMenu.addItem(closeBackgroundItem)
        
        let quickActionsItem = NSMenuItem(title: "Quick Actions", action: nil, keyEquivalent: "")
        quickActionsItem.submenu = quickActionsMenu
        menu.addItem(quickActionsItem)

        menu.addItem(NSMenuItem.separator())

        // Open Full Window menu item
        let openWindowItem = NSMenuItem(
            title: "Open Control Center",
            action: #selector(openFullWindow),
            keyEquivalent: "o"
        )
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit Craig-O-Clean",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }
    
    // MARK: - NSMenuDelegate
    
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        Task { @MainActor in
            updateRunningAppsMenu()
        }
    }
    
    private func updateRunningAppsMenu() {
        guard let submenu = runningAppsMenuItem?.submenu else { return }
        submenu.removeAllItems()
        
        // Get running applications sorted by memory usage
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        
        if runningApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "No apps running", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            submenu.addItem(noAppsItem)
            return
        }
        
        // Add header
        let headerItem = NSMenuItem(title: "Select app to force quit:", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        submenu.addItem(headerItem)
        submenu.addItem(NSMenuItem.separator())
        
        // Add each running app
        for app in runningApps {
            guard let appName = app.localizedName else { continue }
            
            let menuItem = NSMenuItem(title: appName, action: #selector(forceQuitSelectedApp(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = app.processIdentifier
            
            // Add app icon
            if let icon = app.icon {
                let resizedIcon = NSImage(size: NSSize(width: 16, height: 16))
                resizedIcon.lockFocus()
                icon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
                resizedIcon.unlockFocus()
                menuItem.image = resizedIcon
            }
            
            // Add memory usage info if available
            if let process = processManager?.processes.first(where: { $0.pid == app.processIdentifier }) {
                menuItem.title = "\(appName) — \(process.formattedMemoryUsage)"
            }
            
            submenu.addItem(menuItem)
        }
        
        // Add separator and "Force Quit All Non-Essential" option
        submenu.addItem(NSMenuItem.separator())
        
        let forceQuitAllItem = NSMenuItem(
            title: "Force Quit All Background Apps",
            action: #selector(forceQuitAllBackground),
            keyEquivalent: ""
        )
        forceQuitAllItem.target = self
        submenu.addItem(forceQuitAllItem)
    }
    
    @objc func forceQuitSelectedApp(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? Int32 else { return }
        
        // Find the app
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            let appName = app.localizedName ?? "Unknown"
            
            // Show confirmation alert
            let alert = NSAlert()
            alert.messageText = "Force Quit \"\(appName)\"?"
            alert.informativeText = "Any unsaved changes will be lost."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Force Quit")
            alert.addButton(withTitle: "Cancel")
            
            NSApp.activate(ignoringOtherApps: true)
            
            if alert.runModal() == .alertFirstButtonReturn {
                Task { @MainActor in
                    // Try force terminate
                    if app.forceTerminate() {
                        showNotification(title: "App Terminated", body: "\"\(appName)\" has been force quit.")
                    } else {
                        // Try using ProcessManager's more aggressive methods
                        if let process = processManager?.processes.first(where: { $0.pid == pid }) {
                            let success = await processManager?.forceQuitProcess(process) ?? false
                            if success {
                                showNotification(title: "App Terminated", body: "\"\(appName)\" has been force quit.")
                            } else {
                                showNotification(title: "Force Quit Failed", body: "Unable to quit \"\(appName)\". It may require administrator privileges.")
                            }
                        }
                    }
                    processManager?.updateProcessList()
                }
            }
        }
    }
    
    @objc func forceQuitAllBackground() {
        let alert = NSAlert()
        alert.messageText = "Force Quit All Background Apps?"
        alert.informativeText = "This will close all apps running in the background. Any unsaved work will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Force Quit All")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            Task { @MainActor in
                let optimizer = MemoryOptimizerService()
                await optimizer.analyzeMemoryUsage()
                let result = await optimizer.quickCleanupBackground()
                
                showNotification(
                    title: "Background Apps Closed",
                    body: "Closed \(result.appsTerminated) apps, freed \(result.formattedMemoryFreed)"
                )
                processManager?.updateProcessList()
            }
        }
    }

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show context menu
            statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            // Left-click: toggle popover
            // Temporarily remove menu to allow popover to show
            let menu = statusItem?.menu
            statusItem?.menu = nil
            togglePopover()
            // Restore menu after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.statusItem?.menu = menu
            }
        }
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Craig-O-Clean",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "macOS Memory Manager for Craig Ross\n\n© 2025 CraigOClean.com powered by VibeCaaS.com\na division of NeuralQuantum.ai LLC\n\nMonitor • Optimize • Control")
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func performSmartCleanup() {
        Task { @MainActor in
            let optimizer = MemoryOptimizerService()
            await optimizer.analyzeMemoryUsage()
            let result = await optimizer.smartCleanup()
            
            showNotification(
                title: "Smart Cleanup Complete",
                body: "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) apps"
            )
        }
    }
    
    @objc func closeBackgroundApps() {
        Task { @MainActor in
            let optimizer = MemoryOptimizerService()
            await optimizer.analyzeMemoryUsage()
            let result = await optimizer.quickCleanupBackground()
            
            showNotification(
                title: "Background Apps Closed",
                body: "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) background apps"
            )
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Failed to request notification permissions: \(error.localizedDescription)")
            } else if granted {
                print("Notification permissions granted")
            }
        }
    }

    private func showNotification(title: String, body: String) {
        // Use UserNotifications framework (requires macOS 11+, project targets macOS 14+)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error.localizedDescription)")
            }
        }
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    // Make sure popover window is on top
                    popover.contentViewController?.view.window?.makeKey()
                }
            }
        }
    }

    @objc func openFullWindow() {
        // Close popover
        popover?.performClose(nil)

        // If window already exists, bring to front
        if let window = fullWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window with MainAppView
        let contentView = MainAppView()
            .environmentObject(AuthManager.shared)
            .environmentObject(LocalUserStore.shared)
            .environmentObject(SubscriptionManager.shared)
            .environmentObject(StripeCheckoutService.shared)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Craig-O-Clean"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.minSize = NSSize(width: 900, height: 600)
        window.makeKeyAndOrderFront(nil)
        
        // Set window to use toolbar style
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified

        // Show app in dock when window is open
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Handle window close
        let delegate = WindowDelegate { [weak self] in
            self?.fullWindow = nil
            self?.windowDelegate = nil
            // Hide from dock when window closes
            NSApp.setActivationPolicy(.accessory)
        }
        windowDelegate = delegate
        window.delegate = delegate

        fullWindow = window
    }
}

// MARK: - Window Delegate

class WindowDelegate: NSObject, NSWindowDelegate {
    var onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

