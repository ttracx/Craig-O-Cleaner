// File: CraigOClean-vNext/CraigOClean/Domain/Protocols/UpdateService.swift
// Craig-O-Clean - Update Service Protocol
// Protocol defining auto-update operations (DirectPro only)

import Foundation

/// Protocol for update service implementations
@MainActor
public protocol UpdateService: Sendable {

    /// Checks for available updates
    /// - Returns: Update information if available
    func checkForUpdates() async throws -> UpdateInfo?

    /// Downloads and installs an available update
    /// - Parameter update: The update to install
    func installUpdate(_ update: UpdateInfo) async throws

    /// Returns the current update check status
    var status: UpdateStatus { get }

    /// Returns true if auto-updates are available in this edition
    var isAvailable: Bool { get }

    /// Returns the last time updates were checked
    var lastCheckDate: Date? { get }

    /// The update channel (stable, beta, etc.)
    var channel: UpdateChannel { get set }
}

// MARK: - Update Info

public struct UpdateInfo: Sendable {
    public let version: String
    public let build: String
    public let releaseNotes: String
    public let downloadURL: URL
    public let releaseDate: Date
    public let isCritical: Bool

    public init(
        version: String,
        build: String,
        releaseNotes: String,
        downloadURL: URL,
        releaseDate: Date,
        isCritical: Bool = false
    ) {
        self.version = version
        self.build = build
        self.releaseNotes = releaseNotes
        self.downloadURL = downloadURL
        self.releaseDate = releaseDate
        self.isCritical = isCritical
    }
}

// MARK: - Update Status

public enum UpdateStatus: Sendable {
    case idle
    case checking
    case available(UpdateInfo)
    case downloading(progress: Double)
    case installing
    case upToDate
    case error(String)
    case unavailable  // For App Store edition

    public var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .checking: return "Checking..."
        case .available(let info): return "Update available: v\(info.version)"
        case .downloading(let progress): return "Downloading... \(Int(progress * 100))%"
        case .installing: return "Installing..."
        case .upToDate: return "Up to date"
        case .error(let message): return "Error: \(message)"
        case .unavailable: return "Updates via App Store"
        }
    }
}

// MARK: - Update Channel

public enum UpdateChannel: String, CaseIterable, Sendable {
    case stable = "stable"
    case beta = "beta"

    public var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        }
    }

    public var description: String {
        switch self {
        case .stable: return "Receive stable, tested releases"
        case .beta: return "Receive beta releases with new features"
        }
    }
}

// MARK: - Update Errors

public enum UpdateError: Error, LocalizedError, Sendable {
    case notAvailable
    case checkFailed(reason: String)
    case downloadFailed(reason: String)
    case installFailed(reason: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Updates are managed by the App Store"
        case .checkFailed(let reason):
            return "Failed to check for updates: \(reason)"
        case .downloadFailed(let reason):
            return "Failed to download update: \(reason)"
        case .installFailed(let reason):
            return "Failed to install update: \(reason)"
        case .cancelled:
            return "Update was cancelled"
        }
    }
}
