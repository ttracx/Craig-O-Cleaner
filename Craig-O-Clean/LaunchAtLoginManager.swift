import Foundation
import ServiceManagement

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool = false

    private init() {
        checkLaunchAtLoginStatus()
    }

    func checkLaunchAtLoginStatus() {
        // Check if the app is set to launch at login
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions, launch at login is not supported
            isEnabled = false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    // Register the app to launch at login
                    try SMAppService.mainApp.register()
                } else {
                    // Unregister from launch at login
                    try SMAppService.mainApp.unregister()
                }
                isEnabled = enabled
            } catch {
                print("Failed to set launch at login: \(error.localizedDescription)")
            }
        }
    }

    func toggleLaunchAtLogin() {
        setLaunchAtLogin(!isEnabled)
    }
}

