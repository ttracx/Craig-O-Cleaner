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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var fullWindow: NSWindow?
    var windowDelegate: WindowDelegate?
    
    // Services
    private var systemMetrics: SystemMetricsService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize system metrics for menu bar updates
        systemMetrics = SystemMetricsService()

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
        )

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
        
        // Start monitoring for status bar updates
        Task { @MainActor in
            systemMetrics?.startMonitoring()
        }
        
        // Schedule periodic status bar icon updates
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatusBarIcon()
        }
    }
    
    private func updateStatusBarIcon() {
        // Could update icon color/badge based on system health
        // For now, keep the brain icon
    }

    func createContextMenu() {
        let menu = NSMenu()

        // About menu item
        let aboutItem = NSMenuItem(
            title: "About Craig-O-Clean",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

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

