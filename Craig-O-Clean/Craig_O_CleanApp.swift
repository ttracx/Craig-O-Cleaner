// Craig_O_CleanApp.swift
// ClearMind Control Center
//
// Main application entry point
// Manages menu bar presence and main window lifecycle

import SwiftUI

@main
struct ClearMindControlCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene (required but hidden)
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var fullWindow: NSWindow?
    var windowDelegate: WindowDelegate?
    private var metricsService = SystemMetricsService()
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusBarIcon()
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create context menu
        createContextMenu()

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 380, height: 520)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: EnhancedMenuBarView(
                onExpandClick: { [weak self] in
                    self?.openFullWindow()
                },
                onQuickCleanup: { [weak self] in
                    self?.performQuickCleanup()
                }
            )
        )

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
        
        // Start status bar updates
        startStatusBarUpdates()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
    }
    
    private func startStatusBarUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusBarIcon()
            }
        }
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        // Use brain icon for the app
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "ClearMind Control Center")?
            .withSymbolConfiguration(config)
        
        // Add memory indicator
        if let memory = metricsService.memoryMetrics {
            let percentage = Int(memory.usedPercentage)
            button.title = " \(percentage)%"
        }
    }

    func createContextMenu() {
        let menu = NSMenu()

        // About menu item
        menu.addItem(NSMenuItem(
            title: "About ClearMind Control Center",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())
        
        // Quick actions
        let dashboardItem = NSMenuItem(
            title: "Open Dashboard",
            action: #selector(openFullWindow),
            keyEquivalent: "d"
        )
        dashboardItem.keyEquivalentModifierMask = [.command]
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem(
            title: "Quick Memory Cleanup",
            action: #selector(quickCleanup),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        menu.addItem(NSMenuItem(
            title: "Quit ClearMind Control Center",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

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
            .applicationName: "ClearMind Control Center",
            .applicationVersion: "2.0",
            .credits: NSAttributedString(string: "A powerful macOS system utility\nMonitor • Optimize • Control\n\nBuilt with SwiftUI for Apple Silicon")
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func quickCleanup() {
        popover?.performClose(nil)
        performQuickCleanup()
    }
    
    private func performQuickCleanup() {
        Task { @MainActor in
            let optimizer = MemoryOptimizerService()
            _ = await optimizer.quickCleanup()
        }
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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

        // Create new window with the main app view
        let contentView = MainAppView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "ClearMind Control Center"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.makeKeyAndOrderFront(nil)
        window.minSize = NSSize(width: 900, height: 600)

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

