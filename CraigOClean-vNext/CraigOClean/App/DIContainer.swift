// File: CraigOClean-vNext/CraigOClean/App/DIContainer.swift
// Craig-O-Clean - Dependency Injection Container
// Manages service instantiation based on edition

import Foundation
import SwiftUI

/// Dependency injection container that provides the correct service implementations
/// based on the current app edition (DirectPro vs AppStoreLite)
@MainActor
public final class DIContainer: ObservableObject {

    // MARK: - Singleton

    public static let shared = DIContainer()

    // MARK: - Environment

    public let environment: AppEnvironment

    // MARK: - Services

    public let logger: Logger
    public let logStore: LogStore
    public let cleanerService: any CleanerService
    public let diagnosticsService: any DiagnosticsService
    public let permissionService: any PermissionService
    public let updateService: any UpdateService
    public let licensingService: any LicensingService

    // MARK: - Use Cases

    public lazy var runCleanup: RunCleanup = {
        RunCleanup(
            cleanerService: cleanerService,
            permissionService: permissionService,
            logger: logger
        )
    }()

    public lazy var runDiagnostics: RunDiagnostics = {
        RunDiagnostics(
            diagnosticsService: diagnosticsService,
            logger: logger
        )
    }()

    // MARK: - Initialization

    private init() {
        self.environment = AppEnvironment.shared

        // Initialize logging first (needed by other services)
        self.logStore = LogStore(maxEntries: 1000)
        self.logger = Logger(store: logStore, logFileURL: environment.logsDirectory.appendingPathComponent("app.log"))

        // Log startup
        logger.info("Craig-O-Clean starting - Edition: \(environment.edition.displayName)", category: .app)
        logger.info("Version: \(environment.fullVersionString)", category: .app)

        // Initialize services based on edition
        #if APPSTORE_LITE
        logger.debug("Initializing App Store Lite services", category: .app)
        self.cleanerService = AppStoreCleanerService(logger: logger)
        self.diagnosticsService = AppStoreDiagnosticsService(logger: logger)
        self.permissionService = PermissionsService(
            capabilities: AppStoreLiteCapabilities.shared.capabilities,
            logger: logger
        )
        self.updateService = NoopUpdateService()
        self.licensingService = NoopLicenseService()
        #elseif DIRECT_PRO
        logger.debug("Initializing DirectPro services", category: .app)
        self.cleanerService = DirectProCleanerService(logger: logger)
        self.diagnosticsService = DirectProDiagnosticsService(logger: logger)
        self.permissionService = PermissionsService(
            capabilities: DirectProCapabilities.shared.capabilities,
            logger: logger
        )
        self.updateService = SparkleUpdateService(logger: logger)
        self.licensingService = DirectLicenseService(logger: logger)
        #else
        // Default to Lite for safety
        logger.debug("Initializing default (Lite) services", category: .app)
        self.cleanerService = AppStoreCleanerService(logger: logger)
        self.diagnosticsService = AppStoreDiagnosticsService(logger: logger)
        self.permissionService = PermissionsService(
            capabilities: AppStoreLiteCapabilities.shared.capabilities,
            logger: logger
        )
        self.updateService = NoopUpdateService()
        self.licensingService = NoopLicenseService()
        #endif

        logger.info("Service initialization complete", category: .app)
    }

    // MARK: - Factory Methods

    /// Creates a new RunCleanup use case (for testing or isolated use)
    public func makeRunCleanup() -> RunCleanup {
        RunCleanup(
            cleanerService: cleanerService,
            permissionService: permissionService,
            logger: logger
        )
    }

    /// Creates a new RunDiagnostics use case (for testing or isolated use)
    public func makeRunDiagnostics() -> RunDiagnostics {
        RunDiagnostics(
            diagnosticsService: diagnosticsService,
            logger: logger
        )
    }
}

// MARK: - Environment Key

private struct DIContainerKey: EnvironmentKey {
    @MainActor static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    public var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    public func withDIContainer(_ container: DIContainer = DIContainer.shared) -> some View {
        self.environment(\.diContainer, container)
            .environmentObject(container)
    }
}

// MARK: - Preview Support

#if DEBUG
extension DIContainer {
    /// Creates a container for SwiftUI previews
    @MainActor
    public static var preview: DIContainer {
        shared
    }
}
#endif
