// MARK: - AutoCleanupServiceTests.swift
// Craig-O-Clean - Unit Tests for Auto Cleanup Service
// Tests automatic resource monitoring and cleanup functionality

import XCTest
@testable import Craig_O_Clean

@MainActor
final class AutoCleanupServiceTests: XCTestCase {
    
    var service: AutoCleanupService!
    var systemMetrics: SystemMetricsService!
    var memoryOptimizer: MemoryOptimizerService!
    var processManager: ProcessManager!
    
    override func setUp() {
        super.setUp()
        systemMetrics = SystemMetricsService()
        memoryOptimizer = MemoryOptimizerService()
        processManager = ProcessManager()
        service = AutoCleanupService(
            systemMetrics: systemMetrics,
            memoryOptimizer: memoryOptimizer,
            processManager: processManager
        )
    }
    
    override func tearDown() {
        service.disable()
        systemMetrics.stopMonitoring()
        processManager.stopAutoUpdate()
        service = nil
        systemMetrics = nil
        memoryOptimizer = nil
        processManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isMonitoring, "Should not be monitoring by default")
    }
    
    // MARK: - Enable/Disable Tests
    
    func testEnable() {
        service.enable()
        XCTAssertTrue(service.isEnabled, "Service should be enabled")
        XCTAssertTrue(service.isMonitoring, "Service should start monitoring")
    }
    
    func testDisable() {
        service.enable()
        service.disable()
        XCTAssertFalse(service.isEnabled, "Service should be disabled")
        XCTAssertFalse(service.isMonitoring, "Service should stop monitoring")
    }
    
    // MARK: - Threshold Tests
    
    func testDefaultThresholds() {
        let thresholds = service.thresholds
        XCTAssertEqual(thresholds.memoryWarning, 75.0, "Default memory warning should be 75%")
        XCTAssertEqual(thresholds.memoryCritical, 85.0, "Default memory critical should be 85%")
        XCTAssertEqual(thresholds.cpuWarning, 80.0, "Default CPU warning should be 80%")
        XCTAssertEqual(thresholds.cpuCritical, 90.0, "Default CPU critical should be 90%")
    }
    
    func testUpdateThresholds() {
        var newThresholds = ResourceThresholds()
        newThresholds.memoryWarning = 60.0
        newThresholds.memoryCritical = 80.0
        
        service.updateThresholds(newThresholds)
        
        XCTAssertEqual(service.thresholds.memoryWarning, 60.0)
        XCTAssertEqual(service.thresholds.memoryCritical, 80.0)
    }
    
    // MARK: - ResourceThresholds Tests
    
    func testResourceThresholdsDefault() {
        let thresholds = ResourceThresholds.default
        XCTAssertEqual(thresholds.memoryWarning, 75.0)
        XCTAssertEqual(thresholds.memoryCritical, 85.0)
        XCTAssertEqual(thresholds.cpuWarning, 80.0)
        XCTAssertEqual(thresholds.cpuCritical, 90.0)
        XCTAssertEqual(thresholds.processMemoryLimit, 2_147_483_648) // 2GB
        XCTAssertEqual(thresholds.processCPULimit, 50.0)
    }
    
    // MARK: - Statistics Tests
    
    func testInitialStatistics() {
        XCTAssertEqual(service.totalCleanups, 0, "Total cleanups should be 0")
        XCTAssertEqual(service.totalMemoryFreed, 0, "Total memory freed should be 0")
        XCTAssertEqual(service.totalProcessesTerminated, 0, "Total processes terminated should be 0")
    }
    
    func testLastCleanupTime() {
        XCTAssertNil(service.lastCleanupTime, "Last cleanup time should be nil initially")
    }
    
    // MARK: - Event History Tests
    
    func testRecentEventsEmpty() {
        XCTAssertTrue(service.recentEvents.isEmpty, "Recent events should be empty initially")
    }
    
    func testClearHistory() {
        service.clearHistory()
        XCTAssertTrue(service.recentEvents.isEmpty, "Events should be empty after clearing")
    }
    
    // MARK: - Status Summary Tests
    
    func testGetStatusSummaryDisabled() {
        service.disable()
        let summary = service.getStatusSummary()
        XCTAssertTrue(summary.contains("disabled"), "Summary should indicate disabled state")
    }
    
    func testGetStatusSummaryEnabled() {
        service.enable()
        let summary = service.getStatusSummary()
        XCTAssertFalse(summary.contains("disabled"), "Summary should not indicate disabled state")
    }
    
    // MARK: - CleanupAction Tests
    
    func testCleanupActionProperties() {
        let actions: [CleanupAction] = [.memoryPurge, .processTermination, .browserTabCleanup, .cacheClearing]
        
        for action in actions {
            XCTAssertFalse(action.rawValue.isEmpty, "Action should have name")
            XCTAssertFalse(action.icon.isEmpty, "Action should have icon")
            XCTAssertFalse(action.id.isEmpty, "Action should have id")
        }
    }
    
    // MARK: - CleanupEvent Tests
    
    func testCleanupEventDescription() {
        let event = CleanupEvent(
            timestamp: Date(),
            action: .memoryPurge,
            reason: "High memory usage",
            memoryFreed: 512 * 1024 * 1024,
            processesTerminated: nil
        )
        
        let description = event.description
        XCTAssertTrue(description.contains("Memory Purge"))
        XCTAssertTrue(description.contains("High memory usage"))
    }
    
    func testCleanupEventWithProcesses() {
        let event = CleanupEvent(
            timestamp: Date(),
            action: .processTermination,
            reason: "CPU overload",
            memoryFreed: nil,
            processesTerminated: 3
        )
        
        let description = event.description
        XCTAssertTrue(description.contains("3 processes"))
    }
    
    // MARK: - Trigger Immediate Cleanup Tests
    
    func testTriggerImmediateCleanup() async {
        // Enable the service first
        service.enable()
        
        // This should not crash
        await service.triggerImmediateCleanup()
    }
}
