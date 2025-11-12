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
            // For older macOS versions, we'll use a simpler approach
            isEnabled = isLaunchAtLoginEnabledLegacy()
        }
    }
    
    func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.unregister()
                    isEnabled = false
                } else {
                    try SMAppService.mainApp.register()
                    isEnabled = true
                }
            } catch {
                print("Failed to toggle launch at login: \(error.localizedDescription)")
            }
        } else {
            toggleLaunchAtLoginLegacy()
        }
    }
    
    // Legacy method for macOS < 13.0
    private func isLaunchAtLoginEnabledLegacy() -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue()
        
        guard let loginItemsRef = loginItems else { return false }
        
        let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
        
        for item in loginItemsArray {
            let itemRef = item as! LSSharedFileListItem
            if let itemURL = LSSharedFileListItemCopyResolvedURL(itemRef, 0, nil)?.takeRetainedValue() as URL? {
                if itemURL.path.contains(bundleIdentifier) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func toggleLaunchAtLoginLegacy() {
        let bundleURL = Bundle.main.bundleURL
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue()
        
        guard let loginItemsRef = loginItems else { return }
        
        if isEnabled {
            // Remove from login items
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
            
            for item in loginItemsArray {
                let itemRef = item as! LSSharedFileListItem
                if let itemURL = LSSharedFileListItemCopyResolvedURL(itemRef, 0, nil)?.takeRetainedValue() as URL? {
                    if itemURL.path == bundleURL.path {
                        LSSharedFileListItemRemove(loginItemsRef, itemRef)
                    }
                }
            }
            isEnabled = false
        } else {
            // Add to login items
            LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemBeforeFirst.takeRetainedValue(), nil, nil, bundleURL as CFURL, nil, nil)
            isEnabled = true
        }
    }
}

