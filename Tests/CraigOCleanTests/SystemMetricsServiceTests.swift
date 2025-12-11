// MARK: - SystemMetricsServiceTests.swift
// Craig-O-Clean - Unit Tests for System Metrics Service
// Tests system monitoring, memory, CPU, disk, and network metrics

import XCTest
@testable import Craig_O_Clean

@MainActor
final class SystemMetricsServiceTests: XCTestCase {
    
    var service: SystemMetricsService!
    
    override func setUp() {
        super.setUp()
        service = SystemMetricsService()
    }
    
    override func tearDown() {
        service.stopMonitoring()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isMonitoring, "Service should not be monitoring on init")
        XCTAssertNil(service.cpuMetrics, "CPU metrics should be nil before first refresh")
        XCTAssertNil(service.memoryMetrics, "Memory metrics should be nil before first refresh")
    }
    
    // MARK: - Monitoring Tests
    
    func testStartMonitoring() async {
        service.startMonitoring()
        
        // Give it time to fetch initial metrics
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertTrue(service.isMonitoring, "Service should be monitoring after start")
    }
    
    func testStopMonitoring() async {
        service.startMonitoring()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        service.stopMonitoring()
        
        XCTAssertFalse(service.isMonitoring, "Service should stop monitoring")
    }
    
    func testRefreshInterval() {
        let defaultInterval = service.refreshInterval
        XCTAssertEqual(defaultInterval, 2.0, "Default refresh interval should be 2 seconds")
        
        service.refreshInterval = 5.0
        XCTAssertEqual(service.refreshInterval, 5.0, "Refresh interval should be updated")
    }
    
    // MARK: - Metrics Fetch Tests
    
    func testRefreshAllMetrics() async {
        await service.refreshAllMetrics()
        
        XCTAssertNotNil(service.cpuMetrics, "CPU metrics should be populated after refresh")
        XCTAssertNotNil(service.memoryMetrics, "Memory metrics should be populated after refresh")
        XCTAssertNotNil(service.diskMetrics, "Disk metrics should be populated after refresh")
        XCTAssertNotNil(service.networkMetrics, "Network metrics should be populated after refresh")
        XCTAssertNotNil(service.lastUpdateTime, "Last update time should be set")
    }
    
    // MARK: - CPU Metrics Tests
    
    func testCPUMetricsValues() async {
        await service.refreshAllMetrics()
        
        guard let cpu = service.cpuMetrics else {
            XCTFail("CPU metrics should be available")
            return
        }
        
        XCTAssertGreaterThanOrEqual(cpu.totalUsage, 0, "Total CPU usage should be >= 0")
        XCTAssertLessThanOrEqual(cpu.totalUsage, 100, "Total CPU usage should be <= 100")
        XCTAssertGreaterThan(cpu.coreCount, 0, "Core count should be positive")
        XCTAssertEqual(cpu.perCoreUsage.count, cpu.coreCount, "Per-core usage array should match core count")
    }
    
    // MARK: - Memory Metrics Tests
    
    func testMemoryMetricsValues() async {
        await service.refreshAllMetrics()
        
        guard let memory = service.memoryMetrics else {
            XCTFail("Memory metrics should be available")
            return
        }
        
        XCTAssertGreaterThan(memory.totalRAM, 0, "Total RAM should be positive")
        XCTAssertGreaterThanOrEqual(memory.usedPercentage, 0, "Used percentage should be >= 0")
        XCTAssertLessThanOrEqual(memory.usedPercentage, 100, "Used percentage should be <= 100")
        XCTAssertTrue(memory.usedRAM <= memory.totalRAM, "Used RAM should not exceed total RAM")
    }
    
    func testMemoryPressureLevel() async {
        await service.refreshAllMetrics()
        
        guard let memory = service.memoryMetrics else {
            XCTFail("Memory metrics should be available")
            return
        }
        
        let validLevels: [MemoryPressureLevel] = [.normal, .warning, .critical]
        XCTAssertTrue(validLevels.contains(memory.pressureLevel), "Pressure level should be valid")
    }
    
    // MARK: - Disk Metrics Tests
    
    func testDiskMetricsValues() async {
        await service.refreshAllMetrics()
        
        guard let disk = service.diskMetrics else {
            XCTFail("Disk metrics should be available")
            return
        }
        
        XCTAssertGreaterThan(disk.totalSpace, 0, "Total disk space should be positive")
        XCTAssertTrue(disk.usedSpace <= disk.totalSpace, "Used space should not exceed total")
        XCTAssertEqual(disk.mountPoint, "/", "Mount point should be root")
    }
    
    // MARK: - Network Metrics Tests
    
    func testNetworkMetricsValues() async {
        await service.refreshAllMetrics()
        
        guard let network = service.networkMetrics else {
            XCTFail("Network metrics should be available")
            return
        }
        
        XCTAssertGreaterThanOrEqual(network.bytesIn, 0, "Bytes in should be >= 0")
        XCTAssertGreaterThanOrEqual(network.bytesOut, 0, "Bytes out should be >= 0")
    }
    
    // MARK: - Snapshot Tests
    
    func testGetSnapshot() async {
        await service.refreshAllMetrics()
        
        let snapshot = service.getSnapshot()
        XCTAssertNotNil(snapshot, "Snapshot should be available after refresh")
    }
    
    // MARK: - Formatting Helper Tests
    
    func testFormatBytes() {
        XCTAssertEqual(SystemMetricsService.formatBytes(0), "Zero KB")
        XCTAssertTrue(SystemMetricsService.formatBytes(1024).contains("KB"))
        XCTAssertTrue(SystemMetricsService.formatBytes(1024 * 1024).contains("MB"))
        XCTAssertTrue(SystemMetricsService.formatBytes(1024 * 1024 * 1024).contains("GB"))
    }
    
    func testFormatPercentage() {
        XCTAssertEqual(SystemMetricsService.formatPercentage(50.0), "50.0%")
        XCTAssertEqual(SystemMetricsService.formatPercentage(0.0), "0.0%")
        XCTAssertEqual(SystemMetricsService.formatPercentage(100.0), "100.0%")
    }
    
    func testFormatUptime() {
        XCTAssertEqual(SystemMetricsService.formatUptime(60), "1m")
        XCTAssertEqual(SystemMetricsService.formatUptime(3600), "1h 0m")
        XCTAssertEqual(SystemMetricsService.formatUptime(86400), "1d 0h 0m")
    }
}
