// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Diagnostics/BasicDiagnosticsService.swift
// Craig-O-Clean - Basic Diagnostics Service
// Shared diagnostic collection logic for both editions

import Foundation

/// Base diagnostics service with operations that work in both editions.
@MainActor
public class BasicDiagnosticsService: DiagnosticsService {

    // MARK: - Properties

    internal let logger: Logger
    internal let fileManager: FileManager

    public var canInspectFullDisk: Bool { false }
    public var canExportReports: Bool { false }

    // MARK: - Initialization

    public init(logger: Logger, fileManager: FileManager = .default) {
        self.logger = logger
        self.fileManager = fileManager
    }

    // MARK: - DiagnosticsService Protocol

    public func collectReport() async throws -> DiagnosticReport {
        logger.info("Collecting diagnostic report", category: .diagnostics)

        async let systemInfo = collectSystemInfo()
        async let diskInfo = collectDiskInfo()
        async let cacheInfo = collectCacheInfo()

        let appInfo = collectAppInfo()

        return DiagnosticReport(
            edition: AppEdition.current,
            systemInfo: await systemInfo,
            diskInfo: await diskInfo,
            cacheInfo: await cacheInfo,
            appInfo: appInfo
        )
    }

    public func collectSystemInfo() async -> SystemInfo {
        let processInfo = ProcessInfo.processInfo

        // Get macOS version
        let osVersion = processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        // Get build number
        var buildNumber = "Unknown"
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
            buildNumber = String(cString: buffer)
        }

        // Get hardware model
        var hardwareModel = "Unknown"
        size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &buffer, &size, nil, 0)
            hardwareModel = String(cString: buffer)
        }

        // Get processor info
        var processorInfo = "Unknown"
        size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
            processorInfo = String(cString: buffer)
        }

        // Get physical memory
        let memorySize = processInfo.physicalMemory

        // Get boot time
        var bootTime: Date? = nil
        var bootTimeSpec = timeval()
        size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &bootTimeSpec, &size, nil, 0) == 0 {
            bootTime = Date(timeIntervalSince1970: TimeInterval(bootTimeSpec.tv_sec))
        }

        return SystemInfo(
            macOSVersion: versionString,
            macOSBuild: buildNumber,
            hardwareModel: hardwareModel,
            processorInfo: processorInfo,
            memorySize: memorySize,
            bootTime: bootTime
        )
    }

    public func collectDiskInfo() async -> DiskInfo? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        do {
            let values = try homeURL.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeLocalizedFormatDescriptionKey
            ])

            return DiskInfo(
                volumeName: values.volumeName ?? "Macintosh HD",
                fileSystemType: values.volumeLocalizedFormatDescription ?? "APFS",
                totalCapacity: UInt64(values.volumeTotalCapacity ?? 0),
                availableCapacity: UInt64(values.volumeAvailableCapacity ?? 0),
                mountPoint: "/"
            )
        } catch {
            logger.warning("Failed to get disk info: \(error)", category: .diagnostics)
            return nil
        }
    }

    public func collectCacheInfo() async -> CacheInfo {
        let home = NSHomeDirectory()

        // Calculate user cache size
        let userCacheSize = await calculateDirectorySize("\(home)/Library/Caches")

        // Calculate log size
        let logSize = await calculateDirectorySize("\(home)/Library/Logs")

        // Calculate temp files size
        let tempSize = await calculateDirectorySize(NSTemporaryDirectory())

        return CacheInfo(
            userCacheSize: userCacheSize,
            systemCacheSize: nil,  // Not accessible in base implementation
            logSize: logSize,
            tempFilesSize: tempSize
        )
    }

    public func exportReport(_ report: DiagnosticReport, to url: URL) async throws {
        throw DiagnosticsError.notSupportedInEdition(reason: "Export not available in this edition")
    }

    // MARK: - Internal Helpers

    internal func collectAppInfo() -> AppInfo {
        let env = AppEnvironment.shared
        let provider = CapabilityProviderFactory.current()

        return AppInfo(
            version: env.version,
            build: env.build,
            edition: env.edition,
            capabilities: provider.capabilities
        )
    }

    internal func calculateDirectorySize(_ path: String) async -> UInt64 {
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        while let url = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if !(resourceValues.isDirectory ?? false) {
                    totalSize += UInt64(resourceValues.fileSize ?? 0)
                }
            } catch {
                // Skip inaccessible files
            }
        }

        return totalSize
    }
}
