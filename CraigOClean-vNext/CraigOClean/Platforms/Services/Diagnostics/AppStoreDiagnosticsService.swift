// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Diagnostics/AppStoreDiagnosticsService.swift
// Craig-O-Clean - App Store Diagnostics Service
// Sandboxed diagnostics for App Store Lite edition

import Foundation

/// Diagnostics service for App Store Lite edition with sandbox restrictions.
@MainActor
public final class AppStoreDiagnosticsService: BasicDiagnosticsService {

    // MARK: - Properties

    private let capabilities = AppStoreLiteCapabilities.shared

    public override var canInspectFullDisk: Bool { false }
    public override var canExportReports: Bool { false }

    // MARK: - Initialization

    public override init(logger: Logger, fileManager: FileManager = .default) {
        super.init(logger: logger, fileManager: fileManager)
        logger.debug("AppStoreDiagnosticsService initialized (sandbox mode)", category: .diagnostics)
    }

    // MARK: - Override to Enforce Sandbox

    public override func collectReport() async throws -> DiagnosticReport {
        logger.info("Collecting diagnostic report (sandbox mode)", category: .diagnostics)

        // Collect what we can within sandbox
        async let systemInfo = collectSystemInfo()
        async let diskInfo = collectDiskInfo()
        async let cacheInfo = collectCacheInfo()

        let appInfo = collectAppInfo()

        return DiagnosticReport(
            edition: .appStoreLite,
            systemInfo: await systemInfo,
            diskInfo: await diskInfo,
            cacheInfo: await cacheInfo,
            appInfo: appInfo
        )
    }

    public override func collectCacheInfo() async -> CacheInfo {
        let home = NSHomeDirectory()

        // Only collect user-level cache info
        let userCacheSize = await calculateDirectorySize("\(home)/Library/Caches")
        let logSize = await calculateDirectorySize("\(home)/Library/Logs")
        let tempSize = await calculateDirectorySize(NSTemporaryDirectory())

        return CacheInfo(
            userCacheSize: userCacheSize,
            systemCacheSize: nil,  // Not accessible in sandbox
            logSize: logSize,
            tempFilesSize: tempSize
        )
    }

    public override func exportReport(_ report: DiagnosticReport, to url: URL) async throws {
        logger.warning("Report export not available in App Store edition", category: .diagnostics)
        throw DiagnosticsError.notSupportedInEdition(
            reason: capabilities.unavailabilityReason(for: "exportDiagnostics")
        )
    }

    // MARK: - Sandbox-Specific Methods

    /// Returns explanation for limited diagnostics
    public var limitationsExplanation: String {
        """
        The App Store edition provides basic diagnostics within the app sandbox.

        For comprehensive system analysis including:
        - Full disk usage breakdown
        - System-wide cache analysis
        - Exportable diagnostic reports

        Consider Craig-O-Clean Pro from our website.
        """
    }

    /// Returns list of features not available in sandbox
    public var unavailableFeatures: [String] {
        [
            "System-wide cache analysis",
            "Full disk usage inspection",
            "Export diagnostic reports",
            "Process memory usage",
            "Application resource usage"
        ]
    }
}
