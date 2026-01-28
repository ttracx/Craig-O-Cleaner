// MARK: - SandboxMigrationManager.swift
// Craig-O-Clean - Sandbox Migration Detection and Management
// Detects when app upgrades from non-sandboxed to sandboxed version

import Foundation
import SwiftUI
import os.log

/// Manages the detection and handling of sandbox migration
@MainActor
class SandboxMigrationManager: ObservableObject {
    static let shared = SandboxMigrationManager()

    private let logger = Logger(subsystem: "com.craigoclean.app", category: "SandboxMigration")

    @Published private(set) var hasMigrated = false
    @Published var shouldShowMigrationNotice = false

    private let userDefaults = UserDefaults.standard
    private let migrationKey = "hasCompletedSandboxMigration"
    private let previousVersionKey = "previousAppVersion"

    private init() {
        checkMigrationStatus()
    }

    /// Check if the app is running in a sandbox
    var isSandboxed: Bool {
        let environment = Foundation.ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Check migration status and determine if notice should be shown
    func checkMigrationStatus() {
        let hasCompletedMigration = userDefaults.bool(forKey: migrationKey)
        let previousVersion = userDefaults.string(forKey: previousVersionKey)

        // If we're sandboxed, haven't migrated yet, and had a previous version
        if isSandboxed && !hasCompletedMigration && previousVersion != nil {
            logger.info("Sandbox migration detected - showing notice")
            shouldShowMigrationNotice = true
        } else if isSandboxed && !hasCompletedMigration && previousVersion == nil {
            // First install of sandboxed version
            logger.info("First sandboxed install - no migration needed")
            markMigrationComplete()
        }

        // Store current version for next launch
        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            userDefaults.set(currentVersion, forKey: previousVersionKey)
        }
    }

    /// Mark migration as complete
    func markMigrationComplete() {
        logger.info("Marking sandbox migration as complete")
        userDefaults.set(true, forKey: migrationKey)
        hasMigrated = true
        shouldShowMigrationNotice = false
    }

    /// Reset migration status (for testing)
    func resetMigrationStatus() {
        logger.warning("Resetting migration status - for testing only")
        userDefaults.removeObject(forKey: migrationKey)
        hasMigrated = false
        checkMigrationStatus()
    }
}

// MARK: - Sandbox Migration Notice View

struct SandboxMigrationNotice: View {
    @EnvironmentObject var migrationManager: SandboxMigrationManager
    @EnvironmentObject var permissions: PermissionsService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Security Upgrade")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Craig-O-Clean is now sandboxed for enhanced security")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            // Explanation
            VStack(alignment: .leading, spacing: 16) {
                MigrationFeatureRow(
                    icon: "checkmark.shield.fill",
                    title: "Enhanced Security",
                    description: "Your data is now better protected with App Sandbox"
                )

                MigrationFeatureRow(
                    icon: "lock.fill",
                    title: "Privacy First",
                    description: "Limited access ensures your information stays private"
                )

                MigrationFeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Permission Reset Required",
                    description: "macOS requires re-granting permissions for security"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Important Notice
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Important")
                        .fontWeight(.semibold)
                }

                Text("You'll need to grant permissions again. We'll guide you through the process.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 20)

            // Action Button
            Button(action: {
                migrationManager.markMigrationComplete()
                dismiss()
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Feature Row Component

struct MigrationFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SandboxMigrationNotice()
        .environmentObject(SandboxMigrationManager.shared)
        .environmentObject(PermissionsService())
}
