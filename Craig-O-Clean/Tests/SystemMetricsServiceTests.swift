// SystemMetricsServiceTests.swift
// ClearMind Control Center Tests
//
// Unit tests for SystemMetricsService

import XCTest
@testable import Craig_O_Clean

final class SystemMetricsServiceTests: XCTestCase {
    
    var sut: SystemMetricsService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        sut = SystemMetricsService()
    }
    
    @MainActor
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Memory Metrics Tests
    
    @MainActor
    func testMemoryMetricsNotNilAfterUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Memory metrics should be populated")
        
        // When
        sut.updateAllMetrics()
        
        // Wait for async update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            XCTAssertNotNil(self.sut.memoryMetrics, "Memory metrics should not be nil after update")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testMemoryMetricsTotalIsGreaterThanZero() async {
        // Given
        let expectation = XCTestExpectation(description: "Total memory should be greater than zero")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.memoryMetrics {
                XCTAssertGreaterThan(metrics.totalMemory, 0, "Total memory should be greater than zero")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testMemoryUsedPercentageIsWithinBounds() async {
        // Given
        let expectation = XCTestExpectation(description: "Memory percentage should be between 0 and 100")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.memoryMetrics {
                XCTAssertGreaterThanOrEqual(metrics.usedPercentage, 0, "Used percentage should be >= 0")
                XCTAssertLessThanOrEqual(metrics.usedPercentage, 100, "Used percentage should be <= 100")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - CPU Metrics Tests
    
    @MainActor
    func testCPUMetricsNotNilAfterUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "CPU metrics should be populated")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            XCTAssertNotNil(self.sut.cpuMetrics, "CPU metrics should not be nil after update")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testCPUCoreCountIsGreaterThanZero() async {
        // Given
        let expectation = XCTestExpectation(description: "CPU core count should be greater than zero")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.cpuMetrics {
                XCTAssertGreaterThan(metrics.coreCount, 0, "Core count should be greater than zero")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testCPUUsageIsWithinBounds() async {
        // Given
        let expectation = XCTestExpectation(description: "CPU usage should be between 0 and 100")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.cpuMetrics {
                XCTAssertGreaterThanOrEqual(metrics.overallUsage, 0, "CPU usage should be >= 0")
                XCTAssertLessThanOrEqual(metrics.overallUsage, 100, "CPU usage should be <= 100")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testPerCoreUsageCountMatchesCoreCount() async {
        // Given
        let expectation = XCTestExpectation(description: "Per core usage array should match core count")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.cpuMetrics {
                XCTAssertEqual(metrics.perCoreUsage.count, metrics.coreCount, 
                              "Per core usage array count should match core count")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Disk Metrics Tests
    
    @MainActor
    func testDiskMetricsNotNilAfterUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Disk metrics should be populated")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            XCTAssertNotNil(self.sut.diskMetrics, "Disk metrics should not be nil after update")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testDiskTotalSpaceIsGreaterThanZero() async {
        // Given
        let expectation = XCTestExpectation(description: "Disk total space should be greater than zero")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.diskMetrics {
                XCTAssertGreaterThan(metrics.totalSpace, 0, "Total space should be greater than zero")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testDiskUsedPlusFreeEqualsTotal() async {
        // Given
        let expectation = XCTestExpectation(description: "Used + Free should approximately equal Total")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            if let metrics = self.sut.diskMetrics {
                let sum = metrics.usedSpace + metrics.freeSpace
                // Allow for some rounding differences
                XCTAssertEqual(sum, metrics.totalSpace, accuracy: 1_000_000_000, 
                              "Used + Free should equal Total (within 1GB tolerance)")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Health Summary Tests
    
    @MainActor
    func testHealthSummaryNotNilAfterUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Health summary should be populated")
        
        // When
        sut.updateAllMetrics()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            XCTAssertNotNil(self.sut.healthSummary, "Health summary should not be nil after update")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - History Tests
    
    @MainActor
    func testCPUHistoryUpdatesOverTime() async {
        // Given
        let initialCount = sut.cpuHistory.count
        let expectation = XCTestExpectation(description: "CPU history should grow over time")
        
        // When
        sut.startAutoUpdate(interval: 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Then
            XCTAssertGreaterThan(self.sut.cpuHistory.count, initialCount, 
                                "CPU history should have more entries after updates")
            self.sut.stopAutoUpdate()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}

// MARK: - Memory Metrics Model Tests

final class MemoryMetricsModelTests: XCTestCase {
    
    func testMemoryPressureNormal() {
        // Given
        let metrics = MemoryMetrics(
            totalMemory: 16_000_000_000,
            usedMemory: 6_000_000_000,  // 37.5% used
            freeMemory: 10_000_000_000,
            activeMemory: 4_000_000_000,
            inactiveMemory: 2_000_000_000,
            wiredMemory: 2_000_000_000,
            compressedMemory: 0,
            swapUsed: 0,
            swapTotal: 0
        )
        
        // Then
        XCTAssertEqual(metrics.memoryPressure, .normal)
    }
    
    func testMemoryPressureModerate() {
        // Given
        let metrics = MemoryMetrics(
            totalMemory: 16_000_000_000,
            usedMemory: 10_000_000_000,  // 62.5% used
            freeMemory: 6_000_000_000,
            activeMemory: 6_000_000_000,
            inactiveMemory: 2_000_000_000,
            wiredMemory: 4_000_000_000,
            compressedMemory: 0,
            swapUsed: 0,
            swapTotal: 0
        )
        
        // Then
        XCTAssertEqual(metrics.memoryPressure, .moderate)
    }
    
    func testMemoryPressureHigh() {
        // Given
        let metrics = MemoryMetrics(
            totalMemory: 16_000_000_000,
            usedMemory: 13_000_000_000,  // 81.25% used
            freeMemory: 3_000_000_000,
            activeMemory: 8_000_000_000,
            inactiveMemory: 1_000_000_000,
            wiredMemory: 5_000_000_000,
            compressedMemory: 0,
            swapUsed: 0,
            swapTotal: 0
        )
        
        // Then
        XCTAssertEqual(metrics.memoryPressure, .high)
    }
    
    func testMemoryPressureCritical() {
        // Given
        let metrics = MemoryMetrics(
            totalMemory: 16_000_000_000,
            usedMemory: 15_000_000_000,  // 93.75% used
            freeMemory: 1_000_000_000,
            activeMemory: 10_000_000_000,
            inactiveMemory: 500_000_000,
            wiredMemory: 5_000_000_000,
            compressedMemory: 0,
            swapUsed: 0,
            swapTotal: 0
        )
        
        // Then
        XCTAssertEqual(metrics.memoryPressure, .critical)
    }
    
    func testFormattedMemoryInGB() {
        // Given
        let metrics = MemoryMetrics(
            totalMemory: 16_000_000_000,
            usedMemory: 8_000_000_000,
            freeMemory: 8_000_000_000,
            activeMemory: 4_000_000_000,
            inactiveMemory: 2_000_000_000,
            wiredMemory: 2_000_000_000,
            compressedMemory: 0,
            swapUsed: 0,
            swapTotal: 0
        )
        
        // Then
        XCTAssertTrue(metrics.totalFormatted.contains("GB"))
    }
}
