// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Cleaner/DirectProCleanerService.swift
// Craig-O-Clean - DirectPro Cleaner Service
// Full-featured cleanup service for DirectPro edition

import Foundation

/// Cleaner service for DirectPro edition with full system-wide capabilities.
/// Extends SafeCleanerService with additional privileged operations.
@MainActor
public final class DirectProCleanerService: SafeCleanerService {

    // MARK: - Properties

    private let capabilities = DirectProCapabilities.shared

    // MARK: - Initialization

    public override init(logger: Logger, fileManager: FileManager = .default) {
        super.init(logger: logger, fileManager: fileManager)
        logger.debug("DirectProCleanerService initialized", category: .cleanup)
    }

    // MARK: - Override Available Targets

    public override func availableTargets() -> [CleanupTarget] {
        var targets = CleanupTarget.userCacheTargets()

        // Add system-wide targets for DirectPro
        if capabilities.canDeleteSystemWideCaches {
            targets.append(contentsOf: CleanupTarget.systemCacheTargets())
        }

        // Add additional Pro-only targets
        targets.append(contentsOf: proOnlyTargets())

        return targets
    }

    // MARK: - Path Validation Override

    override func isPathAllowed(_ path: String) -> Bool {
        // DirectPro can access more paths
        let home = NSHomeDirectory()

        // Always allow user home
        if path.hasPrefix(home) {
            return true
        }

        // Allow system paths if helper is installed (TODO: check helper status)
        let allowedSystemPaths = [
            "/Library/Caches",
            "/Library/Logs",
            "/private/var/folders"
        ]

        for allowed in allowedSystemPaths {
            if path.hasPrefix(allowed) {
                return true
            }
        }

        // Block truly system-critical paths
        let blockedPaths = [
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/private/var/db",
            "/Library/Preferences"
        ]

        for blocked in blockedPaths {
            if path.hasPrefix(blocked) {
                logger.warning("Blocked access to system path: \(path)", category: .cleanup)
                return false
            }
        }

        return false
    }

    // MARK: - Pro-Only Targets

    private func proOnlyTargets() -> [CleanupTarget] {
        let home = "~"
        return [
            CleanupTarget(
                name: "Application Caches (All Users)",
                description: "Cache files from all applications for all users",
                category: .systemCaches,
                paths: ["/Library/Caches"],
                requiresPrivileges: true
            ),
            CleanupTarget(
                name: "System Logs",
                description: "System-level log files",
                category: .logs,
                paths: ["/Library/Logs"],
                requiresPrivileges: true
            ),
            CleanupTarget(
                name: "Temporary Items",
                description: "System and user temporary files",
                category: .other,
                paths: ["\(home)/Library/Caches/TemporaryItems", "/private/var/folders"],
                requiresPrivileges: true
            ),
            CleanupTarget(
                name: "Homebrew Cache",
                description: "Homebrew package manager cache",
                category: .developerTools,
                paths: ["\(home)/Library/Caches/Homebrew"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "npm Cache",
                description: "Node.js package manager cache",
                category: .developerTools,
                paths: ["\(home)/.npm/_cacache"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "CocoaPods Cache",
                description: "iOS/macOS dependency manager cache",
                category: .developerTools,
                paths: ["\(home)/Library/Caches/CocoaPods"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "Gradle Cache",
                description: "Gradle build system cache",
                category: .developerTools,
                paths: ["\(home)/.gradle/caches"],
                requiresPrivileges: false
            ),
            CleanupTarget(
                name: "Docker Images (Unused)",
                description: "Unused Docker images and containers",
                category: .developerTools,
                paths: ["\(home)/.docker"],
                requiresPrivileges: false
            )
        ]
    }

    // MARK: - Privileged Cleanup

    /// Runs cleanup requiring privileged helper (placeholder for future implementation)
    public func runPrivilegedCleanup(targets: [CleanupTarget]) async throws -> CleanupSessionResult {
        logger.info("Privileged cleanup requested for \(targets.count) targets", category: .cleanup)

        // TODO: Implement XPC communication with privileged helper
        // For now, fall back to standard cleanup with warning

        logger.warning("Privileged helper not yet implemented, using standard cleanup", category: .cleanup)

        return try await runCleanup(targets: targets, dryRun: false)
    }
}

// MARK: - System Cleanup Operations

extension DirectProCleanerService {

    /// Calculates the size of system caches (requires Full Disk Access)
    public func calculateSystemCacheSize() async -> UInt64 {
        var totalSize: UInt64 = 0

        let systemCachePaths = [
            "/Library/Caches",
            "/System/Library/Caches"
        ]

        for path in systemCachePaths {
            if let (_, size) = try? await scanDirectory(at: path) {
                totalSize += size
            }
        }

        return totalSize
    }

    /// Checks if Full Disk Access is available
    public var hasFullDiskAccess: Bool {
        capabilities.hasFullDiskAccess()
    }

    /// Checks if privileged helper is installed
    public var isHelperInstalled: Bool {
        capabilities.isHelperInstalled()
    }
}
