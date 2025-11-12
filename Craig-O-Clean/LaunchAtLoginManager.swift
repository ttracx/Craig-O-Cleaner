import Foundation
import ServiceManagement

class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false
    
    init() {
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
    
    func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                print("Failed to toggle launch at login: \(error.localizedDescription)")
                // Revert the state if toggle failed
                isEnabled = !isEnabled
            }
        }
    }
}

