// File: CraigOClean-vNext/CraigOClean/Tests/CraigOCleanTests/CleanerServiceTests.swift
// Craig-O-Clean - Cleaner Service Tests
// Unit tests for cleanup services

import XCTest
@testable import CraigOClean

final class CleanerServiceTests: XCTestCase {

    var logStore: LogStore!
    var logger: Logger!

    override func setUp() async throws {
        logStore = LogStore()
        logger = Logger(store: logStore)
    }

    override func tearDown() async throws {
        logStore = nil
        logger = nil
    }

    // MARK: - Target Generation Tests

    @MainActor
    func testUserCacheTargetsGeneration() {
        let targets = CleanupTarget.userCacheTargets()

        XCTAssertFalse(targets.isEmpty)
        XCTAssertTrue(targets.allSatisfy { !$0.requiresPrivileges })
    }

    @MainActor
    func testSystemCacheTargetsRequirePrivileges() {
        let targets = CleanupTarget.systemCacheTargets()

        XCTAssertFalse(targets.isEmpty)
        XCTAssertTrue(targets.allSatisfy { $0.requiresPrivileges })
    }

    // MARK: - App Store Cleaner Tests

    @MainActor
    func testAppStoreCleanerOnlyReturnsUserTargets() async {
        let cleaner = AppStoreCleanerService(logger: logger)
        let targets = cleaner.availableTargets()

        // All targets should not require privileges
        XCTAssertTrue(targets.allSatisfy { !$0.requiresPrivileges })

        // All paths should be within user home
        let home = NSHomeDirectory()
        for target in targets {
            for path in target.expandedPaths {
                XCTAssertTrue(path.hasPrefix(home), "Path \(path) should be within user home")
            }
        }
    }

    @MainActor
    func testAppStoreCleanerBlocksSystemPaths() async {
        let cleaner = AppStoreCleanerService(logger: logger)

        // Create a target with system path
        let systemTarget = CleanupTarget(
            name: "System Caches",
            description: "Test",
            category: .systemCaches,
            paths: ["/Library/Caches"],
            requiresPrivileges: true
        )

        // Should not be available
        XCTAssertFalse(cleaner.isTargetAvailable(systemTarget))
    }

    @MainActor
    func testAppStoreCleanerRejectsPrivilegedTargets() async {
        let cleaner = AppStoreCleanerService(logger: logger)

        let privilegedTarget = CleanupTarget(
            name: "Privileged",
            description: "Test",
            category: .systemCaches,
            paths: ["/Library/Caches"],
            requiresPrivileges: true
        )

        let reason = cleaner.unavailabilityReason(for: privilegedTarget)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.contains("privileges") == true)
    }

    // MARK: - DirectPro Cleaner Tests

    @MainActor
    func testDirectProCleanerIncludesSystemTargets() async {
        let cleaner = DirectProCleanerService(logger: logger)
        let targets = cleaner.availableTargets()

        // Should include both user and system targets
        let hasUserTargets = targets.contains { !$0.requiresPrivileges }
        let hasSystemTargets = targets.contains { $0.requiresPrivileges }

        XCTAssertTrue(hasUserTargets)
        XCTAssertTrue(hasSystemTargets)
    }

    @MainActor
    func testDirectProCleanerHasMoreTargets() async {
        let proService = DirectProCleanerService(logger: logger)
        let liteService = AppStoreCleanerService(logger: logger)

        let proTargets = proService.availableTargets()
        let liteTargets = liteService.availableTargets()

        XCTAssertGreaterThan(proTargets.count, liteTargets.count)
    }

    // MARK: - Cleanup Target Model Tests

    func testCleanupTargetExpandedPaths() {
        let target = CleanupTarget(
            name: "Test",
            description: "Test target",
            category: .userCaches,
            paths: ["~/Library/Caches", "~/Library/Logs"]
        )

        let expandedPaths = target.expandedPaths
        let home = NSHomeDirectory()

        XCTAssertEqual(expandedPaths.count, 2)
        XCTAssertTrue(expandedPaths[0].hasPrefix(home))
        XCTAssertFalse(expandedPaths[0].contains("~"))
    }

    func testCleanupTargetFormattedSize() {
        var target = CleanupTarget(
            name: "Test",
            description: "Test",
            category: .userCaches,
            paths: []
        )
        target.estimatedSize = 1_000_000_000  // ~1 GB

        let formatted = target.formattedSize
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("MB"))
    }

    // MARK: - Cleanup Category Tests

    func testCleanupCategoryIcons() {
        for category in CleanupCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty)
        }
    }

    func testSystemCachesRequirePrivileges() {
        XCTAssertTrue(CleanupCategory.systemCaches.requiresPrivileges)
        XCTAssertFalse(CleanupCategory.userCaches.requiresPrivileges)
        XCTAssertFalse(CleanupCategory.logs.requiresPrivileges)
    }

    // MARK: - Cleanup Error Tests

    func testCleanupErrorDescriptions() {
        let errors: [CleanupError] = [
            .fileNotFound(path: "/test"),
            .permissionDenied(path: "/test"),
            .inUse(path: "/test"),
            .deletionFailed(path: "/test", underlyingError: "test error"),
            .pathNotAllowed(path: "/test"),
            .notSupportedInEdition(reason: "sandbox"),
            .scanFailed(reason: "test"),
            .cancelled,
            .unknown(message: "test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testCleanupErrorRecoverability() {
        XCTAssertTrue(CleanupError.fileNotFound(path: "/test").isRecoverable)
        XCTAssertTrue(CleanupError.inUse(path: "/test").isRecoverable)
        XCTAssertFalse(CleanupError.permissionDenied(path: "/test").isRecoverable)
        XCTAssertFalse(CleanupError.pathNotAllowed(path: "/test").isRecoverable)
        XCTAssertFalse(CleanupError.cancelled.isRecoverable)
    }

    // MARK: - Scan Result Tests

    func testCleanupScanResultFormatting() {
        let target = CleanupTarget(
            name: "Test",
            description: "Test",
            category: .userCaches,
            paths: []
        )

        let result = CleanupScanResult(
            target: target,
            files: [],
            totalSize: 500_000_000  // 500 MB
        )

        XCTAssertTrue(result.formattedTotalSize.contains("MB"))
        XCTAssertEqual(result.fileCount, 0)
    }

    // MARK: - Session Result Tests

    func testCleanupSessionResultAggregation() {
        let results = [
            CleanupResult(
                targetId: UUID(),
                targetName: "Target 1",
                success: true,
                bytesFreed: 100_000,
                filesRemoved: 10,
                startTime: Date(),
                endTime: Date()
            ),
            CleanupResult(
                targetId: UUID(),
                targetName: "Target 2",
                success: true,
                bytesFreed: 200_000,
                filesRemoved: 20,
                startTime: Date(),
                endTime: Date()
            )
        ]

        let session = CleanupSessionResult(
            results: results,
            startTime: Date(),
            endTime: Date()
        )

        XCTAssertEqual(session.totalBytesFreed, 300_000)
        XCTAssertEqual(session.totalFilesRemoved, 30)
        XCTAssertEqual(session.successfulCount, 2)
        XCTAssertEqual(session.failedCount, 0)
        XCTAssertTrue(session.allSuccessful)
    }
}
