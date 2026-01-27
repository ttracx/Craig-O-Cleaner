//
//  PermissionStatusView.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

/// View displaying all permission statuses with remediation options
struct PermissionStatusView: View {
    @Environment(PermissionCenter.self) private var permissions
    @State private var isRefreshing = false
    @State private var showingRemediation: PermissionType?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                Divider()

                browserAutomationSection

                Divider()

                systemAccessSection

                Divider()

                footerSection
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
        .sheet(item: $showingRemediation) { permission in
            RemediationSheet(permission: permission)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title)
                    .foregroundStyle(.blue)

                Text("Permissions")
                    .font(.title.bold())
            }

            Text("Craig-O-Clean requires various macOS permissions to perform system cleanup operations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Browser Automation

    private var browserAutomationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browser Automation")
                .font(.headline)

            Text("Control browsers to close tabs, clear history, and manage downloads.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(BrowserApp.allCases, id: \.self) { browser in
                PermissionRow(
                    icon: browser.icon,
                    title: browser.rawValue,
                    state: permissions.automationPermissions[browser] ?? .unknown,
                    isInstalled: isBrowserInstalled(browser),
                    onFix: {
                        showingRemediation = .automation(browser)
                    },
                    onRequest: {
                        Task {
                            await requestPermission(for: browser)
                        }
                    }
                )
            }
        }
    }

    // MARK: - System Access

    private var systemAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Access")
                .font(.headline)

            Text("Access system files and perform elevated operations.")
                .font(.caption)
                .foregroundStyle(.secondary)

            PermissionRow(
                icon: "internaldrive",
                title: "Full Disk Access",
                state: permissions.fullDiskAccess,
                isInstalled: true,
                onFix: {
                    showingRemediation = .fullDiskAccess
                },
                onRequest: {
                    permissions.openSystemSettings(for: .fullDiskAccess)
                }
            )

            PermissionRow(
                icon: "shield.checkered",
                title: "Privileged Helper",
                state: permissions.helperInstalled ? .granted : .denied,
                isInstalled: true,
                onFix: {
                    showingRemediation = .helper
                },
                onRequest: {
                    // Show helper installation dialog
                    // TODO: Implement helper installation
                }
            )
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                Task {
                    isRefreshing = true
                    await permissions.refreshAll()
                    isRefreshing = false
                }
            } label: {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Refresh All")
                }
            }
            .disabled(isRefreshing)

            Spacer()

            if let lastCheck = permissions.lastCheckDate {
                Text("Last checked: \(lastCheck, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func isBrowserInstalled(_ browser: BrowserApp) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
    }

    private func requestPermission(for browser: BrowserApp) async {
        let state = await AutomationChecker.requestPermission(for: browser)
        await MainActor.run {
            permissions.automationPermissions[browser] = state
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let state: PermissionState
    let isInstalled: Bool
    let onFix: () -> Void
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(iconColor)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                if !isInstalled {
                    Text("Not installed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // State indicator
            stateIndicator

            // Action button
            if isInstalled {
                actionButton
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: - State Indicator

    @ViewBuilder
    private var stateIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: stateIcon)
                .foregroundStyle(stateColor)

            Text(stateText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stateIcon: String {
        switch state {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .unknown:
            return "circle"
        }
    }

    private var stateColor: Color {
        switch state {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .unknown:
            return .gray
        }
    }

    private var stateText: String {
        switch state {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        case .unknown:
            return "Unknown"
        }
    }

    private var iconColor: Color {
        if !isInstalled {
            return .gray
        }
        return state == .granted ? .green : .primary
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .denied:
            Button("Fix") {
                onFix()
            }
            .buttonStyle(.borderedProminent)

        case .notDetermined:
            Button("Request") {
                onRequest()
            }
            .buttonStyle(.bordered)

        case .granted, .unknown:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Permission Status View") {
    PermissionStatusView()
        .environment(PermissionCenter.shared)
        .frame(width: 600, height: 700)
}

#Preview("Permission Row - Granted") {
    PermissionRow(
        icon: "safari",
        title: "Safari",
        state: .granted,
        isInstalled: true,
        onFix: {},
        onRequest: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Permission Row - Denied") {
    PermissionRow(
        icon: "globe",
        title: "Google Chrome",
        state: .denied,
        isInstalled: true,
        onFix: {},
        onRequest: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Permission Row - Not Determined") {
    PermissionRow(
        icon: "flame",
        title: "Firefox",
        state: .notDetermined,
        isInstalled: true,
        onFix: {},
        onRequest: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Permission Row - Not Installed") {
    PermissionRow(
        icon: "globe",
        title: "Brave Browser",
        state: .unknown,
        isInstalled: false,
        onFix: {},
        onRequest: {}
    )
    .padding()
    .frame(width: 400)
}
