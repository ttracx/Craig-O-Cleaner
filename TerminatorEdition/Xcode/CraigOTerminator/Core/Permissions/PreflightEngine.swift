//
//  PreflightEngine.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import AppKit
import os.log

// MARK: - Preflight Result

/// Result of preflight validation
struct PreflightResult {
    let canExecute: Bool
    let failedChecks: [FailedCheck]
    let missingPermissions: [PermissionType]

    struct FailedCheck {
        let check: PreflightCheck
        let reason: String
    }

    /// Is execution safe to proceed?
    var isValid: Bool {
        canExecute && failedChecks.isEmpty && missingPermissions.isEmpty
    }

    /// Human-readable summary of issues
    var summary: String {
        var lines: [String] = []

        if !failedChecks.isEmpty {
            lines.append("Failed checks:")
            for failed in failedChecks {
                lines.append("  - \(failed.check.type.rawValue): \(failed.reason)")
            }
        }

        if !missingPermissions.isEmpty {
            lines.append("Missing permissions:")
            for permission in missingPermissions {
                lines.append("  - \(permission.displayName)")
            }
        }

        return lines.isEmpty ? "All checks passed" : lines.joined(separator: "\n")
    }
}

// MARK: - Preflight Engine

/// Validates capability preconditions before execution
final class PreflightEngine {

    private let permissionCenter: PermissionCenter
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "PreflightEngine")

    // MARK: - Initialization

    init(permissionCenter: PermissionCenter = .shared) {
        self.permissionCenter = permissionCenter
    }

    // MARK: - Validation

    /// Run all preflight checks for capability
    func validate(_ capability: Capability) async -> PreflightResult {
        logger.info("Running preflight checks for capability: \(capability.id)")

        var failedChecks: [PreflightResult.FailedCheck] = []
        var missingPermissions: [PermissionType] = []

        // Check each preflight check
        for check in capability.preflightChecks {
            if let failure = await validate(check) {
                failedChecks.append(failure)
            }
        }

        // Check privilege level permissions
        let permissionCheck = await checkPrivilegeLevelPermissions(capability)
        missingPermissions.append(contentsOf: permissionCheck)

        let canExecute = failedChecks.isEmpty && missingPermissions.isEmpty

        let result = PreflightResult(
            canExecute: canExecute,
            failedChecks: failedChecks,
            missingPermissions: missingPermissions
        )

        if canExecute {
            logger.info("Preflight validation passed for \(capability.id)")
        } else {
            logger.warning("Preflight validation failed for \(capability.id): \(result.summary)")
        }

        return result
    }

    // MARK: - Check Validation

    private func validate(_ check: PreflightCheck) async -> PreflightResult.FailedCheck? {
        logger.debug("Validating preflight check: \(check.type.rawValue) for target '\(check.target)'")

        switch check.type {
        case .pathExists:
            return validatePathExists(check)

        case .pathWritable:
            return validatePathWritable(check)

        case .appRunning:
            return validateAppRunning(check)

        case .appNotRunning:
            return validateAppNotRunning(check)

        case .diskSpaceAvailable:
            return validateDiskSpace(check)

        case .sipStatus:
            return validateSIPStatus(check)

        case .automationPermission:
            return await validateAutomationPermission(check)
        }
    }

    private func validatePathExists(_ check: PreflightCheck) -> PreflightResult.FailedCheck? {
        let path = NSString(string: check.target).expandingTildeInPath
        let exists = FileManager.default.fileExists(atPath: path)

        if !exists {
            logger.warning("Path does not exist: \(path)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: check.failureMessage
            )
        }

        logger.debug("Path exists: \(path)")
        return nil
    }

    private func validatePathWritable(_ check: PreflightCheck) -> PreflightResult.FailedCheck? {
        let path = NSString(string: check.target).expandingTildeInPath

        // Check if path exists first
        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("Path does not exist (cannot check writable): \(path)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: "Path does not exist: \(path)"
            )
        }

        let writable = FileManager.default.isWritableFile(atPath: path)

        if !writable {
            logger.warning("Path is not writable: \(path)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: check.failureMessage
            )
        }

        logger.debug("Path is writable: \(path)")
        return nil
    }

    private func validateAppRunning(_ check: PreflightCheck) -> PreflightResult.FailedCheck? {
        let running = isAppRunning(check.target)

        if !running {
            logger.warning("App is not running: \(check.target)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: check.failureMessage
            )
        }

        logger.debug("App is running: \(check.target)")
        return nil
    }

    private func validateAppNotRunning(_ check: PreflightCheck) -> PreflightResult.FailedCheck? {
        let running = isAppRunning(check.target)

        if running {
            logger.warning("App is running (should not be): \(check.target)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: check.failureMessage
            )
        }

        logger.debug("App is not running (as expected): \(check.target)")
        return nil
    }

    private func validateDiskSpace(_ check: PreflightCheck) -> PreflightResult.FailedCheck? {
        // Parse target as byte count (e.g., "1GB", "500MB")
        guard let requiredBytes = parseByteCount(check.target) else {
            logger.error("Invalid disk space requirement format: \(check.target)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: "Invalid disk space format: \(check.target)"
            )
        }

        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {

            let availableGB = Double(available) / 1_000_000_000
            let requiredGB = Double(requiredBytes) / 1_000_000_000

            if available < requiredBytes {
                logger.warning("Insufficient disk space: available=\(availableGB)GB, required=\(requiredGB)GB")
                return PreflightResult.FailedCheck(
                    check: check,
                    reason: check.failureMessage
                )
            }

            logger.debug("Sufficient disk space: available=\(availableGB)GB, required=\(requiredGB)GB")
        } else {
            logger.error("Could not determine available disk space")
            return PreflightResult.FailedCheck(
                check: check,
                reason: "Could not determine available disk space"
            )
        }

        return nil
    }

    private func validateSIPStatus(_ check: PreflightCheck) -> PreflightResult.FailedCheck? {
        // Check if SIP is enabled (we never want to recommend disabling it)
        // This is informational only - we don't fail if SIP is enabled
        // The check.target could specify "enabled" or "disabled" as expected state

        let sipEnabled = checkSIPStatus()

        let expectedEnabled = check.target.lowercased() == "enabled"

        if sipEnabled != expectedEnabled {
            logger.warning("SIP status mismatch: expected=\(expectedEnabled), actual=\(sipEnabled)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: check.failureMessage
            )
        }

        logger.debug("SIP status check passed: \(sipEnabled ? "enabled" : "disabled")")
        return nil
    }

    private func validateAutomationPermission(_ check: PreflightCheck) async -> PreflightResult.FailedCheck? {
        // Check target is a browser name
        guard let browser = BrowserApp.allCases.first(where: { $0.rawValue == check.target }) else {
            logger.warning("Unknown browser for automation check: \(check.target)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: "Unknown browser: \(check.target)"
            )
        }

        let state = await AutomationChecker.checkPermission(for: browser)

        if state != .granted {
            logger.warning("Automation permission not granted for \(browser.rawValue): \(state.rawValue)")
            return PreflightResult.FailedCheck(
                check: check,
                reason: check.failureMessage
            )
        }

        logger.debug("Automation permission granted for \(browser.rawValue)")
        return nil
    }

    // MARK: - Permission Level Checks

    private func checkPrivilegeLevelPermissions(_ capability: Capability) async -> [PermissionType] {
        var missing: [PermissionType] = []

        switch capability.privilegeLevel {
        case .automation:
            // Detect required browser from capability
            if let browser = detectRequiredBrowser(capability) {
                let state = permissionCenter.automationPermissions[browser] ?? .unknown

                if state != .granted {
                    logger.warning("Missing automation permission for \(browser.rawValue)")
                    missing.append(.automation(browser))
                }
            }

        case .elevated:
            if !permissionCenter.helperInstalled {
                logger.warning("Privileged helper not installed")
                missing.append(.helper)
            }

        case .fullDiskAccess:
            if permissionCenter.fullDiskAccess != .granted {
                logger.warning("Full disk access not granted")
                missing.append(.fullDiskAccess)
            }

        case .user:
            // No special permissions needed
            break
        }

        return missing
    }

    // MARK: - Helpers

    private func isAppRunning(_ identifier: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == identifier ||
            app.localizedName == identifier ||
            app.bundleIdentifier?.contains(identifier) == true
        }
    }

    private func detectRequiredBrowser(_ capability: Capability) -> BrowserApp? {
        // Detect browser from required apps
        for appName in capability.requiredApps {
            if let browser = BrowserApp.allCases.first(where: { $0.rawValue == appName }) {
                return browser
            }
        }

        // Try to infer from capability ID or description
        let searchText = (capability.id + capability.description).lowercased()

        for browser in BrowserApp.allCases {
            let browserName = browser.rawValue.lowercased()
            if searchText.contains(browserName) {
                return browser
            }
        }

        return nil
    }

    private func parseByteCount(_ string: String) -> Int64? {
        // Parse "1GB", "500MB", "1.5GB", etc.
        let upperString = string.uppercased().trimmingCharacters(in: .whitespaces)

        let scanner = Scanner(string: upperString)
        guard let value = scanner.scanDouble() else { return nil }

        let remaining = String(upperString[scanner.currentIndex...])

        let multiplier: Int64
        if remaining.hasPrefix("GB") {
            multiplier = 1_000_000_000
        } else if remaining.hasPrefix("MB") {
            multiplier = 1_000_000
        } else if remaining.hasPrefix("KB") {
            multiplier = 1_000
        } else if remaining.hasPrefix("B") || remaining.isEmpty {
            multiplier = 1
        } else {
            return nil
        }

        return Int64(value * Double(multiplier))
    }

    private func checkSIPStatus() -> Bool {
        // Execute csrutil status and parse output
        let task = Process()
        task.launchPath = "/usr/bin/csrutil"
        task.arguments = ["status"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Output is either "System Integrity Protection status: enabled." or "...disabled."
                return output.lowercased().contains("enabled")
            }
        } catch {
            logger.error("Failed to check SIP status: \(error.localizedDescription)")
        }

        // Default to assuming enabled (safer assumption)
        return true
    }
}
