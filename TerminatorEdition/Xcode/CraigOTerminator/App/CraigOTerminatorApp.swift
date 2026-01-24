import SwiftUI

@main
struct CraigOTerminatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, idealWidth: 1200, minHeight: 700, idealHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Craig-O Terminator") {
                    appState.showAbout = true
                }
            }
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Quick Cleanup") {
                    Task { await appState.performQuickCleanup() }
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])

                Button("Full Cleanup") {
                    Task { await appState.performFullCleanup() }
                }
                .keyboardShortcut("C", modifiers: [.command, .shift])

                Button("Emergency Mode") {
                    Task { await appState.performEmergencyCleanup() }
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "bolt.circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the Terminator Engine
        Task { @MainActor in
            await AppState.shared.initialize()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup on exit
        Task { @MainActor in
            AppState.shared.shutdown()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
}
