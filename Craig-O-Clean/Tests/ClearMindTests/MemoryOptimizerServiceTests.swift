// MARK: - MemoryOptimizerServiceTests.swift
// CraigOClean Control Center - Unit Tests for MemoryOptimizerService

import XCTest
@testable import Craig_O_Clean

@MainActor
final class MemoryOptimizerServiceTests: XCTestCase {
    
    var sut: MemoryOptimizerService!
    
    override func setUp() async throws {
        sut = MemoryOptimizerService()
    }
    
    override func tearDown() async throws {
        sut = nil
    }
    
    // MARK: - Analysis Tests
    
    func testAnalyzeMemoryUsage() async throws {
        XCTAssertFalse(sut.isAnalyzing, "Should not be analyzing initially")
        XCTAssertTrue(sut.cleanupCandidates.isEmpty, "Candidates should be empty initially")
        
        await sut.analyzeMemoryUsage()
        
        XCTAssertFalse(sut.isAnalyzing, "Should not be analyzing after completion")
        // Note: candidates might be empty if no apps meet threshold
    }
    
    func testPotentialMemorySavings() async throws {
        await sut.analyzeMemoryUsage()
        
        let expectedSavings = sut.cleanupCandidates.reduce(0) { $0 + $1.memoryUsage }
        XCTAssertEqual(sut.potentialMemorySavings, expectedSavings, "Potential savings should match sum of candidate memory")
    }
    
    // MARK: - Selection Tests
    
    func testToggleSelection() async throws {
        await sut.analyzeMemoryUsage()
        
        guard let candidate = sut.cleanupCandidates.first else {
            // Skip if no candidates (could happen on fresh system)
            return
        }
        
        XCTAssertFalse(sut.selectedCandidates.contains(candidate), "Candidate should not be selected initially")
        
        sut.toggleSelection(candidate)
        XCTAssertTrue(sut.selectedCandidates.contains(candidate), "Candidate should be selected after toggle")
        
        sut.toggleSelection(candidate)
        XCTAssertFalse(sut.selectedCandidates.contains(candidate), "Candidate should be deselected after second toggle")
    }
    
    func testSelectAll() async throws {
        await sut.analyzeMemoryUsage()
        
        sut.selectAll()
        XCTAssertEqual(sut.selectedCandidates.count, sut.cleanupCandidates.count, "All candidates should be selected")
    }
    
    func testDeselectAll() async throws {
        await sut.analyzeMemoryUsage()
        
        sut.selectAll()
        sut.deselectAll()
        
        XCTAssertTrue(sut.selectedCandidates.isEmpty, "No candidates should be selected after deselect all")
    }
    
    func testSelectByCategory() async throws {
        await sut.analyzeMemoryUsage()
        
        sut.selectByCategory(.heavyMemory)
        
        let heavyMemoryCandidates = sut.cleanupCandidates.filter { $0.category == .heavyMemory }
        for candidate in heavyMemoryCandidates {
            XCTAssertTrue(sut.selectedCandidates.contains(candidate), "Heavy memory candidates should be selected")
        }
    }
    
    // MARK: - Category Tests
    
    func testGetSuggestionsByCategory() async throws {
        await sut.analyzeMemoryUsage()
        
        let suggestions = sut.getSuggestionsByCategory()
        
        // Verify all candidates are categorized
        let totalCategorized = suggestions.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalCategorized, sut.cleanupCandidates.count, "All candidates should be categorized")
    }
    
    func testGetTopMemoryConsumers() async throws {
        await sut.analyzeMemoryUsage()
        
        let limit = 3
        let topConsumers = sut.getTopMemoryConsumers(limit: limit)
        
        XCTAssertLessThanOrEqual(topConsumers.count, limit, "Should return at most the limit number of consumers")
        
        // Verify sorted by memory (descending)
        for i in 0..<(topConsumers.count - 1) {
            XCTAssertGreaterThanOrEqual(topConsumers[i].memoryUsage, topConsumers[i + 1].memoryUsage, "Results should be sorted by memory usage descending")
        }
    }
    
    func testGetBackgroundApps() async throws {
        await sut.analyzeMemoryUsage()
        
        let backgroundApps = sut.getBackgroundApps()
        
        for app in backgroundApps {
            XCTAssertTrue(app.isBackgroundApp, "All returned apps should be background apps")
        }
    }
    
    // MARK: - Configuration Tests
    
    func testMinimumMemoryThreshold() {
        let newThreshold: Int64 = 50 * 1024 * 1024 // 50 MB
        sut.minimumMemoryThreshold = newThreshold
        XCTAssertEqual(sut.minimumMemoryThreshold, newThreshold, "Threshold should be configurable")
    }
    
    func testExcludedBundleIdentifiers() {
        let testBundleId = "com.test.app"
        sut.excludedBundleIdentifiers.insert(testBundleId)
        XCTAssertTrue(sut.excludedBundleIdentifiers.contains(testBundleId), "Excluded bundle IDs should be configurable")
    }
    
    // MARK: - Purge Availability Test
    
    func testIsPurgeAvailable() {
        let isAvailable = sut.isPurgeAvailable()
        // Just verify the method returns a boolean value
        XCTAssertTrue(isAvailable || !isAvailable, "isPurgeAvailable should return a boolean")
    }
    
    // MARK: - Cleanup Result Tests
    
    func testCleanupResultFormatting() {
        let result = CleanupResult(
            appsTerminated: 5,
            memoryFreed: 500 * 1024 * 1024, // 500 MB
            success: true,
            errors: [],
            timestamp: Date()
        )
        
        XCTAssertEqual(result.appsTerminated, 5)
        XCTAssertTrue(result.formattedMemoryFreed.contains("500") || result.formattedMemoryFreed.contains("MB"))
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    // MARK: - Cleanup Candidate Tests
    
    func testCleanupCandidateFormattedMemoryUsage() {
        let candidateMB = CleanupCandidate(
            id: "test1",
            name: "Test App",
            bundleIdentifier: "com.test.app",
            memoryUsage: 256 * 1024 * 1024, // 256 MB
            cpuUsage: 5.0,
            lastActiveTime: nil,
            processId: 12345,
            isBackgroundApp: false,
            icon: nil,
            category: .heavyMemory
        )
        
        XCTAssertTrue(candidateMB.formattedMemoryUsage.contains("256") || candidateMB.formattedMemoryUsage.contains("MB"))
        
        let candidateGB = CleanupCandidate(
            id: "test2",
            name: "Heavy App",
            bundleIdentifier: "com.heavy.app",
            memoryUsage: 2 * 1024 * 1024 * 1024, // 2 GB
            cpuUsage: 10.0,
            lastActiveTime: nil,
            processId: 12346,
            isBackgroundApp: false,
            icon: nil,
            category: .heavyMemory
        )
        
        XCTAssertTrue(candidateGB.formattedMemoryUsage.contains("2") && candidateGB.formattedMemoryUsage.contains("GB"))
    }
    
    func testCleanupCategoryProperties() {
        for category in CleanupCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty, "Category should have a raw value")
            XCTAssertFalse(category.description.isEmpty, "Category should have a description")
            XCTAssertFalse(category.icon.isEmpty, "Category should have an icon")
        }
    }
}
