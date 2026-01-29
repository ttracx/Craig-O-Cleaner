// File: CraigOClean-vNext/CraigOClean/Domain/Protocols/CleanerService.swift
// Craig-O-Clean - Cleaner Service Protocol
// Protocol defining cleanup operations

import Foundation

/// Protocol for cleanup service implementations
@MainActor
public protocol CleanerService: Sendable {

    /// Returns the available cleanup targets for the current edition
    func availableTargets() -> [CleanupTarget]

    /// Scans specified targets and returns file information for preview
    /// - Parameter targets: The targets to scan
    /// - Returns: Scan results with file details and sizes
    func scanTargets(_ targets: [CleanupTarget]) async throws -> [CleanupScanResult]

    /// Scans a single target and returns file information
    /// - Parameter target: The target to scan
    /// - Returns: Scan result with file details
    func scanTarget(_ target: CleanupTarget) async throws -> CleanupScanResult

    /// Runs cleanup on the specified targets
    /// - Parameter targets: The targets to clean
    /// - Parameter dryRun: If true, simulates cleanup without deleting files
    /// - Returns: Results of the cleanup operation
    func runCleanup(targets: [CleanupTarget], dryRun: Bool) async throws -> CleanupSessionResult

    /// Cancels any ongoing cleanup operation
    func cancelCleanup()

    /// Returns true if a cleanup operation is currently in progress
    var isRunning: Bool { get }

    /// Progress of current operation (0.0 to 1.0)
    var progress: Double { get }

    /// Current status message
    var statusMessage: String { get }
}

// MARK: - Default Implementations

extension CleanerService {

    /// Convenience method to scan all available targets
    public func scanAllTargets() async throws -> [CleanupScanResult] {
        try await scanTargets(availableTargets())
    }

    /// Convenience method to run cleanup on selected targets only
    public func runCleanupOnSelected(from targets: [CleanupTarget], dryRun: Bool = false) async throws -> CleanupSessionResult {
        let selected = targets.filter { $0.isSelected }
        return try await runCleanup(targets: selected, dryRun: dryRun)
    }
}

// MARK: - Cleanup Progress

/// Observable progress state for cleanup operations
@MainActor
public final class CleanupProgress: ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var currentTarget: String = ""
    @Published public var statusMessage: String = ""
    @Published public var filesProcessed: Int = 0
    @Published public var bytesProcessed: UInt64 = 0

    public init() {}

    public func reset() {
        isRunning = false
        progress = 0.0
        currentTarget = ""
        statusMessage = ""
        filesProcessed = 0
        bytesProcessed = 0
    }

    public func start(target: String) {
        isRunning = true
        currentTarget = target
        statusMessage = "Processing \(target)..."
    }

    public func update(progress: Double, files: Int, bytes: UInt64) {
        self.progress = progress
        self.filesProcessed = files
        self.bytesProcessed = bytes
    }

    public func complete() {
        isRunning = false
        progress = 1.0
        statusMessage = "Cleanup complete"
    }

    public func fail(message: String) {
        isRunning = false
        statusMessage = "Failed: \(message)"
    }
}
