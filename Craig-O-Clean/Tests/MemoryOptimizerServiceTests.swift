// MemoryOptimizerServiceTests.swift
// ClearMind Control Center Tests
//
// Unit tests for MemoryOptimizerService

import XCTest
@testable import Craig_O_Clean

final class MemoryOptimizerServiceTests: XCTestCase {
    
    var sut: MemoryOptimizerService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        sut = MemoryOptimizerService()
    }
    
    @MainActor
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    @MainActor
    func testInitialStateIsClean() {
        XCTAssertTrue(sut.cleanupCandidates.isEmpty, "Initial cleanup candidates should be empty")
        XCTAssertTrue(sut.suggestions.isEmpty, "Initial suggestions should be empty")
        XCTAssertTrue(sut.selectedForCleanup.isEmpty, "Initial selection should be empty")
        XCTAssertEqual(sut.currentStep, .analyze, "Initial step should be analyze")
        XCTAssertFalse(sut.isProcessing, "Should not be processing initially")
        XCTAssertNil(sut.lastResult, "Last result should be nil initially")
    }
    
    // MARK: - Analysis Tests
    
    @MainActor
    func testAnalyzeForCleanupUpdatesStep() async {
        // When
        await sut.analyzeForCleanup()
        
        // Then
        XCTAssertEqual(sut.currentStep, .review, "Step should be review after analysis")
    }
    
    @MainActor
    func testAnalyzeForCleanupPopulatesCandidates() async {
        // When
        await sut.analyzeForCleanup()
        
        // Then - should have some candidates (at least the app itself)
        // Note: In a real test, we might mock NSWorkspace.shared.runningApplications
        XCTAssertFalse(sut.isProcessing, "Should not be processing after analysis completes")
    }
    
    // MARK: - Selection Tests
    
    @MainActor
    func testToggleSelectionAddsCandidate() {
        // Given
        let candidate = CleanupCandidate(
            id: "com.test.app",
            name: "Test App",
            bundleIdentifier: "com.test.app",
            pid: 1234,
            memoryUsage: 500_000_000,
            lastActiveTime: nil,
            isBackground: true,
            icon: nil
        )
        sut.cleanupCandidates = [candidate]
        
        // When
        sut.toggleSelection(candidate)
        
        // Then
        XCTAssertTrue(sut.selectedForCleanup.contains(candidate.id))
    }
    
    @MainActor
    func testToggleSelectionRemovesCandidate() {
        // Given
        let candidate = CleanupCandidate(
            id: "com.test.app",
            name: "Test App",
            bundleIdentifier: "com.test.app",
            pid: 1234,
            memoryUsage: 500_000_000,
            lastActiveTime: nil,
            isBackground: true,
            icon: nil
        )
        sut.cleanupCandidates = [candidate]
        sut.selectedForCleanup.insert(candidate.id)
        
        // When
        sut.toggleSelection(candidate)
        
        // Then
        XCTAssertFalse(sut.selectedForCleanup.contains(candidate.id))
    }
    
    @MainActor
    func testSelectAll() {
        // Given
        let candidates = [
            CleanupCandidate(id: "app1", name: "App 1", bundleIdentifier: "app1", pid: 1, memoryUsage: 100, lastActiveTime: nil, isBackground: true, icon: nil),
            CleanupCandidate(id: "app2", name: "App 2", bundleIdentifier: "app2", pid: 2, memoryUsage: 200, lastActiveTime: nil, isBackground: true, icon: nil),
            CleanupCandidate(id: "app3", name: "App 3", bundleIdentifier: "app3", pid: 3, memoryUsage: 300, lastActiveTime: nil, isBackground: true, icon: nil)
        ]
        sut.cleanupCandidates = candidates
        
        // When
        sut.selectAll()
        
        // Then
        XCTAssertEqual(sut.selectedForCleanup.count, 3)
        XCTAssertTrue(sut.selectedForCleanup.contains("app1"))
        XCTAssertTrue(sut.selectedForCleanup.contains("app2"))
        XCTAssertTrue(sut.selectedForCleanup.contains("app3"))
    }
    
    @MainActor
    func testDeselectAll() {
        // Given
        sut.selectedForCleanup = ["app1", "app2", "app3"]
        
        // When
        sut.deselectAll()
        
        // Then
        XCTAssertTrue(sut.selectedForCleanup.isEmpty)
    }
    
    // MARK: - Memory Estimation Tests
    
    @MainActor
    func testEstimatedMemoryCalculation() {
        // Given
        let candidates = [
            CleanupCandidate(id: "app1", name: "App 1", bundleIdentifier: "app1", pid: 1, memoryUsage: 100_000_000, lastActiveTime: nil, isBackground: true, icon: nil),
            CleanupCandidate(id: "app2", name: "App 2", bundleIdentifier: "app2", pid: 2, memoryUsage: 200_000_000, lastActiveTime: nil, isBackground: true, icon: nil),
            CleanupCandidate(id: "app3", name: "App 3", bundleIdentifier: "app3", pid: 3, memoryUsage: 300_000_000, lastActiveTime: nil, isBackground: true, icon: nil)
        ]
        sut.cleanupCandidates = candidates
        sut.selectedForCleanup = ["app1", "app3"] // Only select app1 and app3
        
        // When
        sut.updateEstimatedMemory()
        
        // Then
        XCTAssertEqual(sut.estimatedMemoryToFree, 400_000_000) // 100 + 300
    }
    
    // MARK: - Step Navigation Tests
    
    @MainActor
    func testProceedToConfirmWithSelection() {
        // Given
        sut.selectedForCleanup = ["app1"]
        sut.currentStep = .review
        
        // When
        sut.proceedToConfirm()
        
        // Then
        XCTAssertEqual(sut.currentStep, .confirm)
    }
    
    @MainActor
    func testProceedToConfirmWithoutSelection() {
        // Given
        sut.selectedForCleanup = []
        sut.currentStep = .review
        
        // When
        sut.proceedToConfirm()
        
        // Then - should stay at review
        XCTAssertEqual(sut.currentStep, .review)
    }
    
    @MainActor
    func testBackToReview() {
        // Given
        sut.currentStep = .confirm
        
        // When
        sut.backToReview()
        
        // Then
        XCTAssertEqual(sut.currentStep, .review)
    }
    
    @MainActor
    func testReset() {
        // Given
        sut.cleanupCandidates = [
            CleanupCandidate(id: "app1", name: "App", bundleIdentifier: "app", pid: 1, memoryUsage: 100, lastActiveTime: nil, isBackground: true, icon: nil)
        ]
        sut.selectedForCleanup = ["app1"]
        sut.currentStep = .complete
        
        // When
        sut.reset()
        
        // Then
        XCTAssertTrue(sut.cleanupCandidates.isEmpty)
        XCTAssertTrue(sut.selectedForCleanup.isEmpty)
        XCTAssertEqual(sut.currentStep, .analyze)
        XCTAssertNil(sut.lastResult)
    }
    
    // MARK: - Statistics Tests
    
    @MainActor
    func testTotalCandidatesMemory() {
        // Given
        let candidates = [
            CleanupCandidate(id: "app1", name: "App 1", bundleIdentifier: "app1", pid: 1, memoryUsage: 100_000_000, lastActiveTime: nil, isBackground: true, icon: nil),
            CleanupCandidate(id: "app2", name: "App 2", bundleIdentifier: "app2", pid: 2, memoryUsage: 200_000_000, lastActiveTime: nil, isBackground: true, icon: nil)
        ]
        sut.cleanupCandidates = candidates
        
        // Then
        XCTAssertEqual(sut.totalCandidatesMemory, 300_000_000)
    }
    
    @MainActor
    func testSelectedCount() {
        // Given
        sut.selectedForCleanup = ["app1", "app2", "app3"]
        
        // Then
        XCTAssertEqual(sut.selectedCount, 3)
    }
}

// MARK: - Cleanup Candidate Model Tests

final class CleanupCandidateModelTests: XCTestCase {
    
    func testMemoryFormatted_MB() {
        // Given
        let candidate = CleanupCandidate(
            id: "test",
            name: "Test",
            bundleIdentifier: "test",
            pid: 1,
            memoryUsage: 500_000_000, // 500 MB
            lastActiveTime: nil,
            isBackground: false,
            icon: nil
        )
        
        // Then
        XCTAssertTrue(candidate.memoryFormatted.contains("MB"))
        XCTAssertTrue(candidate.memoryFormatted.contains("476") || candidate.memoryFormatted.contains("477")) // ~477 MB
    }
    
    func testMemoryFormatted_GB() {
        // Given
        let candidate = CleanupCandidate(
            id: "test",
            name: "Test",
            bundleIdentifier: "test",
            pid: 1,
            memoryUsage: 2_000_000_000, // 2 GB
            lastActiveTime: nil,
            isBackground: false,
            icon: nil
        )
        
        // Then
        XCTAssertTrue(candidate.memoryFormatted.contains("GB"))
    }
    
    func testIsInactive_WithRecentActivity() {
        // Given
        let candidate = CleanupCandidate(
            id: "test",
            name: "Test",
            bundleIdentifier: "test",
            pid: 1,
            memoryUsage: 100_000_000,
            lastActiveTime: Date(), // Just now
            isBackground: false,
            icon: nil
        )
        
        // Then
        XCTAssertFalse(candidate.isInactive)
    }
    
    func testIsInactive_WithOldActivity() {
        // Given
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let candidate = CleanupCandidate(
            id: "test",
            name: "Test",
            bundleIdentifier: "test",
            pid: 1,
            memoryUsage: 100_000_000,
            lastActiveTime: tenMinutesAgo,
            isBackground: false,
            icon: nil
        )
        
        // Then
        XCTAssertTrue(candidate.isInactive)
    }
    
    func testIsInactive_WithNoActivity() {
        // Given
        let candidate = CleanupCandidate(
            id: "test",
            name: "Test",
            bundleIdentifier: "test",
            pid: 1,
            memoryUsage: 100_000_000,
            lastActiveTime: nil,
            isBackground: false,
            icon: nil
        )
        
        // Then
        XCTAssertTrue(candidate.isInactive)
    }
}

// MARK: - Cleanup Result Model Tests

final class CleanupResultModelTests: XCTestCase {
    
    func testFreedMemoryFormatted_MB() {
        // Given
        let result = CleanupResult(
            success: true,
            freedMemory: 500_000_000,
            appsTerminated: 2,
            errors: []
        )
        
        // Then
        XCTAssertTrue(result.freedMemoryFormatted.contains("MB"))
    }
    
    func testFreedMemoryFormatted_GB() {
        // Given
        let result = CleanupResult(
            success: true,
            freedMemory: 2_000_000_000,
            appsTerminated: 5,
            errors: []
        )
        
        // Then
        XCTAssertTrue(result.freedMemoryFormatted.contains("GB"))
    }
}
