import SwiftUI

@main
struct Craig_O_CleanApp: App {
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Craig-O-Clean")
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create context menu
        createContextMenu()

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 480)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView(onExpandClick: { [weak self] in
                self?.openFullWindow()
            })
        )

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
    }

    func createContextMenu() {
        let menu = NSMenu()

        // About menu item
        menu.addItem(NSMenuItem(
            title: "About Craig-O-Clean",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        // Open Full Window menu item
        menu.addItem(NSMenuItem(
            title: "Open Full Window",
            action: #selector(openFullWindow),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        menu.addItem(NSMenuItem(
            title: "Quit Craig-O-Clean",
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
            .applicationName: "Craig-O-Clean",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "A powerful macOS process monitor\nBuilt with SwiftUI")
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
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

        // Create new window
        let contentView = ContentView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Craig-O-Clean - Process Monitor"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)

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

