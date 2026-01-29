// File: CraigOClean-vNext/CraigOClean/Platforms/Services/Licensing/DirectLicenseService.swift
// Craig-O-Clean - Direct License Service
// License management for DirectPro edition

import Foundation

/// License service for DirectPro edition.
/// Note: This is a stub implementation for the licensing backend.
@MainActor
public final class DirectLicenseService: LicensingService {

    // MARK: - Properties

    private let logger: Logger
    private var currentStatus: LicenseStatus = .trial(daysRemaining: 14)
    private var licenseInfo: LicenseInfo?

    public var isAvailable: Bool { true }
    public var registeredEmail: String? { licenseInfo?.email }

    // MARK: - Initialization

    public init(logger: Logger) {
        self.logger = logger
        logger.debug("DirectLicenseService initialized", category: .licensing)

        // Load saved license
        loadSavedLicense()
    }

    // MARK: - LicensingService Protocol

    public func status() -> LicenseStatus {
        return currentStatus
    }

    public func activate(key: String) async throws -> LicenseStatus {
        logger.info("Attempting license activation", category: .licensing)

        // Validate key format
        guard isValidKeyFormat(key) else {
            throw LicensingError.invalidKey
        }

        // TODO: Implement actual license server validation
        // For now, simulate activation

        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Simulate successful activation
        let info = LicenseInfo(
            key: key,
            email: "user@example.com",
            purchaseDate: Date(),
            expirationDate: nil,
            type: .perpetual
        )

        licenseInfo = info
        currentStatus = .licensed(expiresAt: nil)

        saveLicense(info)
        logger.info("License activated successfully", category: .licensing)

        return currentStatus
    }

    public func deactivate() async throws {
        logger.info("Deactivating license", category: .licensing)

        // TODO: Notify license server

        licenseInfo = nil
        currentStatus = .trial(daysRemaining: 0)
        clearSavedLicense()

        logger.info("License deactivated", category: .licensing)
    }

    public func validate() async throws -> Bool {
        guard let info = licenseInfo else {
            return false
        }

        logger.debug("Validating license", category: .licensing)

        // TODO: Validate with license server

        // Check expiration
        if info.isExpired {
            currentStatus = .expired
            return false
        }

        return true
    }

    // MARK: - Private Methods

    private func isValidKeyFormat(_ key: String) -> Bool {
        // Expected format: XXXX-XXXX-XXXX-XXXX
        let pattern = "^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private func loadSavedLicense() {
        // TODO: Load from secure storage (Keychain)
        if let savedKey = UserDefaults.standard.string(forKey: "licenseKey") {
            logger.debug("Found saved license", category: .licensing)
            currentStatus = .licensed(expiresAt: nil)
        }
    }

    private func saveLicense(_ info: LicenseInfo) {
        // TODO: Save to secure storage (Keychain)
        UserDefaults.standard.set(info.key, forKey: "licenseKey")
    }

    private func clearSavedLicense() {
        UserDefaults.standard.removeObject(forKey: "licenseKey")
    }
}

// MARK: - Trial Management

extension DirectLicenseService {

    /// Returns the trial start date
    public var trialStartDate: Date? {
        UserDefaults.standard.object(forKey: "trialStartDate") as? Date
    }

    /// Returns days remaining in trial
    public var trialDaysRemaining: Int {
        guard let startDate = trialStartDate else {
            // Start trial if not started
            startTrial()
            return 14
        }

        let trialLength = 14
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, trialLength - daysSinceStart)
    }

    /// Starts the trial period
    private func startTrial() {
        UserDefaults.standard.set(Date(), forKey: "trialStartDate")
        logger.info("Trial started", category: .licensing)
    }
}
