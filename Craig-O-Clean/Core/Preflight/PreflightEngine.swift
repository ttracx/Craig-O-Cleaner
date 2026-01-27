// MARK: - PreflightEngine.swift
// Craig-O-Clean - Preflight Check Engine
// Validates permissions, paths, and system state before capability execution

import Foundation
import AppKit
import os.log

// MARK: - Preflight Result

struct PreflightResult {
    let passed: Bool
    let failureMessages: [String]
    let remediationHint: String?
    let checkedPermissions: [RequiredPermission: Bool]

    static let success = PreflightResult(passed: true, failureMessages: [], remediationHint: nil, checkedPermissions: [:])
}

// MARK: - Preflight Engine

@MainActor
final class PreflightEngine: ObservableObject {

    private let logger = Logger(subsystem: "com.CraigOClean.app", category: "PreflightEngine")

    /// Run all preflight checks for a capability
    func runChecks(for capability: Capability) async -> PreflightResult {
        var failures: [String] = []
        var remediation: String?
        var permissionResults: [RequiredPermission: Bool] = [:]

        // 1. Check required permissions
        for permission in capability.requiredPermissions {
            if permission == .none { continue }

            let granted = await checkPermission(permission)
            permissionResults[permission] = granted

            if !granted {
                if let browserName = permission.automationBrowserName {
                    failures.append("Automation permission required for \(browserName)")
                    remediation = "Open System Settings > Privacy & Security > Automation and enable Craig-O-Clean for \(browserName)."
                } else if permission == .fullDiskAccessOptional {
                    // Optional — warn but don't block
                    logger.info("Full Disk Access not granted (optional)")
                } else if permission == .accessibilityOptional {
                    logger.info("Accessibility not granted (optional)")
                }
            }
        }

        // 2. Check required privileges
        if capability.requiredPrivileges == .elevated {
            // We don't fail here — the executor handles auth flow
            // But we note it for the UI
            logger.info("Capability \(capability.id) requires elevated privileges")
        }

        // 3. Run preflight checks defined in the capability
        for check in capability.preflightChecks {
            let checkResult = await runSingleCheck(check)
            if !checkResult.passed {
                failures.append(checkResult.message)
            }
        }

        if failures.isEmpty {
            return .success
        }

        return PreflightResult(
            passed: false,
            failureMessages: failures,
            remediationHint: remediation,
            checkedPermissions: permissionResults
        )
    }

    // MARK: - Individual Check Types

    private struct SingleCheckResult {
        let passed: Bool
        let message: String
    }

    private func runSingleCheck(_ check: PreflightCheck) async -> SingleCheckResult {
        switch check.type {
        case .pathExists:
            let expandedPath = check.value.replacingOccurrences(of: "~", with: NSHomeDirectory())
            let exists = FileManager.default.fileExists(atPath: expandedPath)
            return SingleCheckResult(
                passed: exists,
                message: check.message ?? "Path not found: \(check.value)"
            )

        case .appRunning:
            let running = NSWorkspace.shared.runningApplications.contains {
                $0.localizedName == check.value || $0.bundleIdentifier?.contains(check.value.lowercased()) == true
            }
            return SingleCheckResult(
                passed: running,
                message: check.message ?? "\(check.value) is not running"
            )

        case .appInstalled:
            let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: check.value)
            return SingleCheckResult(
                passed: path != nil,
                message: check.message ?? "Application not installed: \(check.value)"
            )

        case .minOSVersion:
            let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
            let parts = check.value.split(separator: ".").compactMap { Int($0) }
            let major = parts.count > 0 ? parts[0] : 0
            let minor = parts.count > 1 ? parts[1] : 0
            let met = currentVersion.majorVersion > major ||
                      (currentVersion.majorVersion == major && currentVersion.minorVersion >= minor)
            return SingleCheckResult(
                passed: met,
                message: check.message ?? "Requires macOS \(check.value) or later"
            )

        case .commandExists:
            let exists = FileManager.default.isExecutableFile(atPath: check.value)
            return SingleCheckResult(
                passed: exists,
                message: check.message ?? "Command not found: \(check.value)"
            )

        case .sipNote:
            // SIP notes are informational, never fail
            logger.info("SIP note for \(check.value): \(check.message ?? "")")
            return SingleCheckResult(passed: true, message: "")
        }
    }

    // MARK: - Permission Checks

    private func checkPermission(_ permission: RequiredPermission) async -> Bool {
        switch permission {
        case .none:
            return true

        case .automationSafari, .automationChrome, .automationEdge,
             .automationBrave, .automationArc, .automationFirefox,
             .automationSystemEvents:
            // Try a lightweight AppleScript to check automation access
            guard let browserName = permission.automationBrowserName else { return false }
            return checkAutomationAccess(for: browserName)

        case .fullDiskAccessOptional:
            return checkFullDiskAccess()

        case .accessibilityOptional:
            return AXIsProcessTrusted()
        }
    }

    private func checkAutomationAccess(for appName: String) -> Bool {
        // Try to run a trivial AppleScript against the app
        let script = NSAppleScript(source: "tell application \"\(appName)\" to return name")
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorNum = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743 = not authorized, -10004 = not authorized
            if errorNum == -1743 || errorNum == -10004 {
                return false
            }
            // -600 = app not running — permission may be OK, app just isn't open
            if errorNum == -600 {
                return true // Permission is likely fine, app just isn't running
            }
        }

        return true
    }

    private func checkFullDiskAccess() -> Bool {
        // Heuristic: try to read a protected directory
        let testPath = NSHomeDirectory() + "/Library/Mail"
        return FileManager.default.isReadableFile(atPath: testPath)
    }
}
