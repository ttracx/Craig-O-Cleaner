// File: CraigOClean-vNext/CraigOClean/Domain/Models/DiagnosticReport.swift
// Craig-O-Clean - Diagnostic Report Model
// Represents system diagnostic information

import Foundation

/// Comprehensive diagnostic report for the system
public struct DiagnosticReport: Sendable {
    public let id: UUID
    public let generatedAt: Date
    public let edition: AppEdition
    public let systemInfo: SystemInfo
    public let diskInfo: DiskInfo?
    public let cacheInfo: CacheInfo
    public let appInfo: AppInfo

    public init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        edition: AppEdition,
        systemInfo: SystemInfo,
        diskInfo: DiskInfo?,
        cacheInfo: CacheInfo,
        appInfo: AppInfo
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.edition = edition
        self.systemInfo = systemInfo
        self.diskInfo = diskInfo
        self.cacheInfo = cacheInfo
        self.appInfo = appInfo
    }
}

// MARK: - System Info

public struct SystemInfo: Sendable {
    public let macOSVersion: String
    public let macOSBuild: String
    public let hardwareModel: String
    public let processorInfo: String
    public let memorySize: UInt64
    public let bootTime: Date?

    public init(
        macOSVersion: String,
        macOSBuild: String,
        hardwareModel: String,
        processorInfo: String,
        memorySize: UInt64,
        bootTime: Date?
    ) {
        self.macOSVersion = macOSVersion
        self.macOSBuild = macOSBuild
        self.hardwareModel = hardwareModel
        self.processorInfo = processorInfo
        self.memorySize = memorySize
        self.bootTime = bootTime
    }

    public var formattedMemorySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(memorySize), countStyle: .memory)
    }

    public var uptimeString: String? {
        guard let bootTime = bootTime else { return nil }
        let interval = Date().timeIntervalSince(bootTime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval)
    }
}

// MARK: - Disk Info

public struct DiskInfo: Sendable {
    public let volumeName: String
    public let fileSystemType: String
    public let totalCapacity: UInt64
    public let availableCapacity: UInt64
    public let usedCapacity: UInt64
    public let mountPoint: String

    public init(
        volumeName: String,
        fileSystemType: String,
        totalCapacity: UInt64,
        availableCapacity: UInt64,
        mountPoint: String
    ) {
        self.volumeName = volumeName
        self.fileSystemType = fileSystemType
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.usedCapacity = totalCapacity - availableCapacity
        self.mountPoint = mountPoint
    }

    public var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity) * 100
    }

    public var formattedTotalCapacity: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalCapacity), countStyle: .file)
    }

    public var formattedAvailableCapacity: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableCapacity), countStyle: .file)
    }

    public var formattedUsedCapacity: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedCapacity), countStyle: .file)
    }
}

// MARK: - Cache Info

public struct CacheInfo: Sendable {
    public let userCacheSize: UInt64
    public let systemCacheSize: UInt64?  // nil if not accessible
    public let logSize: UInt64
    public let tempFilesSize: UInt64

    public init(
        userCacheSize: UInt64,
        systemCacheSize: UInt64?,
        logSize: UInt64,
        tempFilesSize: UInt64
    ) {
        self.userCacheSize = userCacheSize
        self.systemCacheSize = systemCacheSize
        self.logSize = logSize
        self.tempFilesSize = tempFilesSize
    }

    public var totalCleanableSize: UInt64 {
        userCacheSize + (systemCacheSize ?? 0) + logSize + tempFilesSize
    }

    public var formattedUserCacheSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(userCacheSize), countStyle: .file)
    }

    public var formattedSystemCacheSize: String? {
        guard let size = systemCacheSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    public var formattedLogSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(logSize), countStyle: .file)
    }

    public var formattedTotalCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalCleanableSize), countStyle: .file)
    }
}

// MARK: - App Info

public struct AppInfo: Sendable {
    public let version: String
    public let build: String
    public let edition: AppEdition
    public let capabilities: Capabilities

    public init(
        version: String,
        build: String,
        edition: AppEdition,
        capabilities: Capabilities
    ) {
        self.version = version
        self.build = build
        self.edition = edition
        self.capabilities = capabilities
    }

    public var fullVersionString: String {
        "\(version) (\(build))"
    }
}

// MARK: - Report Export

extension DiagnosticReport {

    /// Exports the report as a formatted string
    public func exportAsText() -> String {
        var lines: [String] = []

        lines.append("Craig-O-Clean Diagnostic Report")
        lines.append("================================")
        lines.append("Generated: \(generatedAt.formatted())")
        lines.append("Edition: \(edition.displayName)")
        lines.append("")

        lines.append("System Information")
        lines.append("------------------")
        lines.append("macOS: \(systemInfo.macOSVersion) (\(systemInfo.macOSBuild))")
        lines.append("Hardware: \(systemInfo.hardwareModel)")
        lines.append("Processor: \(systemInfo.processorInfo)")
        lines.append("Memory: \(systemInfo.formattedMemorySize)")
        if let uptime = systemInfo.uptimeString {
            lines.append("Uptime: \(uptime)")
        }
        lines.append("")

        if let diskInfo = diskInfo {
            lines.append("Disk Information")
            lines.append("----------------")
            lines.append("Volume: \(diskInfo.volumeName)")
            lines.append("File System: \(diskInfo.fileSystemType)")
            lines.append("Total: \(diskInfo.formattedTotalCapacity)")
            lines.append("Used: \(diskInfo.formattedUsedCapacity) (\(String(format: "%.1f", diskInfo.usedPercentage))%)")
            lines.append("Available: \(diskInfo.formattedAvailableCapacity)")
            lines.append("")
        }

        lines.append("Cache Information")
        lines.append("-----------------")
        lines.append("User Caches: \(cacheInfo.formattedUserCacheSize)")
        if let systemCache = cacheInfo.formattedSystemCacheSize {
            lines.append("System Caches: \(systemCache)")
        }
        lines.append("Logs: \(cacheInfo.formattedLogSize)")
        lines.append("Total Cleanable: \(cacheInfo.formattedTotalCleanableSize)")
        lines.append("")

        lines.append("Application")
        lines.append("-----------")
        lines.append("Version: \(appInfo.fullVersionString)")
        lines.append("Edition: \(appInfo.edition.displayName)")

        return lines.joined(separator: "\n")
    }
}
