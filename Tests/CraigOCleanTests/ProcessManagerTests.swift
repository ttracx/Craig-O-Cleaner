// MARK: - ProcessManagerTests.swift
// Craig-O-Clean - Unit Tests for Process Manager
// Tests process listing, termination, and CPU/memory tracking

import XCTest
@testable import Craig_O_Clean

@MainActor
final class ProcessManagerTests: XCTestCase {
    
    var processManager: ProcessManager!
    
    override func setUp() {
        super.setUp()
        processManager = ProcessManager()
    }
    
    override func tearDown() {
        processManager.stopAutoUpdate()
        processManager.stopCPUHistoryTracking()
        processManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testProcessManagerInitialization() {
        XCTAssertNotNil(processManager, "Process manager should initialize")
        XCTAssertFalse(processManager.isLoading, "Should not be loading on init")
    }
    
    // MARK: - Process List Tests
    
    func testUpdateProcessList() {
        processManager.updateProcessList()
        
        // Give it time to fetch processes
        let expectation = self.expectation(description: "Process list updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        // Should have at least some processes
        XCTAssertFalse(processManager.processes.isEmpty, "Should have processes")
    }
    
    func testProcessesContainPID() {
        processManager.updateProcessList()
        
        let expectation = self.expectation(description: "Process list updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        for process in processManager.processes {
            XCTAssertGreaterThan(process.pid, 0, "Process PID should be positive")
        }
    }
    
    // MARK: - ProcessInfo Model Tests
    
    func testProcessInfoModel() {
        let process = ProcessInfo(
            pid: 12345,
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            isUserProcess: true,
            cpuUsage: 25.5,
            memoryUsage: 512 * 1024 * 1024,
            creationTime: Date().addingTimeInterval(-3600),
            parentPID: 1,
            executablePath: "/Applications/TestApp.app/Contents/MacOS/TestApp",
            threads: 8,
            ports: 10,
            arguments: ["--verbose"],
            workingDirectory: "/Users/test",
            uid: 501
        )
        
        XCTAssertEqual(process.pid, 12345)
        XCTAssertEqual(process.name, "TestApp")
        XCTAssertEqual(process.bundleIdentifier, "com.test.app")
        XCTAssertTrue(process.isUserProcess)
    }
    
    func testProcessInfoFormattedMemoryUsage() {
        let process = ProcessInfo(
            pid: 1,
            name: "Test",
            memoryUsage: 1024 * 1024 * 1024 // 1 GB
        )
        
        XCTAssertTrue(process.formattedMemoryUsage.contains("GB"), "Should format as GB")
    }
    
    func testProcessInfoFormattedCPUUsage() {
        let process = ProcessInfo(
            pid: 1,
            name: "Test",
            cpuUsage: 50.5
        )
        
        XCTAssertEqual(process.formattedCPUUsage, "50.5%")
    }
    
    func testProcessInfoAge() {
        let creationTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let process = ProcessInfo(
            pid: 1,
            name: "Test",
            creationTime: creationTime
        )
        
        XCTAssertNotNil(process.age)
        XCTAssertGreaterThan(process.age ?? 0, 3500) // At least 3500 seconds
    }
    
    func testProcessInfoFormattedAge() {
        let creationTime = Date().addingTimeInterval(-3665) // 1h 1m 5s ago
        let process = ProcessInfo(
            pid: 1,
            name: "Test",
            creationTime: creationTime
        )
        
        let formattedAge = process.formattedAge
        XCTAssertTrue(formattedAge.contains("1:01") || formattedAge.contains("1:00"), "Should format as hours:minutes")
    }
    
    func testProcessInfoEquality() {
        let process1 = ProcessInfo(pid: 123, name: "Test1")
        let process2 = ProcessInfo(pid: 123, name: "Test2")
        let process3 = ProcessInfo(pid: 456, name: "Test1")
        
        XCTAssertEqual(process1, process2, "Processes with same PID should be equal")
        XCTAssertNotEqual(process1, process3, "Processes with different PIDs should not be equal")
    }
    
    func testProcessInfoHashable() {
        let process1 = ProcessInfo(pid: 123, name: "Test1")
        let process2 = ProcessInfo(pid: 123, name: "Test2")
        
        var set = Set<ProcessInfo>()
        set.insert(process1)
        set.insert(process2)
        
        XCTAssertEqual(set.count, 1, "Set should contain only one element with same PID")
    }
    
    // MARK: - CPU History Tests
    
    func testGetCPUHistory() {
        let history = processManager.getCPUHistory(for: 1)
        XCTAssertNotNil(history, "CPU history should not be nil")
    }
    
    // MARK: - System Stats Tests
    
    func testTotalCPUUsage() {
        processManager.updateProcessList()
        
        let expectation = self.expectation(description: "Process list updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertGreaterThanOrEqual(processManager.totalCPUUsage, 0, "Total CPU usage should be non-negative")
    }
    
    func testTotalMemoryUsage() {
        processManager.updateProcessList()
        
        let expectation = self.expectation(description: "Process list updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertGreaterThanOrEqual(processManager.totalMemoryUsage, 0, "Total memory usage should be non-negative")
    }
    
    func testSystemLoad() {
        processManager.updateProcessList()
        
        let expectation = self.expectation(description: "Process list updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        let load = processManager.systemLoad
        XCTAssertGreaterThanOrEqual(load.one, 0, "Load average should be non-negative")
    }
    
    // MARK: - Auto Update Tests
    
    func testStartAutoUpdate() {
        processManager.startAutoUpdate()
        // Just verify it doesn't crash
    }
    
    func testStopAutoUpdate() {
        processManager.startAutoUpdate()
        processManager.stopAutoUpdate()
        // Just verify it doesn't crash
    }
    
    // MARK: - Process Details Tests
    
    func testGetProcessDetails() {
        let process = ProcessInfo(pid: 1, name: "launchd")
        let details = processManager.getProcessDetails(for: process)
        
        XCTAssertNotNil(details, "Process details should not be nil")
        XCTAssertEqual(details.process.pid, process.pid)
    }
    
    // MARK: - CPU Core Data Tests
    
    func testCPUCoreData() {
        let coreData = CPUCoreData(id: 0, usage: 50.0)
        XCTAssertEqual(coreData.id, 0)
        XCTAssertEqual(coreData.usage, 50.0)
    }
    
    // MARK: - System CPU Info Tests
    
    func testSystemCPUInfo() {
        processManager.updateProcessList()
        
        let expectation = self.expectation(description: "Process list updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        if let cpuInfo = processManager.systemCPUInfo {
            XCTAssertGreaterThan(cpuInfo.coreCount, 0, "Core count should be positive")
            XCTAssertGreaterThanOrEqual(cpuInfo.totalUsage, 0, "Total usage should be non-negative")
        }
    }
}
