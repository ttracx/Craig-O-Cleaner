import Foundation

/// Helper for accessing app version information
extension Bundle {
    /// App version (e.g., "9")
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number (e.g., "2")
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Full version string (e.g., "9 (2)")
    var fullVersionString: String {
        return "\(appVersion) (\(buildNumber))"
    }

    /// Display version string for UI (e.g., "Version 9 (2)")
    var displayVersion: String {
        return "Version \(fullVersionString)"
    }
}
