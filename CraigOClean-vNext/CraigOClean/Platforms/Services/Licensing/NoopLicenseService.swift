// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Licensing/NoopLicenseService.swift
// Craig-O-Clean - No-Op License Service
// Placeholder license service for App Store edition

import Foundation

/// No-operation license service for App Store edition.
/// Licensing is managed by the App Store.
@MainActor
public final class NoopLicenseService: LicensingService {

    // MARK: - Properties

    public var isAvailable: Bool { false }
    public var registeredEmail: String? { nil }

    // MARK: - Initialization

    public init() {}

    // MARK: - LicensingService Protocol

    public func status() -> LicenseStatus {
        return .notRequired
    }

    public func activate(key: String) async throws -> LicenseStatus {
        throw LicensingError.notAvailable
    }

    public func deactivate() async throws {
        throw LicensingError.notAvailable
    }

    public func validate() async throws -> Bool {
        return true  // Always valid for App Store purchases
    }
}
