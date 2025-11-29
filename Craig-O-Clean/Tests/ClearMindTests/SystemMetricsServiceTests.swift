// MARK: - SystemMetricsServiceTests.swift
// CraigOClean Control Center - Unit Tests for SystemMetricsService

import XCTest
@testable import CraigOClean

@MainActor
final class SystemMetricsServiceTests: XCTestCase {
    
    var sut: SystemMetricsService!
    
    override func setUp() async throws {
        sut = SystemMetricsService()
    }
    
    override func tearDown() async throws {
        sut.stopMonitoring()
        sut = nil
    }
    
    // MARK: - CPU Metrics Tests
    
    func testCPUMetricsFetch() async throws {
        await sut.refreshAllMetrics()
        
        let cpuMetrics = sut.cpuMetrics
        XCTAssertNotNil(cpuMetrics, "CPU metrics should not be nil after refresh")
        
        if let cpu = cpuMetrics {
            XCTAssertGreaterThanOrEqual(cpu.totalUsage, 0, "CPU usage should be >= 0")
            XCTAssertLessThanOrEqual(cpu.totalUsage, 100, "CPU usage should be <= 100")
            XCTAssertGreaterThan(cpu.coreCount, 0, "Core count should be > 0")
            XCTAssertEqual(cpu.perCoreUsage.count, cpu.coreCount, "Per-core usage count should match core count")
        }
    }
    
    func testCPULoadAverages() async throws {
        await sut.refreshAllMetrics()
        
        guard let cpu = sut.cpuMetrics else {
            XCTFail("CPU metrics should be available")
            return
        }
        
        // Load averages should be non-negative
        XCTAssertGreaterThanOrEqual(cpu.loadAverage.one, 0, "1-minute load should be >= 0")
        XCTAssertGreaterThanOrEqual(cpu.loadAverage.five, 0, "5-minute load should be >= 0")
        XCTAssertGreaterThanOrEqual(cpu.loadAverage.fifteen, 0, "15-minute load should be >= 0")
    }
    
    // MARK: - Memory Metrics Tests
    
    func testMemoryMetricsFetch() async throws {
        await sut.refreshAllMetrics()
        
        let memoryMetrics = sut.memoryMetrics
        XCTAssertNotNil(memoryMetrics, "Memory metrics should not be nil after refresh")
        
        if let memory = memoryMetrics {
            XCTAssertGreaterThan(memory.totalRAM, 0, "Total RAM should be > 0")
            XCTAssertGreaterThanOrEqual(memory.usedRAM, 0, "Used RAM should be >= 0")
            XCTAssertGreaterThanOrEqual(memory.freeRAM, 0, "Free RAM should be >= 0")
            XCTAssertLessThanOrEqual(memory.usedRAM, memory.totalRAM, "Used RAM should be <= total RAM")
        }
    }
    
    func testMemoryPressureLevel() async throws {
        await sut.refreshAllMetrics()
        
        guard let memory = sut.memoryMetrics else {
            XCTFail("Memory metrics should be available")
            return
        }
        
        // Pressure level should be one of the valid values
        let validLevels: [MemoryPressureLevel] = [.normal, .warning, .critical]
        XCTAssertTrue(validLevels.contains(memory.pressureLevel), "Pressure level should be a valid value")
        
        // Pressure percentage should be in valid range
        XCTAssertGreaterThanOrEqual(memory.pressurePercentage, 0, "Pressure percentage should be >= 0")
        XCTAssertLessThanOrEqual(memory.pressurePercentage, 100, "Pressure percentage should be <= 100")
    }
    
    func testMemoryUsedPercentageCalculation() async throws {
        await sut.refreshAllMetrics()
        
        guard let memory = sut.memoryMetrics else {
            XCTFail("Memory metrics should be available")
            return
        }
        
        let expectedPercentage = Double(memory.usedRAM) / Double(memory.totalRAM) * 100
        XCTAssertEqual(memory.usedPercentage, expectedPercentage, accuracy: 0.01, "Used percentage calculation should be correct")
    }
    
    // MARK: - Disk Metrics Tests
    
    func testDiskMetricsFetch() async throws {
        await sut.refreshAllMetrics()
        
        let diskMetrics = sut.diskMetrics
        XCTAssertNotNil(diskMetrics, "Disk metrics should not be nil after refresh")
        
        if let disk = diskMetrics {
            XCTAssertGreaterThan(disk.totalSpace, 0, "Total space should be > 0")
            XCTAssertGreaterThanOrEqual(disk.freeSpace, 0, "Free space should be >= 0")
            XCTAssertLessThanOrEqual(disk.usedSpace, disk.totalSpace, "Used space should be <= total space")
            XCTAssertEqual(disk.mountPoint, "/", "Mount point should be root")
        }
    }
    
    // MARK: - Network Metrics Tests
    
    func testNetworkMetricsFetch() async throws {
        await sut.refreshAllMetrics()
        
        let networkMetrics = sut.networkMetrics
        XCTAssertNotNil(networkMetrics, "Network metrics should not be nil after refresh")
        
        if let network = networkMetrics {
            XCTAssertGreaterThanOrEqual(network.bytesIn, 0, "Bytes in should be >= 0")
            XCTAssertGreaterThanOrEqual(network.bytesOut, 0, "Bytes out should be >= 0")
            XCTAssertGreaterThanOrEqual(network.bytesInPerSecond, 0, "Download speed should be >= 0")
            XCTAssertGreaterThanOrEqual(network.bytesOutPerSecond, 0, "Upload speed should be >= 0")
        }
    }
    
    // MARK: - Monitoring Tests
    
    func testMonitoringStartStop() async throws {
        XCTAssertFalse(sut.isMonitoring, "Should not be monitoring initially")
        
        sut.startMonitoring()
        XCTAssertTrue(sut.isMonitoring, "Should be monitoring after start")
        
        sut.stopMonitoring()
        XCTAssertFalse(sut.isMonitoring, "Should not be monitoring after stop")
    }
    
    func testRefreshIntervalConfiguration() async throws {
        let newInterval: TimeInterval = 5.0
        sut.refreshInterval = newInterval
        XCTAssertEqual(sut.refreshInterval, newInterval, "Refresh interval should be configurable")
    }
    
    // MARK: - Snapshot Tests
    
    func testGetSnapshot() async throws {
        await sut.refreshAllMetrics()
        
        let snapshot = sut.getSnapshot()
        XCTAssertNotNil(snapshot, "Snapshot should not be nil after refresh")
        
        if let snapshot = snapshot {
            XCTAssertNotNil(snapshot.cpu, "Snapshot should contain CPU metrics")
            XCTAssertNotNil(snapshot.memory, "Snapshot should contain memory metrics")
            XCTAssertNotNil(snapshot.disk, "Snapshot should contain disk metrics")
            XCTAssertNotNil(snapshot.network, "Snapshot should contain network metrics")
            XCTAssertGreaterThanOrEqual(snapshot.uptime, 0, "Uptime should be >= 0")
        }
    }
    
    // MARK: - Formatting Helper Tests
    
    func testFormatBytes() {
        XCTAssertEqual(SystemMetricsService.formatBytes(0), "Zero KB")
        XCTAssertTrue(SystemMetricsService.formatBytes(1024).contains("1"))
        XCTAssertTrue(SystemMetricsService.formatBytes(1024 * 1024).contains("MB") || SystemMetricsService.formatBytes(1024 * 1024).contains("1"))
        XCTAssertTrue(SystemMetricsService.formatBytes(1024 * 1024 * 1024).contains("GB") || SystemMetricsService.formatBytes(1024 * 1024 * 1024).contains("1"))
    }
    
    func testFormatPercentage() {
        XCTAssertEqual(SystemMetricsService.formatPercentage(0), "0.0%")
        XCTAssertEqual(SystemMetricsService.formatPercentage(50.5), "50.5%")
        XCTAssertEqual(SystemMetricsService.formatPercentage(100), "100.0%")
    }
    
    func testFormatUptime() {
        XCTAssertTrue(SystemMetricsService.formatUptime(60).contains("1m") || SystemMetricsService.formatUptime(60).contains("min"))
        XCTAssertTrue(SystemMetricsService.formatUptime(3600).contains("1h") || SystemMetricsService.formatUptime(3600).contains("hour"))
        XCTAssertTrue(SystemMetricsService.formatUptime(86400).contains("1d") || SystemMetricsService.formatUptime(86400).contains("day"))
    }
}
