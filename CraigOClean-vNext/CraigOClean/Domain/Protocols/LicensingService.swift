// File: CraigOClean-vNext/CraigOClean/Domain/Protocols/LicensingService.swift
// Craig-O-Clean - Licensing Service Protocol
// Protocol defining license activation and validation (DirectPro only)

import Foundation

/// Protocol for licensing service implementations
@MainActor
public protocol LicensingService: Sendable {

    /// Returns the current license status
    func status() -> LicenseStatus

    /// Activates a license with the provided key
    /// - Parameter key: The license key to activate
    /// - Returns: The resulting license status
    func activate(key: String) async throws -> LicenseStatus

    /// Deactivates the current license
    func deactivate() async throws

    /// Validates the current license with the server
    /// - Returns: True if license is valid
    func validate() async throws -> Bool

    /// Returns true if licensing is available in this edition
    var isAvailable: Bool { get }

    /// Returns the registered email if licensed
    var registeredEmail: String? { get }
}

// MARK: - License Status

public enum LicenseStatus: Sendable, Equatable {
    case licensed(expiresAt: Date?)
    case trial(daysRemaining: Int)
    case expired
    case invalid
    case notRequired  // For App Store edition

    public var isActive: Bool {
        switch self {
        case .licensed, .trial:
            return true
        case .notRequired:
            return true
        case .expired, .invalid:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .licensed(let expires):
            if let expires = expires {
                return "Licensed (expires \(expires.formatted(date: .abbreviated, time: .omitted)))"
            }
            return "Licensed (perpetual)"
        case .trial(let days):
            return "Trial (\(days) days remaining)"
        case .expired:
            return "License Expired"
        case .invalid:
            return "Invalid License"
        case .notRequired:
            return "App Store Purchase"
        }
    }
}

// MARK: - License Info

public struct LicenseInfo: Sendable {
    public let key: String
    public let email: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let type: LicenseType

    public init(
        key: String,
        email: String,
        purchaseDate: Date,
        expirationDate: Date? = nil,
        type: LicenseType
    ) {
        self.key = key
        self.email = email
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.type = type
    }

    public var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return expiration < Date()
    }
}

// MARK: - License Type

public enum LicenseType: String, Sendable {
    case personal = "personal"
    case family = "family"
    case business = "business"
    case perpetual = "perpetual"

    public var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .family: return "Family"
        case .business: return "Business"
        case .perpetual: return "Perpetual"
        }
    }
}

// MARK: - Licensing Errors

public enum LicensingError: Error, LocalizedError, Sendable {
    case notAvailable
    case invalidKey
    case keyAlreadyUsed
    case activationFailed(reason: String)
    case deactivationFailed(reason: String)
    case validationFailed(reason: String)
    case networkError(reason: String)
    case serverError(reason: String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Licensing is managed by the App Store"
        case .invalidKey:
            return "The license key is invalid"
        case .keyAlreadyUsed:
            return "This license key has already been used on another device"
        case .activationFailed(let reason):
            return "Activation failed: \(reason)"
        case .deactivationFailed(let reason):
            return "Deactivation failed: \(reason)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .serverError(let reason):
            return "Server error: \(reason)"
        }
    }
}
