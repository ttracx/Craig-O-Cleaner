// MARK: - MemoryOptimizerServiceTests.swift
// Craig-O-Clean - Unit Tests for Memory Optimizer Service
// Tests memory analysis, cleanup candidates, and optimization workflows

import XCTest
@testable import Craig_O_Clean

@MainActor
final class MemoryOptimizerServiceTests: XCTestCase {
    
    var service: MemoryOptimizerService!
    
    override func setUp() {
        super.setUp()
        service = MemoryOptimizerService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertTrue(service.cleanupCandidates.isEmpty, "Cleanup candidates should be empty on init")
        XCTAssertTrue(service.selectedCandidates.isEmpty, "Selected candidates should be empty on init")
        XCTAssertFalse(service.isAnalyzing, "Should not be analyzing on init")
        XCTAssertFalse(service.isOptimizing, "Should not be optimizing on init")
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultThreshold() {
        let defaultThreshold: Int64 = 100 * 1024 * 1024 // 100 MB
        XCTAssertEqual(service.minimumMemoryThreshold, defaultThreshold, "Default threshold should be 100 MB")
    }
    
    func testExcludedBundleIdentifiers() {
        let excludedIds = service.excludedBundleIdentifiers
        XCTAssertTrue(excludedIds.contains("com.apple.finder"), "Finder should be excluded")
        XCTAssertTrue(excludedIds.contains("com.apple.dock"), "Dock should be excluded")
    }
    
    // MARK: - Analysis Tests
    
    func testAnalyzeMemoryUsage() async {
        await service.analyzeMemoryUsage()
        
        XCTAssertFalse(service.isAnalyzing, "Should not be analyzing after completion")
        // Note: cleanupCandidates may be empty if no apps meet threshold
    }
    
    // MARK: - Selection Tests
    
    func testSelectAll() async {
        await service.analyzeMemoryUsage()
        service.selectAll()
        
        XCTAssertEqual(
            service.selectedCandidates.count,
            service.cleanupCandidates.count,
            "All candidates should be selected"
        )
    }
    
    func testDeselectAll() async {
        await service.analyzeMemoryUsage()
        service.selectAll()
        service.deselectAll()
        
        XCTAssertTrue(service.selectedCandidates.isEmpty, "No candidates should be selected after deselect")
    }
    
    // MARK: - Category Tests
    
    func testCleanupCategories() {
        let allCategories = CleanupCategory.allCases
        XCTAssertEqual(allCategories.count, 4, "Should have 4 cleanup categories")
        
        XCTAssertTrue(allCategories.contains(.heavyMemory))
        XCTAssertTrue(allCategories.contains(.backgroundApps))
        XCTAssertTrue(allCategories.contains(.inactiveApps))
        XCTAssertTrue(allCategories.contains(.browserTabs))
    }
    
    func testCategoryDescriptions() {
        for category in CleanupCategory.allCases {
            XCTAssertFalse(category.description.isEmpty, "Category \(category) should have description")
            XCTAssertFalse(category.icon.isEmpty, "Category \(category) should have icon")
        }
    }
    
    // MARK: - Helpers Tests
    
    func testGetSuggestionsByCategory() async {
        await service.analyzeMemoryUsage()
        let suggestions = service.getSuggestionsByCategory()
        
        // Should return dictionary grouped by category
        XCTAssertNotNil(suggestions, "Suggestions dictionary should not be nil")
    }
    
    func testGetTopMemoryConsumers() async {
        await service.analyzeMemoryUsage()
        let top5 = service.getTopMemoryConsumers(limit: 5)
        
        XCTAssertLessThanOrEqual(top5.count, 5, "Should return at most 5 consumers")
    }
    
    func testGetBackgroundApps() async {
        await service.analyzeMemoryUsage()
        let backgroundApps = service.getBackgroundApps()
        
        // All returned apps should be marked as background
        for app in backgroundApps {
            XCTAssertTrue(app.isBackgroundApp, "App should be background app")
        }
    }
    
    // MARK: - Purge Tests
    
    func testIsPurgeAvailable() {
        let isAvailable = service.isPurgeAvailable()
        // Purge should be available on macOS
        XCTAssertTrue(isAvailable, "Purge should be available on macOS")
    }
    
    // MARK: - CleanupResult Tests
    
    func testCleanupResultFormatting() {
        let result = CleanupResult(
            appsTerminated: 3,
            memoryFreed: 512 * 1024 * 1024, // 512 MB
            success: true,
            errors: [],
            timestamp: Date()
        )
        
        XCTAssertEqual(result.appsTerminated, 3)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(result.formattedMemoryFreed.isEmpty, "Formatted memory should not be empty")
    }
    
    // MARK: - CleanupCandidate Tests
    
    func testCleanupCandidateFormatting() {
        let candidate = CleanupCandidate(
            id: "test",
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
        
        XCTAssertFalse(candidate.formattedMemoryUsage.isEmpty)
        XCTAssertFalse(candidate.potentialSavings.isEmpty)
    }
}
