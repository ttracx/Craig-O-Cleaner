//
//  RemediationSheet.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

/// Sheet displaying step-by-step remediation instructions for denied permissions
struct RemediationSheet: View {
    let permission: PermissionType

    @Environment(\.dismiss) private var dismiss
    @Environment(PermissionCenter.self) private var permissions

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            Divider()

            instructionsSection

            Spacer()

            footerActions
        }
        .padding(24)
        .frame(width: 550, height: 500)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: headerIcon)
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text("Permission Required")
                    .font(.title2.bold())

                Text(permission.displayName)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(permissionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerIcon: String {
        switch permission {
        case .automation:
            return "applescript"
        case .fullDiskAccess:
            return "internaldrive"
        case .helper:
            return "shield.checkered"
        }
    }

    private var permissionDescription: String {
        switch permission {
        case .automation(let browser):
            return "Craig-O-Clean needs permission to control \(browser.rawValue) to perform cleanup operations like closing tabs and clearing history."
        case .fullDiskAccess:
            return "Full Disk Access allows Craig-O-Clean to access system files, browser data, and application caches for thorough cleanup."
        case .helper:
            return "The Privileged Helper enables Craig-O-Clean to perform system-level operations that require administrator privileges."
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Fix:")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(remediationSteps.enumerated()), id: \.offset) { index, step in
                        stepRow(number: index + 1, step: step)
                    }
                }
            }
        }
    }

    private func stepRow(number: Int, step: RemediationStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number badge
            Text("\(number)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.blue)
                )

            // Instruction text
            VStack(alignment: .leading, spacing: 4) {
                Text(step.instruction)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                if let path = step.systemSettingsPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
            }

            Spacer()
        }
    }

    private var remediationSteps: [RemediationStep] {
        permissions.remediationSteps(for: permission)
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if canOpenAutomatically {
                Button("Open System Settings") {
                    permissions.openSystemSettings(for: permission)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var canOpenAutomatically: Bool {
        switch permission {
        case .automation, .fullDiskAccess:
            return true
        case .helper:
            return false
        }
    }
}

// MARK: - PermissionType Identifiable

extension PermissionType: Identifiable {
    var id: String {
        switch self {
        case .automation(let browser):
            return "automation-\(browser.rawValue)"
        case .fullDiskAccess:
            return "fullDiskAccess"
        case .helper:
            return "helper"
        }
    }
}

// MARK: - Preview

#Preview("Safari Automation") {
    RemediationSheet(permission: .automation(.safari))
        .environment(PermissionCenter.shared)
}

#Preview("Full Disk Access") {
    RemediationSheet(permission: .fullDiskAccess)
        .environment(PermissionCenter.shared)
}

#Preview("Privileged Helper") {
    RemediationSheet(permission: .helper)
        .environment(PermissionCenter.shared)
}
