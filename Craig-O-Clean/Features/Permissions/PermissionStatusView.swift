// MARK: - PermissionStatusView.swift
// Craig-O-Clean - Permission Status & Remediation UI
// Shows permission state for automation targets with remediation guidance

import SwiftUI

struct CapabilityPermissionStatusView: View {
    @EnvironmentObject var permissions: PermissionsService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)

            Text("Craig-O-Clean needs specific permissions to manage browsers and perform system operations.")
                .font(.callout)
                .foregroundColor(.secondary)

            Divider()

            // Browser automation permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Browser Automation")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(BrowserApp.allCases, id: \.self) { browser in
                    BrowserPermissionRow(browser: browser)
                }
            }

            Divider()

            // System permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("System Permissions")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                SystemPermissionRow(
                    title: "Accessibility",
                    icon: "accessibility",
                    description: "Required for advanced window management",
                    settingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )

                SystemPermissionRow(
                    title: "Full Disk Access",
                    icon: "externaldrive",
                    description: "Enables comprehensive cache cleanup",
                    settingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                )
            }

            Divider()

            // Open System Settings
            Button(action: openSystemSettings) {
                Label("Open System Settings", systemImage: "gear")
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Browser App Enum (for permissions)

enum BrowserApp: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case firefox = "Firefox"
    case brave = "Brave Browser"
    case arc = "Arc"

    var icon: String {
        switch self {
        case .safari: return "safari"
        case .chrome, .edge, .brave, .arc: return "globe"
        case .firefox: return "flame"
        }
    }

    var bundleId: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .firefox: return "org.mozilla.firefox"
        case .brave: return "com.brave.Browser"
        case .arc: return "company.thebrowser.Browser"
        }
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}

// MARK: - Browser Permission Row

struct BrowserPermissionRow: View {
    let browser: BrowserApp

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: browser.icon)
                .frame(width: 20)
                .foregroundColor(.vibePurple)

            Text(browser.rawValue)
                .frame(width: 120, alignment: .leading)

            if browser.isInstalled {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text("Not installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if browser.isInstalled {
                Button("Grant Access") {
                    openAutomationSettings()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - System Permission Row

struct SystemPermissionRow: View {
    let title: String
    let icon: String
    let description: String
    let settingsPath: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.vibePurple)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: settingsPath) {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }
}
