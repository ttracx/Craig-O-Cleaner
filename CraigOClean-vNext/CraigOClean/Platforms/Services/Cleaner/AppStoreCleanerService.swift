// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Cleaner/AppStoreCleanerService.swift
// Craig-O-Clean - App Store Cleaner Service
// Sandboxed cleanup service for App Store Lite edition

import Foundation

/// Cleaner service for App Store Lite edition with strict sandbox compliance.
/// Only allows operations within user's home directory.
@MainActor
public final class AppStoreCleanerService: SafeCleanerService {

    // MARK: - Properties

    private let capabilities = AppStoreLiteCapabilities.shared

    // MARK: - Initialization

    public override init(logger: Logger, fileManager: FileManager = .default) {
        super.init(logger: logger, fileManager: fileManager)
        logger.debug("AppStoreCleanerService initialized (sandbox mode)", category: .cleanup)
    }

    // MARK: - Override Available Targets

    public override func availableTargets() -> [CleanupTarget] {
        // Only return user-level targets, filtered for sandbox safety
        CleanupTarget.userCacheTargets().filter { target in
            // Ensure all paths are within allowed directories
            target.expandedPaths.allSatisfy { capabilities.isPathAllowed($0) }
        }
    }

    // MARK: - Strict Path Validation

    override func isPathAllowed(_ path: String) -> Bool {
        // Delegate to AppStoreLiteCapabilities for strict sandbox validation
        capabilities.isPathAllowed(path)
    }

    // MARK: - Override Scan to Add Compliance Checks

    public override func scanTarget(_ target: CleanupTarget) async throws -> CleanupScanResult {
        // Verify target doesn't require privileges
        if target.requiresPrivileges {
            logger.warning("Rejecting privileged target in sandbox: \(target.name)", category: .cleanup)
            throw CleanupError.notSupportedInEdition(
                reason: "This cleanup target requires privileges not available in the App Store edition"
            )
        }

        // Validate all paths
        for path in target.expandedPaths {
            if !capabilities.isPathAllowed(path) {
                logger.warning("Path not allowed in sandbox: \(path)", category: .cleanup)
                throw CleanupError.pathNotAllowed(path: path)
            }
        }

        return try await super.scanTarget(target)
    }

    // MARK: - Override Cleanup to Add Compliance Checks

    public override func runCleanup(targets: [CleanupTarget], dryRun: Bool) async throws -> CleanupSessionResult {
        // Filter out any privileged targets with warning
        let safeTargets = targets.filter { target in
            if target.requiresPrivileges {
                logger.warning("Skipping privileged target: \(target.name)", category: .cleanup)
                return false
            }

            let allPathsAllowed = target.expandedPaths.allSatisfy { capabilities.isPathAllowed($0) }
            if !allPathsAllowed {
                logger.warning("Skipping target with disallowed paths: \(target.name)", category: .cleanup)
                return false
            }

            return true
        }

        if safeTargets.count < targets.count {
            let skipped = targets.count - safeTargets.count
            logger.info("Skipped \(skipped) targets due to sandbox restrictions", category: .cleanup)
        }

        if safeTargets.isEmpty {
            throw CleanupError.notSupportedInEdition(
                reason: "No cleanup targets are available within sandbox restrictions"
            )
        }

        return try await super.runCleanup(targets: safeTargets, dryRun: dryRun)
    }
}

// MARK: - Sandbox-Specific Helpers

extension AppStoreCleanerService {

    /// Returns the reason why a target is not available
    public func unavailabilityReason(for target: CleanupTarget) -> String? {
        if target.requiresPrivileges {
            return "Requires administrator privileges (available in Pro edition)"
        }

        let disallowedPaths = target.expandedPaths.filter { !capabilities.isPathAllowed($0) }
        if !disallowedPaths.isEmpty {
            return "Contains paths outside sandbox: \(disallowedPaths.first ?? "unknown")"
        }

        return nil
    }

    /// Returns user-friendly explanation for sandbox limitations
    public var sandboxExplanation: String {
        """
        The App Store edition runs in a secure sandbox that limits access to system files. \
        This ensures your data stays safe but means some cleanup operations are not available.

        For full system-wide cleanup, consider Craig-O-Clean Pro which can be downloaded directly \
        from our website.
        """
    }

    /// Checks if a target is available in sandbox mode
    public func isTargetAvailable(_ target: CleanupTarget) -> Bool {
        !target.requiresPrivileges &&
        target.expandedPaths.allSatisfy { capabilities.isPathAllowed($0) }
    }
}
