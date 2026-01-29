// File: CraigOClean-vNext/CraigOClean/Domain/UseCases/RunCleanup.swift
// Craig-O-Clean - Run Cleanup Use Case
// Orchestrates the cleanup workflow

import Foundation

/// Use case for running cleanup operations
@MainActor
public final class RunCleanup: ObservableObject {

    private let cleanerService: any CleanerService
    private let permissionService: any PermissionService
    private let logger: Logger

    @Published public private(set) var scanResults: [CleanupScanResult] = []
    @Published public private(set) var sessionResult: CleanupSessionResult?
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isCleaning: Bool = false
    @Published public private(set) var error: CleanupError?

    public init(
        cleanerService: any CleanerService,
        permissionService: any PermissionService,
        logger: Logger
    ) {
        self.cleanerService = cleanerService
        self.permissionService = permissionService
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Returns all available cleanup targets
    public func availableTargets() -> [CleanupTarget] {
        cleanerService.availableTargets()
    }

    /// Scans the specified targets to preview cleanup
    public func scan(targets: [CleanupTarget]) async {
        isScanning = true
        error = nil
        scanResults = []

        logger.info("Starting scan for \(targets.count) targets", category: .cleanup)

        do {
            scanResults = try await cleanerService.scanTargets(targets)

            let totalSize = scanResults.reduce(0) { $0 + $1.totalSize }
            let totalFiles = scanResults.reduce(0) { $0 + $1.fileCount }

            logger.info(
                "Scan complete: \(totalFiles) files, \(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file))",
                category: .cleanup
            )
        } catch let err as CleanupError {
            error = err
            logger.error("Scan failed: \(err.localizedDescription)", category: .cleanup)
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            logger.error("Scan failed: \(error.localizedDescription)", category: .cleanup)
        }

        isScanning = false
    }

    /// Runs cleanup on the specified targets
    /// - Parameter targets: Targets to clean
    /// - Parameter dryRun: If true, simulates without deleting
    public func execute(targets: [CleanupTarget], dryRun: Bool = false) async {
        isCleaning = true
        error = nil
        sessionResult = nil

        let privilegedTargets = targets.filter { $0.requiresPrivileges }
        if !privilegedTargets.isEmpty {
            logger.info("Checking privileges for \(privilegedTargets.count) targets", category: .cleanup)

            do {
                let granted = try await permissionService.requestAdminIfNeeded(for: .deleteSystemCaches)
                if !granted {
                    error = .notSupportedInEdition(reason: "Admin privileges required but not granted")
                    isCleaning = false
                    return
                }
            } catch {
                self.error = .notSupportedInEdition(reason: error.localizedDescription)
                isCleaning = false
                return
            }
        }

        logger.info("Starting cleanup for \(targets.count) targets (dryRun: \(dryRun))", category: .cleanup)

        do {
            sessionResult = try await cleanerService.runCleanup(targets: targets, dryRun: dryRun)

            if let result = sessionResult {
                logger.info(
                    "Cleanup complete: \(result.totalFilesRemoved) files, \(result.formattedTotalBytesFreed) freed",
                    category: .cleanup
                )
            }
        } catch let err as CleanupError {
            error = err
            logger.error("Cleanup failed: \(err.localizedDescription)", category: .cleanup)
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            logger.error("Cleanup failed: \(error.localizedDescription)", category: .cleanup)
        }

        isCleaning = false
    }

    /// Cancels the current operation
    public func cancel() {
        cleanerService.cancelCleanup()
        logger.info("Cleanup cancelled by user", category: .cleanup)
    }

    /// Resets the use case state
    public func reset() {
        scanResults = []
        sessionResult = nil
        error = nil
    }
}
