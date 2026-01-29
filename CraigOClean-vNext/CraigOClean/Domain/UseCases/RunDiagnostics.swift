// File: CraigOClean-vNext/CraigOClean/Domain/UseCases/RunDiagnostics.swift
// Craig-O-Clean - Run Diagnostics Use Case
// Orchestrates diagnostic collection workflow

import Foundation

/// Use case for running diagnostic collection
@MainActor
public final class RunDiagnostics: ObservableObject {

    private let diagnosticsService: any DiagnosticsService
    private let logger: Logger

    @Published public private(set) var report: DiagnosticReport?
    @Published public private(set) var isCollecting: Bool = false
    @Published public private(set) var isExporting: Bool = false
    @Published public private(set) var error: DiagnosticsError?

    public init(
        diagnosticsService: any DiagnosticsService,
        logger: Logger
    ) {
        self.diagnosticsService = diagnosticsService
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Collects a full diagnostic report
    public func collect() async {
        isCollecting = true
        error = nil

        logger.info("Starting diagnostic collection", category: .diagnostics)

        do {
            report = try await diagnosticsService.collectReport()
            logger.info("Diagnostic collection complete", category: .diagnostics)
        } catch let err as DiagnosticsError {
            error = err
            logger.error("Diagnostic collection failed: \(err.localizedDescription)", category: .diagnostics)
        } catch {
            self.error = .collectionFailed(reason: error.localizedDescription)
            logger.error("Diagnostic collection failed: \(error.localizedDescription)", category: .diagnostics)
        }

        isCollecting = false
    }

    /// Exports the current report to a file
    /// - Parameter url: Destination URL
    public func export(to url: URL) async {
        guard let report = report else {
            error = .exportFailed(reason: "No report to export")
            return
        }

        guard diagnosticsService.canExportReports else {
            error = .notSupportedInEdition(reason: "Report export not available in this edition")
            return
        }

        isExporting = true
        error = nil

        logger.info("Exporting diagnostic report to \(url.path)", category: .diagnostics)

        do {
            try await diagnosticsService.exportReport(report, to: url)
            logger.info("Report exported successfully", category: .diagnostics)
        } catch let err as DiagnosticsError {
            error = err
            logger.error("Report export failed: \(err.localizedDescription)", category: .diagnostics)
        } catch {
            self.error = .exportFailed(reason: error.localizedDescription)
            logger.error("Report export failed: \(error.localizedDescription)", category: .diagnostics)
        }

        isExporting = false
    }

    /// Returns whether export is available
    public var canExport: Bool {
        diagnosticsService.canExportReports
    }

    /// Returns whether full disk inspection is available
    public var canInspectFullDisk: Bool {
        diagnosticsService.canInspectFullDisk
    }

    /// Resets the use case state
    public func reset() {
        report = nil
        error = nil
    }
}
