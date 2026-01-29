// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Updates/NoopUpdateService.swift
// Craig-O-Clean - No-Op Update Service
// Placeholder update service for App Store edition

import Foundation

/// No-operation update service for App Store edition.
/// Updates are managed by the App Store.
@MainActor
public final class NoopUpdateService: UpdateService {

    // MARK: - Properties

    public var status: UpdateStatus { .unavailable }
    public var isAvailable: Bool { false }
    public var lastCheckDate: Date? { nil }
    public var channel: UpdateChannel {
        get { .stable }
        set { /* ignored */ }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - UpdateService Protocol

    public func checkForUpdates() async throws -> UpdateInfo? {
        throw UpdateError.notAvailable
    }

    public func installUpdate(_ update: UpdateInfo) async throws {
        throw UpdateError.notAvailable
    }
}
