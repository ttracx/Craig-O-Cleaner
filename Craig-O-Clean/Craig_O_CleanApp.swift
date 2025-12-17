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

// MARK: - Easter Egg Messages 🥚

struct EasterEggMessage {
    let title: String
    let body: String
    let sound: Bool
    
    init(_ title: String, _ body: String, sound: Bool = true) {
        self.title = title
        self.body = body
        self.sound = sound
    }
}

enum EasterEggManager {
    // Regular funny messages (shown randomly)
    static let funnyMessages: [EasterEggMessage] = [
        EasterEggMessage("🧹 Craig's Cleaning Tip #42", "Have you tried turning your RAM off and on again? ...Wait, that's not how this works."),
        EasterEggMessage("📊 Fun Fact", "Your computer has more RAM than the entire Apollo 11 mission. And yet Chrome still wants more. 🚀"),
        EasterEggMessage("🎭 Plot Twist", "I'm also using some of your RAM right now. We're in this together! 😅"),
        EasterEggMessage("🐰 Found Them!", "I found some dust bunnies hiding in your memory. Don't worry, I'll be gentle."),
        EasterEggMessage("📞 Incoming Call", "Your RAM called. It says it needs some 'me time.' I got you covered."),
        EasterEggMessage("🧠 Memory Lane", "Remember when 640KB was enough for anyone? Pepperidge Farm remembers."),
        EasterEggMessage("🎮 Achievement Unlocked", "You opened Craig-O-Clean! +10 Cleanliness, +5 Organization, -1 Procrastination"),
        EasterEggMessage("🔮 Fortune Cookie", "Your RAM forecast: Cloudy with a chance of cleanup. Lucky numbers: 8, 16, 32, 64"),
        EasterEggMessage("🎪 Welcome Back!", "Your memory missed you! Just kidding, it doesn't remember anything. That's... that's the problem."),
        EasterEggMessage("🦸 Hero Mode", "With great RAM comes great responsibility. — Uncle Memory"),
        EasterEggMessage("🍪 Cookie Notice", "This app uses cookies. Just kidding! But your browser has like 47,000 of them."),
        EasterEggMessage("🎬 Previously on Craig-O-Clean", "Your apps were hogging memory. Drama ensued. Let's fix this."),
        EasterEggMessage("🌟 Daily Affirmation", "You are valid. Your processes are valid. Let's just... validate some of them out of memory."),
        EasterEggMessage("🎸 Rock On!", "Your computer is about to get SO clean, it'll need sunglasses. 😎"),
        EasterEggMessage("📝 Reminder", "Roses are red, violets are blue, Chrome has 50 tabs, and they're all using CPU."),
        EasterEggMessage("🎯 Mission Briefing", "Your mission, should you choose to accept it: Close some apps. This message will self-destruct in 5... 4... just kidding."),
        EasterEggMessage("🐱 Cat Fact", "If your Mac were a cat, it would knock unnecessary processes off the table. Be like cat."),
        EasterEggMessage("🎭 Shakespeare Says", "To quit, or not to quit? That is the question. (The answer is quit. Quit the heavy apps.)"),
        EasterEggMessage("🌈 Motivational", "Every byte you free is a byte closer to peak performance! ...That sounded better in my head."),
        EasterEggMessage("🎪 Fun Mode: ON", "Warning: Excessive cleanliness may cause feelings of satisfaction and smugness."),
    ]
    
    // Special time-based messages
    static let morningMessages: [EasterEggMessage] = [
        EasterEggMessage("☀️ Good Morning!", "Rise and shine! Your RAM woke up before you did. Overachiever."),
        EasterEggMessage("🌅 Early Bird", "You're up early! Your computer appreciates your dedication to cleanliness."),
        EasterEggMessage("☕ Morning Brew", "Coffee loading... Memory optimizing... You're going to have a great day!"),
    ]
    
    static let lateNightMessages: [EasterEggMessage] = [
        EasterEggMessage("🌙 Night Owl Alert", "Still coding at this hour? Your RAM is tired too, but we got this!"),
        EasterEggMessage("🦉 Midnight Clean", "Shh... your computer's memory is trying to sleep. Let's tuck it in."),
        EasterEggMessage("😴 Sleepy Time", "Your Mac called. It said 'just five more minutes'... of optimization."),
        EasterEggMessage("🌟 Starlight Special", "Late night + clean RAM = productivity magic. ✨"),
    ]
    
    static let weekendMessages: [EasterEggMessage] = [
        EasterEggMessage("🎉 Weekend Vibes!", "Even your RAM deserves a break. Let's make it a clean break."),
        EasterEggMessage("🛋️ Lazy Sunday", "Relax! Let me do the memory cleaning while you enjoy your weekend."),
        EasterEggMessage("🎊 Party Mode", "It's the weekend! Time to party... by cleaning your memory. We're fun."),
    ]
    
    // Super rare legendary messages (1% chance within the easter egg)
    static let legendaryMessages: [EasterEggMessage] = [
        EasterEggMessage("🦄 LEGENDARY DROP!", "You found the ultra-rare unicorn message! Quick, make a wish! 🌟 (Your RAM will be extra clean today)"),
        EasterEggMessage("🎰 JACKPOT!", "You hit the easter egg jackpot! This happens to 1 in 100 users. You're basically famous now."),
        EasterEggMessage("👾 Secret Level", "KONAMI CODE DETECTED! ↑↑↓↓←→←→BA... Just kidding. But you're still special."),
        EasterEggMessage("🏆 Golden Ticket", "You found Craig's Golden Ticket! Your prize: Immaculately clean memory and bragging rights."),
    ]
    
    // Craig-specific humor
    static let craigMessages: [EasterEggMessage] = [
        EasterEggMessage("👨‍💼 Craig Approved™", "This memory optimization has been personally blessed by Craig himself."),
        EasterEggMessage("📜 Craig's Wisdom", "Craig once said: 'A clean Mac is a happy Mac.' He's so wise."),
        EasterEggMessage("🎖️ Official Notice", "By the power vested in me by Craig, I now pronounce your memory... CLEAN!"),
    ]
    
    static func getRandomMessage() -> EasterEggMessage {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7

        // Default fallback message in case arrays are empty
        let fallbackMessage = EasterEggMessage("🧹 Craig-O-Clean", "Your memory is being optimized!")

        // 1% chance for legendary message
        if Int.random(in: 1...100) == 42 {
            return legendaryMessages.randomElement() ?? fallbackMessage
        }

        // 15% chance for Craig-specific message
        if Int.random(in: 1...100) <= 15 {
            return craigMessages.randomElement() ?? fallbackMessage
        }

        // Time-based messages (30% chance when applicable)
        if Int.random(in: 1...100) <= 30 {
            // Early morning (5 AM - 8 AM)
            if hour >= 5 && hour < 8 {
                return morningMessages.randomElement() ?? fallbackMessage
            }

            // Late night (11 PM - 4 AM)
            if hour >= 23 || hour < 4 {
                return lateNightMessages.randomElement() ?? fallbackMessage
            }

            // Weekend
            if isWeekend {
                return weekendMessages.randomElement() ?? fallbackMessage
            }
        }

        // Default: random funny message
        return funnyMessages.randomElement() ?? fallbackMessage
    }
    
    static var shouldShowEasterEgg: Bool {
        // 25% chance to show easter egg on app launch
        return Int.random(in: 1...100) <= 25
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
    
    // Easter egg tracking
    private var hasShownEasterEggToday = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize logging
        AppLogger.shared.info("Application launching", category: "App", metadata: [
            "version": "1.0",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])
        
        // Initialize system metrics for menu bar updates
        systemMetrics = SystemMetricsService()
        processManager = ProcessManager()
        
        AppLogger.shared.info("Services initialized", category: "App")

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
        
        // 🥚 Easter Egg: Show a fun message on launch (with a slight delay for delight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.triggerEasterEgg()
        }
    }
    
    // MARK: - Easter Egg 🥚
    
    private func triggerEasterEgg() {
        // Check if we should show the easter egg (25% chance)
        guard EasterEggManager.shouldShowEasterEgg else { return }
        
        // Don't spam - check if we showed one recently (use UserDefaults)
        let lastShownKey = "lastEasterEggDate"
        let lastShown = UserDefaults.standard.object(forKey: lastShownKey) as? Date
        
        // Only show once per app session or if it's been more than 4 hours
        if let lastShown = lastShown {
            let hoursSinceLastShown = Date().timeIntervalSince(lastShown) / 3600
            if hoursSinceLastShown < 4 && hasShownEasterEggToday {
                return
            }
        }
        
        // Get a fun message
        let message = EasterEggManager.getRandomMessage()
        
        // Show the easter egg notification
        showEasterEggNotification(message)
        
        // Mark as shown
        hasShownEasterEggToday = true
        UserDefaults.standard.set(Date(), forKey: lastShownKey)
    }
    
    private func showEasterEggNotification(_ message: EasterEggMessage) {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = message.sound ? .default : nil
        
        // Add a category for interactive notifications
        content.categoryIdentifier = "EASTER_EGG"
        
        let request = UNNotificationRequest(
            identifier: "easter-egg-\(UUID().uuidString)",
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🥚 Easter egg failed to hatch: \(error.localizedDescription)")
            } else {
                print("🥚 Easter egg delivered: \(message.title)")
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
        // Export logs before quitting
        Task {
            do {
                let logURL = try await AppLogger.shared.exportLogs(format: .json)
                AppLogger.shared.info("Logs exported before quit: \(logURL.path)", category: "App")
            } catch {
                AppLogger.shared.warning("Failed to export logs before quit: \(error.localizedDescription)", category: "App")
            }
            NSApp.terminate(nil)
        }
    }
    
    @objc func performSmartCleanup() {
        Task { @MainActor in
            AppLogger.shared.info("Smart cleanup initiated", category: "App")
            let tracker = AppLogger.shared.startPerformanceTracking(operation: "SmartCleanup")

            let optimizer = MemoryOptimizerService()
            await optimizer.analyzeMemoryUsage()
            let result = await optimizer.smartCleanup()

            tracker.end()

            AppLogger.shared.info(
                "Smart cleanup completed",
                category: "App",
                metadata: [
                    "appsTerminated": "\(result.appsTerminated)",
                    "memoryFreed": result.formattedMemoryFreed
                ]
            )

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

