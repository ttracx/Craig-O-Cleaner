import Foundation

// MARK: - System Utilities
/// General system utilities for macOS Silicon
/// Handles maintenance, security, permissions, and system controls

@MainActor
public final class SystemUtilities: ObservableObject {

    // MARK: - Types

    public enum MaintenanceTask: String, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"

        public var description: String {
            switch self {
            case .daily: return "Daily maintenance (rotate logs, cleanup)"
            case .weekly: return "Weekly maintenance (rebuild databases)"
            case .monthly: return "Monthly maintenance (rebuild whatis)"
            }
        }
    }

    public struct PermissionStatus: Sendable {
        public let accessibility: Bool
        public let automation: Bool
        public let fullDiskAccess: Bool
        public let screenRecording: Bool
    }

    public struct FirewallStatus: Sendable {
        public let enabled: Bool
        public let stealthMode: Bool
        public let blockAllIncoming: Bool
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var isMaintenanceRunning = false

    // MARK: - System Maintenance

    /// Run periodic maintenance tasks
    public func runPeriodicMaintenance(_ tasks: [MaintenanceTask] = MaintenanceTask.allCases) async throws {
        isMaintenanceRunning = true
        defer { isMaintenanceRunning = false }

        let taskNames = tasks.map { $0.rawValue }.joined(separator: " ")
        _ = try await executor.executePrivileged("periodic \(taskNames)")
    }

    /// Rebuild Spotlight index
    public func rebuildSpotlightIndex(volume: String = "/") async throws {
        _ = try await executor.executePrivileged("mdutil -E \(volume)")
    }

    /// Disable Spotlight for volume
    public func disableSpotlight(volume: String) async throws {
        _ = try await executor.executePrivileged("mdutil -i off \(volume)")
    }

    /// Enable Spotlight for volume
    public func enableSpotlight(volume: String) async throws {
        _ = try await executor.executePrivileged("mdutil -i on \(volume)")
    }

    /// Get Spotlight status
    public func getSpotlightStatus(volume: String = "/") async -> String {
        let result = try? await executor.execute("mdutil -s \(volume)")
        return result?.output ?? "Unknown"
    }

    /// Update dyld shared cache
    public func updateDyldCache() async throws {
        _ = try await executor.executePrivileged("update_dyld_shared_cache")
    }

    /// Rebuild launch services database
    public func rebuildLaunchServices() async throws {
        _ = try await executor.execute("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user")
    }

    // MARK: - DNS Management

    /// Flush DNS cache
    public func flushDNSCache() async throws {
        _ = try await executor.executePrivileged("dscacheutil -flushcache")
        _ = try await executor.executePrivileged("killall -HUP mDNSResponder")
    }

    /// Get current DNS servers
    public func getDNSServers() async -> [String] {
        let result = try? await executor.execute("scutil --dns | grep 'nameserver\\[' | awk '{print $3}'")
        guard let output = result?.output else { return [] }
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// Set DNS servers for interface
    public func setDNSServers(_ servers: [String], interface: String = "Wi-Fi") async throws {
        let serverList = servers.joined(separator: " ")
        _ = try await executor.executePrivileged("networksetup -setdnsservers \"\(interface)\" \(serverList)")
    }

    // MARK: - Network Utilities

    /// Reset network configuration
    public func resetNetworkConfiguration() async throws {
        _ = try await executor.executePrivileged("networksetup -setv4off Wi-Fi")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        _ = try await executor.executePrivileged("networksetup -setdhcp Wi-Fi")
    }

    /// Toggle Wi-Fi
    public func toggleWiFi(enable: Bool) async throws {
        let state = enable ? "on" : "off"
        _ = try await executor.executePrivileged("networksetup -setairportpower en0 \(state)")
    }

    /// Get Wi-Fi network name
    public func getCurrentWiFiNetwork() async -> String? {
        let result = try? await executor.execute(
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep ' SSID' | awk '{print $2}'"
        )
        guard let output = result?.output, !output.isEmpty else { return nil }
        return output
    }

    // MARK: - Security & Permissions

    /// Get SIP (System Integrity Protection) status
    public func getSIPStatus() async -> Bool {
        let result = try? await executor.execute("csrutil status")
        return result?.output.contains("enabled") ?? false
    }

    /// Get Gatekeeper status
    public func getGatekeeperStatus() async -> Bool {
        let result = try? await executor.execute("spctl --status")
        return result?.output.contains("enabled") ?? false
    }

    /// Get FileVault status
    public func getFileVaultStatus() async -> Bool {
        let result = try? await executor.executePrivileged("fdesetup status")
        return result?.output.contains("FileVault is On") ?? false
    }

    /// Get firewall status
    public func getFirewallStatus() async -> FirewallStatus {
        let globalResult = try? await executor.executePrivileged(
            "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate"
        )
        let stealthResult = try? await executor.executePrivileged(
            "/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode"
        )
        let blockResult = try? await executor.executePrivileged(
            "/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall"
        )

        return FirewallStatus(
            enabled: globalResult?.output.contains("enabled") ?? false,
            stealthMode: stealthResult?.output.contains("enabled") ?? false,
            blockAllIncoming: blockResult?.output.contains("enabled") ?? false
        )
    }

    /// Enable/disable firewall
    public func setFirewallEnabled(_ enabled: Bool) async throws {
        let state = enabled ? "on" : "off"
        _ = try await executor.executePrivileged(
            "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate \(state)"
        )
    }

    // MARK: - Power Management

    /// Prevent display sleep
    public func preventDisplaySleep(duration: Int? = nil) async -> Process? {
        let args = duration.map { ["-d", "-t", "\($0)"] } ?? ["-d"]
        // This returns a running process that should be terminated to stop caffeinate
        let command = "caffeinate \(args.joined(separator: " "))"
        _ = try? await executor.execute(command)
        return nil
    }

    /// Prevent system sleep
    public func preventSystemSleep(duration: Int? = nil) async throws {
        let args = duration.map { "-t \($0)" } ?? ""
        _ = try await executor.execute("caffeinate -i \(args) &")
    }

    /// Get power management settings
    public func getPowerSettings() async -> String {
        let result = try? await executor.execute("pmset -g")
        return result?.output ?? ""
    }

    /// Set display sleep time (minutes, 0 = never)
    public func setDisplaySleepTime(_ minutes: Int) async throws {
        _ = try await executor.executePrivileged("pmset -a displaysleep \(minutes)")
    }

    /// Set computer sleep time (minutes, 0 = never)
    public func setComputerSleepTime(_ minutes: Int) async throws {
        _ = try await executor.executePrivileged("pmset -a sleep \(minutes)")
    }

    // MARK: - System Control

    /// Restart Finder
    public func restartFinder() async throws {
        _ = try await executor.execute("killall Finder")
    }

    /// Restart Dock
    public func restartDock() async throws {
        _ = try await executor.execute("killall Dock")
    }

    /// Restart menu bar
    public func restartMenuBar() async throws {
        _ = try await executor.execute("killall SystemUIServer")
        _ = try await executor.execute("killall ControlCenter")
    }

    /// Restart audio
    public func restartAudio() async throws {
        _ = try await executor.executePrivileged("killall coreaudiod")
    }

    /// Restart Notification Center
    public func restartNotificationCenter() async throws {
        _ = try await executor.execute("killall NotificationCenter")
    }

    /// Reset Quick Look
    public func resetQuickLook() async throws {
        _ = try await executor.execute("qlmanage -r")
        _ = try await executor.execute("qlmanage -r cache")
    }

    // MARK: - User Defaults

    /// Show hidden files in Finder
    public func setShowHiddenFiles(_ show: Bool) async throws {
        let value = show ? "true" : "false"
        _ = try await executor.execute("defaults write com.apple.finder AppleShowAllFiles -bool \(value)")
        try await restartFinder()
    }

    /// Set screenshot location
    public func setScreenshotLocation(_ path: String) async throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        _ = try await executor.execute("defaults write com.apple.screencapture location \"\(expandedPath)\"")
        _ = try await executor.execute("killall SystemUIServer")
    }

    /// Set screenshot format
    public func setScreenshotFormat(_ format: String) async throws {
        // png, jpg, gif, pdf, tiff
        _ = try await executor.execute("defaults write com.apple.screencapture type \(format)")
    }

    /// Disable screenshot shadow
    public func disableScreenshotShadow(_ disable: Bool) async throws {
        let value = disable ? "true" : "false"
        _ = try await executor.execute("defaults write com.apple.screencapture disable-shadow -bool \(value)")
    }

    // MARK: - NVRAM

    /// Clear NVRAM (requires reboot)
    public func clearNVRAM() async throws {
        _ = try await executor.executePrivileged("nvram -c")
    }

    /// Get NVRAM contents
    public func getNVRAMContents() async -> String {
        let result = try? await executor.execute("nvram -p")
        return result?.output ?? ""
    }

    // MARK: - System Actions

    /// Shutdown system
    public func shutdown(delay: Int = 0) async throws {
        if delay > 0 {
            _ = try await executor.executePrivileged("shutdown -h +\(delay)")
        } else {
            _ = try await executor.executePrivileged("shutdown -h now")
        }
    }

    /// Restart system
    public func restart(delay: Int = 0) async throws {
        if delay > 0 {
            _ = try await executor.executePrivileged("shutdown -r +\(delay)")
        } else {
            _ = try await executor.executePrivileged("shutdown -r now")
        }
    }

    /// Put system to sleep
    public func sleep() async throws {
        _ = try await executor.executePrivileged("pmset sleepnow")
    }

    /// Lock screen
    public func lockScreen() async throws {
        _ = try await executor.execute(
            "/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend"
        )
    }

    // MARK: - Clipboard

    /// Get clipboard contents
    public func getClipboard() async -> String {
        let result = try? await executor.execute("pbpaste")
        return result?.output ?? ""
    }

    /// Set clipboard contents
    public func setClipboard(_ text: String) async throws {
        let escaped = text.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await executor.execute("echo '\(escaped)' | pbcopy")
    }

    /// Clear clipboard
    public func clearClipboard() async throws {
        _ = try await executor.execute("pbcopy < /dev/null")
    }
}

// MARK: - Utility Commands Reference

public enum UtilityCommands {

    // Maintenance
    public static let periodicAll = "sudo periodic daily weekly monthly"
    public static let rebuildSpotlight = "sudo mdutil -E /"
    public static let updateDyld = "sudo update_dyld_shared_cache"

    // DNS
    public static let flushDNS = "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
    public static let getDNS = "scutil --dns | grep nameserver"

    // Security
    public static let sipStatus = "csrutil status"
    public static let gatekeeperStatus = "spctl --status"
    public static let filevaultStatus = "sudo fdesetup status"
    public static let firewallStatus = "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate"

    // Restart services
    public static let restartFinder = "killall Finder"
    public static let restartDock = "killall Dock"
    public static let restartMenuBar = "killall SystemUIServer && killall ControlCenter"
    public static let restartAudio = "sudo killall coreaudiod"
    public static let resetQuickLook = "qlmanage -r && qlmanage -r cache"

    // Power
    public static let preventSleep = "caffeinate -d"
    public static let powerSettings = "pmset -g"
    public static let sleepNow = "sudo pmset sleepnow"

    // System actions
    public static let shutdown = "sudo shutdown -h now"
    public static let restart = "sudo shutdown -r now"
    public static let lockScreen = "/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend"

    // Finder settings
    public static let showHiddenFiles = "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
    public static let hideHiddenFiles = "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

    // Clipboard
    public static let getClipboard = "pbpaste"
    public static let clearClipboard = "pbcopy < /dev/null"
}
