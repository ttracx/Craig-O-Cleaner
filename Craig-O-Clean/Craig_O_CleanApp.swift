// MARK: - Craig_O_CleanApp.swift
// Craig-O-Clean - Main Application Entry Point
// A macOS system utility for Apple Silicon Macs

import SwiftUI
import AppKit
import UserNotifications

@main
struct Craig_O_CleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Shared services for Settings scene
    @StateObject private var systemMetrics = SystemMetricsService()
    @StateObject private var permissions = PermissionsService()
    @StateObject private var trialManager = TrialManager.shared

    var body: some Scene {
        // Settings scene (shows when user selects File > Settings)
        Settings {
            SettingsPermissionsView()
                .environmentObject(systemMetrics)
                .environmentObject(permissions)
                .environmentObject(AuthManager.shared)
                .environmentObject(LocalUserStore.shared)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(StripeCheckoutService.shared)
                .environmentObject(trialManager)
                .frame(minWidth: 700, minHeight: 600)
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
    // TODO: Re-enable after fixing module visibility
    // private var privilegeService: PrivilegeService?

    // Menu items that need dynamic updates
    private var runningAppsMenuItem: NSMenuItem?
    private var contextMenu: NSMenu?

    // Easter egg tracking
    private var hasShownEasterEggToday = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize logging
        // TODO: Re-enable when AppLogger module is fixed
        // AppLogger.shared.info("Application launching", category: "App", metadata: [
        //     "version": "1.0",
        //     "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        // ])

        // Initialize system metrics for menu bar updates
        systemMetrics = SystemMetricsService()
        processManager = ProcessManager()
        // TODO: Re-enable when PrivilegeService module is fixed
        // privilegeService = PrivilegeService()

        // TODO: Re-enable when AppLogger module is fixed
        // AppLogger.shared.info("Services initialized", category: "App")

        // Check helper status on launch
        // TODO: Re-enable when PrivilegeService module is fixed
        // Task { @MainActor in
        //     await privilegeService?.checkHelperStatus()
        // }

        // Request notification permissions
        requestNotificationPermissions()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use the custom menu bar icon from assets
            if let menuBarIcon = NSImage(named: "MenuBarIcon") {
                button.image = menuBarIcon
                button.image?.isTemplate = true // Use template mode for automatic dark/light mode adaptation
            } else {
                // Fallback to system symbol if MenuBarIcon asset is not found
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
            .environmentObject(TrialManager.shared)
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
        var useColoredIcon = false
        var healthColor: NSColor = .systemGreen

        if let memoryMetrics = systemMetrics?.memoryMetrics {
            switch memoryMetrics.pressureLevel {
            case .normal:
                useColoredIcon = false
                healthColor = .systemGreen
            case .warning:
                useColoredIcon = true
                healthColor = .systemOrange
            case .critical:
                useColoredIcon = true
                healthColor = .systemRed
            }
        }

        // Also check CPU usage if available
        if let cpuMetrics = systemMetrics?.cpuMetrics {
            if cpuMetrics.totalUsage > 90 {
                useColoredIcon = true
                healthColor = .systemRed
            } else if cpuMetrics.totalUsage > 75 && !useColoredIcon {
                useColoredIcon = true
                healthColor = .systemOrange
            }
        }

        // Update the icon based on system health
        if let menuBarIcon = NSImage(named: "MenuBarIcon") {
            if useColoredIcon {
                // Create a colored version for warning/critical states
                let coloredImage = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                    healthColor.set()
                    menuBarIcon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    return true
                }
                button.image = coloredImage
                button.image?.isTemplate = false
            } else {
                // Use template mode for normal state (follows system appearance)
                button.image = menuBarIcon
                button.image?.isTemplate = true
            }
        }

        // Update tooltip with current status
        if let memory = systemMetrics?.memoryMetrics {
            let usedGB = Double(memory.usedRAM) / 1024 / 1024 / 1024
            let totalGB = Double(memory.totalRAM) / 1024 / 1024 / 1024
            button.toolTip = String(format: "Craig-O-Clean\nMemory: %.0f%% used (%.1f GB / %.1f GB)",
                                    memory.usedPercentage,
                                    usedGB,
                                    totalGB)
        } else {
            button.toolTip = "Craig-O-Clean"
        }
    }

    func createContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = true

        // Memory Status header (updated dynamically)
        let memoryStatusItem = NSMenuItem(title: "Memory: Loading...", action: nil, keyEquivalent: "")
        memoryStatusItem.isEnabled = false
        memoryStatusItem.tag = 100 // Tag for updating
        menu.addItem(memoryStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Quick Cleanup Actions (direct, not in submenu)
        let smartCleanupItem = NSMenuItem(title: "✨ Smart Cleanup", action: #selector(performSmartCleanup), keyEquivalent: "s")
        smartCleanupItem.target = self
        menu.addItem(smartCleanupItem)

        let closeBackgroundItem = NSMenuItem(title: "🌙 Close Background Apps", action: #selector(closeBackgroundApps), keyEquivalent: "b")
        closeBackgroundItem.target = self
        menu.addItem(closeBackgroundItem)

        let cleanHeavyItem = NSMenuItem(title: "🔥 Close Heavy Apps", action: #selector(closeHeavyApps), keyEquivalent: "h")
        cleanHeavyItem.target = self
        menu.addItem(cleanHeavyItem)

        menu.addItem(NSMenuItem.separator())

        // Memory Clean (sync + purge)
        let memoryCleanItem = NSMenuItem(title: "⚡ Memory Clean", action: #selector(performMemoryClean), keyEquivalent: "m")
        memoryCleanItem.target = self
        menu.addItem(memoryCleanItem)

        menu.addItem(NSMenuItem.separator())

        // Running Apps submenu (for force quit)
        let runningAppsMenu = NSMenu()
        runningAppsMenu.delegate = self // Set delegate so menuWillOpen gets called for submenu
        let runningAppsItem = NSMenuItem(title: "Force Quit App", action: nil, keyEquivalent: "")
        runningAppsItem.submenu = runningAppsMenu
        runningAppsMenuItem = runningAppsItem
        menu.addItem(runningAppsItem)

        menu.addItem(NSMenuItem.separator())

        // Open Control Center
        let openWindowItem = NSMenuItem(
            title: "Open Control Center",
            action: #selector(openFullWindow),
            keyEquivalent: "o"
        )
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        // About menu item
        let aboutItem = NSMenuItem(
            title: "About Craig-O-Clean",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit Craig-O-Clean",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // DON'T attach menu to statusItem - we'll show it manually in statusBarButtonClicked
        // statusItem?.menu = menu
        // Store menu as instance variable instead
        self.contextMenu = menu
    }
    
    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update menu items synchronously - this is called on the main thread
        // Only update if this is our context menu
        if menu == contextMenu {
            updateMemoryStatusItem(menu)
            updateRunningAppsMenu()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // This is called right before a menu opens
        // Update running apps if this is the submenu
        if menu == runningAppsMenuItem?.submenu {
            print("🔵 Force Quit submenu opening - updating apps list")
            updateRunningAppsMenu()
        }
    }

    private func updateMemoryStatusItem(_ menu: NSMenu) {
        guard let memoryItem = menu.item(withTag: 100) else { return }

        if let memory = systemMetrics?.memoryMetrics {
            let usedGB = Double(memory.usedRAM) / 1024 / 1024 / 1024
            let totalGB = Double(memory.totalRAM) / 1024 / 1024 / 1024
            let pressureEmoji: String
            switch memory.pressureLevel {
            case .normal: pressureEmoji = "🟢"
            case .warning: pressureEmoji = "🟡"
            case .critical: pressureEmoji = "🔴"
            }
            memoryItem.title = "\(pressureEmoji) Memory: \(String(format: "%.1f", usedGB))/\(String(format: "%.0f", totalGB)) GB (\(Int(memory.usedPercentage))%)"
        } else {
            memoryItem.title = "Memory: Checking..."
        }
    }

    private func updateRunningAppsMenu() {
        print("🟢 updateRunningAppsMenu called")

        guard let submenu = runningAppsMenuItem?.submenu else {
            print("🔴 ERROR: submenu is nil")
            return
        }

        print("🟢 Submenu exists, removing all items")
        submenu.removeAllItems()

        // Get our own bundle ID and PID to exclude from the list
        let ownBundleID = Bundle.main.bundleIdentifier
        let ownPID = Foundation.ProcessInfo.processInfo.processIdentifier

        print("🟢 Own bundle ID: \(ownBundleID ?? "nil"), PID: \(ownPID)")

        // Get running applications sorted by memory usage, excluding ourselves
        let runningApps = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular &&
                $0.localizedName != nil &&
                $0.bundleIdentifier != ownBundleID &&  // Exclude ourselves by bundle ID
                $0.processIdentifier != ownPID          // Exclude ourselves by PID
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        print("🟢 Found \(runningApps.count) running apps")

        if runningApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "No apps running", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            submenu.addItem(noAppsItem)
            print("🟡 No apps to show")
            return
        }

        // Add header
        let headerItem = NSMenuItem(title: "Select app to force quit:", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        submenu.addItem(headerItem)
        submenu.addItem(NSMenuItem.separator())

        print("🟢 Adding menu items for each app...")

        // Add each running app
        for app in runningApps {
            guard let appName = app.localizedName else { continue }

            let menuItem = NSMenuItem(title: appName, action: #selector(forceQuitSelectedApp(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = app.processIdentifier
            menuItem.isEnabled = true  // Explicitly enable the menu item

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

            print("📋 Added menu item for \(appName) with PID \(app.processIdentifier), action: \(menuItem.action?.description ?? "nil"), target: \(menuItem.target != nil ? "set" : "nil")")
            submenu.addItem(menuItem)
        }

        print("🟢 Finished adding \(runningApps.count) app menu items")

        // Add separator and "Force Quit All Non-Essential" option
        submenu.addItem(NSMenuItem.separator())

        let forceQuitAllItem = NSMenuItem(
            title: "Force Quit All Background Apps",
            action: #selector(forceQuitAllBackground),
            keyEquivalent: ""
        )
        forceQuitAllItem.target = self
        submenu.addItem(forceQuitAllItem)

        print("🟢 updateRunningAppsMenu complete")
    }
    
    @objc func forceQuitSelectedApp(_ sender: NSMenuItem) {
        print("🔴 forceQuitSelectedApp called")
        print("🔴 Sender: \(sender.title)")
        print("🔴 RepresentedObject: \(String(describing: sender.representedObject))")

        guard let pid = sender.representedObject as? Int32 else {
            print("🔴 ERROR: Could not get PID from representedObject")
            return
        }

        print("🔴 Got PID: \(pid)")

        // CRITICAL: Never allow force quitting ourselves
        let ownPID = Foundation.ProcessInfo.processInfo.processIdentifier
        guard pid != ownPID else {
            print("🔴 Prevented self-termination attempt")
            showNotification(title: "Cannot Force Quit", body: "Craig-O-Clean cannot force quit itself.")
            return
        }

        // Find the app
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            let appName = app.localizedName ?? "Unknown"
            print("🔴 Found app: \(appName)")

            // Additional safety: check bundle ID
            if app.bundleIdentifier == Bundle.main.bundleIdentifier {
                print("🔴 Prevented self-termination via bundle ID check")
                showNotification(title: "Cannot Force Quit", body: "Craig-O-Clean cannot force quit itself.")
                return
            }

            // Show confirmation alert
            print("🔴 Showing confirmation alert for \(appName)")
            let alert = NSAlert()
            alert.messageText = "Force Quit \"\(appName)\"?"
            alert.informativeText = "Any unsaved changes will be lost."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Force Quit")
            alert.addButton(withTitle: "Cancel")

            NSApp.activate(ignoringOtherApps: true)

            if alert.runModal() == .alertFirstButtonReturn {
                print("🔴 User confirmed force quit")
                Task { @MainActor in
                    // Try force terminate
                    if app.forceTerminate() {
                        print("🔴 Successfully force terminated \(appName)")
                        showNotification(title: "App Terminated", body: "\"\(appName)\" has been force quit.")
                    } else {
                        print("🔴 forceTerminate() failed, trying ProcessManager")
                        // Try using ProcessManager's more aggressive methods
                        if let process = processManager?.processes.first(where: { $0.pid == pid }) {
                            // First try standard force quit
                            let success = await processManager?.forceQuitProcess(process) ?? false
                            if success {
                                print("🔴 ProcessManager successfully force quit \(appName)")
                                showNotification(title: "App Terminated", body: "\"\(appName)\" has been force quit.")
                            } else {
                                print("🔴 ProcessManager standard method failed, trying with admin privileges")
                                // Standard method failed, automatically try with admin privileges
                                let adminSuccess = await processManager?.forceQuitWithAdminPrivileges(process) ?? false
                                if adminSuccess {
                                    print("🔴 ProcessManager successfully force quit \(appName) with admin privileges")
                                    showNotification(title: "App Terminated", body: "\"\(appName)\" has been force quit using administrator privileges.")
                                } else {
                                    print("🔴 ProcessManager failed even with admin privileges")
                                    showNotification(title: "Force Quit Failed", body: "Unable to quit \"\(appName)\" even with administrator privileges. The process may be protected by the system.")
                                }
                            }
                        } else {
                            print("🔴 Could not find process in ProcessManager")
                            showNotification(title: "Force Quit Failed", body: "Unable to find process for \"\(appName)\".")
                        }
                    }
                    processManager?.updateProcessList()
                }
            } else {
                print("🔴 User cancelled force quit")
            }
        } else {
            print("🔴 ERROR: Could not find app with PID \(pid)")
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
            contextMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            // Left-click: toggle popover
            togglePopover()
        }
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Craig-O-Clean",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "© 2026 CraigOClean.com powered by VibeCaaS.com\na division of NeuralQuantum.ai LLC\n\nMonitor • Optimize • Control")
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        // Export logs before quitting
        Task {
            // TODO: Re-enable AppLogger
            /*
            do {
                let logURL = try await AppLogger.shared.exportLogs(format: .json)
                // AppLogger.shared.info("Logs exported before quit: \(logURL.path)", category: "App")
            } catch {
                // AppLogger.shared.warning("Failed to export logs before quit: \(error.localizedDescription)", category: "App")
            }
            */
            NSApp.terminate(nil)
        }
    }
    
    @objc func performSmartCleanup() {
        Task { @MainActor in
            // TODO: Re-enable AppLogger
            // AppLogger.shared.info("Smart cleanup initiated", category: "App")
            // let tracker = AppLogger.shared.startPerformanceTracking(operation: "SmartCleanup")

            let optimizer = MemoryOptimizerService()

            // Add our bundle ID to excluded list as extra safety
            if let ownBundleID = Bundle.main.bundleIdentifier {
                optimizer.excludedBundleIdentifiers.insert(ownBundleID)
            }
            // Also add common variations
            optimizer.excludedBundleIdentifiers.insert("com.craigoclean.app")
            optimizer.excludedBundleIdentifiers.insert("com.CraigOClean.app")
            optimizer.excludedBundleIdentifiers.insert("com.Craig-O-Clean.app")

            await optimizer.analyzeMemoryUsage()
            let result = await optimizer.smartCleanup()

            // TODO: Re-enable AppLogger
            // tracker.end()

            // TODO: Re-enable AppLogger
            // AppLogger.shared.info(
            //     "Smart cleanup completed",
            //     category: "App",
            //     metadata: [
            //         "appsTerminated": "\(result.appsTerminated)",
            //         "memoryFreed": result.formattedMemoryFreed
            //     ]
            // )

            showNotification(
                title: "Smart Cleanup Complete",
                body: "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) apps"
            )
        }
    }
    
    @objc func closeBackgroundApps() {
        Task { @MainActor in
            let optimizer = MemoryOptimizerService()

            // Add our bundle ID to excluded list as extra safety
            if let ownBundleID = Bundle.main.bundleIdentifier {
                optimizer.excludedBundleIdentifiers.insert(ownBundleID)
            }
            optimizer.excludedBundleIdentifiers.insert("com.craigoclean.app")

            await optimizer.analyzeMemoryUsage()
            let result = await optimizer.quickCleanupBackground()

            showNotification(
                title: "Background Apps Closed",
                body: "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) background apps"
            )
        }
    }

    @objc func closeHeavyApps() {
        Task { @MainActor in
            let optimizer = MemoryOptimizerService()

            // Add our bundle ID to excluded list as extra safety
            if let ownBundleID = Bundle.main.bundleIdentifier {
                optimizer.excludedBundleIdentifiers.insert(ownBundleID)
            }
            optimizer.excludedBundleIdentifiers.insert("com.craigoclean.app")

            await optimizer.analyzeMemoryUsage()
            let result = await optimizer.quickCleanupHeavy(limit: 3)

            showNotification(
                title: "Heavy Apps Closed",
                body: "Freed \(result.formattedMemoryFreed) by closing \(result.appsTerminated) memory-heavy apps"
            )
        }
    }

    @objc func performMemoryClean() {
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Memory Clean"
        alert.informativeText = "This will run system commands to flush file system buffers and purge inactive memory.\n\nResults may vary depending on your system state. You may be prompted for your administrator password."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            Task { @MainActor in
                // TODO: Re-enable AppLogger
                // AppLogger.shared.info("Memory clean initiated from menu", category: "App")

                // Show progress notification
                showNotification(
                    title: "Memory Clean Starting",
                    body: "Flushing buffers and purging inactive memory..."
                )

                // TODO: Re-enable when PrivilegeService is fixed
                /*
                // Check helper status
                await privilegeService?.checkHelperStatus()

                // Execute memory cleanup
                if let result = await privilegeService?.executeMemoryCleanup() {
                */
                // Placeholder - feature disabled until PrivilegeService is restored
                // if false {
                    // TODO: Re-enable AppLogger
                    // AppLogger.shared.info(
                    //     "Memory clean completed",
                    //     category: "App",
                    //     metadata: [
                    //         "success": "\(result.success)",
                    //         "message": result.message
                    //     ]
                    // )

                    // if result.success {
                    //     showNotification(
                    //         title: "Memory Clean Complete",
                    //         body: result.message
                    //     )
                    // } else {
                    //     showNotification(
                    //         title: "Memory Clean Issue",
                    //         body: result.message
                    //     )
                    // }

                    // Refresh metrics
                    // await systemMetrics?.refreshAllMetrics()
                // } else {
                showNotification(
                    title: "Memory Clean Unavailable",
                    body: "This feature requires PrivilegeService to be enabled."
                )
                // }
            }
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

        // Show app in dock BEFORE creating/showing window
        NSApp.setActivationPolicy(.regular)

        // If window already exists, bring to front
        if let window = fullWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create new window with MainAppView
        let contentView = MainAppView()
            .environmentObject(AuthManager.shared)
            .environmentObject(LocalUserStore.shared)
            .environmentObject(SubscriptionManager.shared)
            .environmentObject(StripeCheckoutService.shared)
            .environmentObject(TrialManager.shared)
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

        // Set window to use toolbar style
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified

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

        // Activate and show window AFTER setup
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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

