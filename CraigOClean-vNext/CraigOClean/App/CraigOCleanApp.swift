// File: CraigOClean-vNext/CraigOClean/App/CraigOCleanApp.swift
// Craig-O-Clean - Main App Entry Point
// SwiftUI App lifecycle management

import SwiftUI

@main
struct CraigOCleanApp: App {

    // MARK: - Properties

    @StateObject private var container = DIContainer.shared
    @StateObject private var environment = AppEnvironment.shared

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(environment)
                .environmentObject(container.logStore)
                .withAppEnvironment(environment)
                .withDIContainer(container)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    configureAppearance()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Craig-O-Clean") {
                    showAboutWindow()
                }
            }

            CommandGroup(after: .appInfo) {
                Divider()
                Button("Check for Updates...") {
                    checkForUpdates()
                }
                .disabled(!environment.capabilities.canAutoUpdate)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(container)
                .environmentObject(environment)
        }
        #endif
    }

    // MARK: - Private Methods

    private func configureAppearance() {
        container.logger.info("Application launched", category: .app)

        // Log edition info
        container.logger.info("Running as \(environment.edition.displayName)", category: .app)
    }

    private func showAboutWindow() {
        let version = environment.fullVersionString
        let edition = environment.edition.displayName

        let alert = NSAlert()
        alert.messageText = "Craig-O-Clean"
        alert.informativeText = """
        Version \(version)
        \(edition)

        A safe and effective disk cleanup utility for macOS.

        Copyright 2024 CraigoSoft. All rights reserved.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func checkForUpdates() {
        Task {
            do {
                _ = try await container.updateService.checkForUpdates()
            } catch {
                container.logger.error("Update check failed: \(error.localizedDescription)", category: .updates)
            }
        }
    }
}

// MARK: - App Delegate (if needed)

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Additional setup if needed
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
#endif
