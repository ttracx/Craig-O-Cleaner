// MARK: - SandboxConfiguration.swift
// Craig-O-Clean Sandbox Edition - Configuration and Constants
// Defines sandbox-compliant behavior and feature availability

import Foundation

/// Global configuration for the sandboxed version of Craig-O-Clean
/// All features are designed to work within Apple's App Sandbox constraints
enum SandboxConfiguration {

    // MARK: - App Information

    static let appName = "Craig-O-Clean"
    static let bundleIdentifier = "com.craigoclean.sandbox"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"

    // MARK: - Distribution Target

    /// The distribution target determines available features
    enum DistributionTarget {
        case macAppStore    // Strict sandbox, no privileged helper
        case developerID    // Sandbox with optional helper capabilities
    }

    /// Current distribution target - set this based on build configuration
    static let distributionTarget: DistributionTarget = .macAppStore

    // MARK: - Feature Flags

    struct Features {
        /// Process monitoring using native BSD APIs (always available)
        static let processMonitoring = true

        /// System metrics using Mach/BSD APIs (always available)
        static let systemMetrics = true

        /// Memory pressure monitoring via DispatchSource (always available)
        static let memoryPressureMonitoring = true

        /// Browser tab management via AppleScript (requires Automation permission)
        static let browserTabManagement = true

        /// User-selected folder cleanup (requires files.user-selected entitlement)
        static let userScopedCleanup = true

        /// App termination via NSRunningApplication (works in sandbox)
        static let appTermination = true

        /// Force quit via NSRunningApplication.forceTerminate() (works in sandbox)
        static let forceQuit = true

        /// Memory purge command (NOT available in MAS sandbox)
        static let memoryPurge: Bool = {
            return distributionTarget == .developerID
        }()

        /// Privileged helper operations (NOT available in MAS)
        static let privilegedHelper: Bool = {
            return distributionTarget == .developerID
        }()

        /// Global cache cleanup (NOT available - requires system file access)
        static let globalCacheCleanup = false

        /// System-wide file deletion (NOT available in sandbox)
        static let systemFileModification = false
    }

    // MARK: - Memory Thresholds

    struct MemoryThresholds {
        /// Memory pressure percentage considered "warning" (yellow)
        static let warningPercentage: Double = 60.0

        /// Memory pressure percentage considered "critical" (red)
        static let criticalPercentage: Double = 80.0

        /// Minimum memory threshold for cleanup candidate (100 MB)
        static let minimumCleanupThreshold: Int64 = 100 * 1024 * 1024

        /// Heavy memory user threshold (500 MB)
        static let heavyMemoryUserThreshold: Int64 = 500 * 1024 * 1024

        /// Background app memory threshold for auto-cleanup suggestions (200 MB)
        static let backgroundAppThreshold: Int64 = 200 * 1024 * 1024
    }

    // MARK: - Timing Configuration

    struct Timing {
        /// Default metrics refresh interval in seconds
        static let metricsRefreshInterval: TimeInterval = 2.0

        /// Process list refresh interval in seconds
        static let processRefreshInterval: TimeInterval = 2.0

        /// Browser tabs refresh interval in seconds
        static let browserTabsRefreshInterval: TimeInterval = 10.0

        /// Auto-cleanup monitoring interval (if enabled)
        static let autoCleanupMonitorInterval: TimeInterval = 30.0

        /// Timeout for AppleScript execution
        static let appleScriptTimeout: TimeInterval = 10.0

        /// Delay before showing startup notifications
        static let startupNotificationDelay: TimeInterval = 2.0
    }

    // MARK: - Protected Processes

    /// Processes that should never be terminated
    static let criticalProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "loginwindow",
        "SystemUIServer",
        "Dock",
        "Finder",
        "mds",
        "mds_stores",
        "coreauthd",
        "securityd",
        "cfprefsd",
        "UserEventAgent",
        "Craig-O-Clean",
        "Craig-O-Clean-Sandbox"
    ]

    /// Bundle identifiers to exclude from cleanup
    static let excludedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systempreferences",
        "com.apple.loginwindow",
        "com.apple.SystemUIServer",
        "com.craigoclean.sandbox",
        "com.craigoclean.app",
        "com.CraigOClean.controlcenter"
    ]

    // MARK: - Browser Configuration

    /// Supported browsers for tab management
    static let supportedBrowsers: [String: String] = [
        "Safari": "com.apple.Safari",
        "Google Chrome": "com.google.Chrome",
        "Microsoft Edge": "com.microsoft.edgemac",
        "Brave Browser": "com.brave.Browser",
        "Arc": "company.thebrowser.Browser"
    ]

    /// Browsers with limited or no AppleScript support
    static let unsupportedBrowsers: Set<String> = [
        "Firefox",
        "org.mozilla.firefox"
    ]

    // MARK: - Cleanup Configuration

    struct Cleanup {
        /// Maximum number of files to delete in a single operation
        static let maxFilesPerOperation = 1000

        /// File size threshold for warning before deletion (100 MB)
        static let largeFolderWarningThreshold: Int64 = 100 * 1024 * 1024

        /// Default trash folder name for safe deletion
        static let trashFolderName = "CraigOCleanTrash"

        /// Days to keep files in app's trash before permanent deletion
        static let trashRetentionDays = 7
    }

    // MARK: - User Defaults Keys

    struct UserDefaultsKeys {
        static let hasShownPermissionOnboarding = "hasShownPermissionOnboarding"
        static let hasRequestedSafariAutomation = "hasRequestedSafariAutomation"
        static let lastEasterEggDate = "lastEasterEggDate"
        static let autoCleanupEnabled = "autoCleanupEnabled"
        static let savedBookmarks = "savedSecurityScopedBookmarks"
        static let memoryWarningNotifications = "memoryWarningNotifications"
        static let lastCleanupDate = "lastCleanupDate"
    }
}

// MARK: - Feature Availability Matrix

/// Detailed feature availability based on permissions and sandbox constraints
struct CapabilityMatrix {

    /// Permission requirement for a capability
    enum PermissionRequirement {
        case none                   // No permission needed
        case accessibility          // Accessibility permission (System Preferences)
        case automation(String)     // Automation permission for specific app
        case fullDiskAccess         // Full Disk Access (cannot be used in MAS)
        case userSelected           // User must select via NSOpenPanel
        case developerIDOnly        // Only available outside MAS
    }

    /// Capability status
    enum CapabilityStatus {
        case available              // Can be used
        case requiresPermission     // Needs user permission
        case notAvailable           // Not possible in sandbox
        case degraded               // Partial functionality
    }

    /// Individual capability
    struct Capability {
        let name: String
        let description: String
        let requirement: PermissionRequirement
        let status: CapabilityStatus
        let sandboxCompliant: Bool
        let masCompliant: Bool
    }

    /// All app capabilities
    static let capabilities: [Capability] = [
        // Monitoring Capabilities (All Available)
        Capability(
            name: "Process List",
            description: "View running processes with CPU and memory usage",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "System Memory",
            description: "Monitor total, used, and available memory",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "CPU Usage",
            description: "Monitor per-core and total CPU usage",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "Memory Pressure",
            description: "Respond to system memory pressure events",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "Disk Usage",
            description: "Monitor disk space on system volume",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "Network Stats",
            description: "Monitor network interface traffic",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),

        // App Control Capabilities
        Capability(
            name: "Quit App",
            description: "Gracefully quit running applications",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "Force Quit",
            description: "Force terminate unresponsive applications",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),

        // Browser Capabilities
        Capability(
            name: "Safari Tabs",
            description: "View and close Safari browser tabs",
            requirement: .automation("com.apple.Safari"),
            status: .requiresPermission,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "Chrome Tabs",
            description: "View and close Chrome browser tabs",
            requirement: .automation("com.google.Chrome"),
            status: .requiresPermission,
            sandboxCompliant: true,
            masCompliant: true
        ),

        // Cleanup Capabilities
        Capability(
            name: "User-Selected Cleanup",
            description: "Clean caches in user-selected folders",
            requirement: .userSelected,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),
        Capability(
            name: "App Container Cleanup",
            description: "Clean app's own container files",
            requirement: .none,
            status: .available,
            sandboxCompliant: true,
            masCompliant: true
        ),

        // Advanced Capabilities (Limited or Not Available)
        Capability(
            name: "Memory Purge",
            description: "Purge inactive memory (requires admin)",
            requirement: .developerIDOnly,
            status: .notAvailable,
            sandboxCompliant: false,
            masCompliant: false
        ),
        Capability(
            name: "Global Cache Cleanup",
            description: "Clean system-wide caches",
            requirement: .fullDiskAccess,
            status: .notAvailable,
            sandboxCompliant: false,
            masCompliant: false
        ),
        Capability(
            name: "Startup Items",
            description: "View startup items (read-only, link to Settings)",
            requirement: .none,
            status: .degraded,
            sandboxCompliant: true,
            masCompliant: true
        )
    ]

    /// Get capabilities by status
    static func capabilities(with status: CapabilityStatus) -> [Capability] {
        return capabilities.filter { $0.status == status }
    }

    /// Get MAS-compliant capabilities only
    static var masCompliantCapabilities: [Capability] {
        return capabilities.filter { $0.masCompliant }
    }
}
