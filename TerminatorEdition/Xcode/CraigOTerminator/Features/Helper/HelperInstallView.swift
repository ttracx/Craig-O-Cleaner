//
//  HelperInstallView.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

/// View for managing privileged helper installation and status
struct HelperInstallView: View {

    // MARK: - Environment

    @Environment(HelperInstaller.self) private var installer

    // MARK: - State

    @State private var isInstalling = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Privileged Helper")
                        .font(.headline)

                    Text(installer.status.displayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Description
            Text("The privileged helper enables system-level operations like disk repair, memory purge, and system maintenance. It runs as a background service with elevated permissions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Actions
            VStack(spacing: 12) {
                if needsAction {
                    Button(action: handleInstall) {
                        HStack {
                            if isInstalling {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: actionIcon)
                            }

                            Text(actionTitle)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isInstalling)
                }

                if installer.status.isInstalled {
                    Button(action: handleUninstall) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Uninstall Helper")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isInstalling)
                }

                Button(action: refreshStatus) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Status")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isInstalling)
            }

            // Capabilities requiring helper
            if installer.status == .notInstalled || installer.status.needsUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Requires Helper:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 4) {
                        HelperCapabilityRow(title: "Flush DNS Cache", icon: "network")
                        HelperCapabilityRow(title: "Purge Inactive Memory", icon: "memorychip")
                        HelperCapabilityRow(title: "System Maintenance", icon: "gearshape.2")
                        HelperCapabilityRow(title: "Rebuild Spotlight", icon: "magnifyingglass")
                        HelperCapabilityRow(title: "Empty All Trashes", icon: "trash.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
        )
        .alert("Helper Installation Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await refreshStatusAsync()
        }
    }

    // MARK: - Status Properties

    private var statusIcon: String {
        switch installer.status {
        case .installed:
            return "checkmark.circle.fill"
        case .outdated:
            return "exclamationmark.triangle.fill"
        case .notInstalled, .unknown:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch installer.status {
        case .installed:
            return .green
        case .outdated:
            return .orange
        case .notInstalled, .unknown:
            return .red
        }
    }

    private var needsAction: Bool {
        switch installer.status {
        case .notInstalled, .outdated:
            return true
        case .installed, .unknown:
            return false
        }
    }

    private var actionTitle: String {
        switch installer.status {
        case .notInstalled, .unknown:
            return "Install Helper"
        case .outdated:
            return "Update Helper"
        case .installed:
            return "Reinstall Helper"
        }
    }

    private var actionIcon: String {
        switch installer.status {
        case .notInstalled, .unknown:
            return "arrow.down.circle"
        case .outdated:
            return "arrow.triangle.2.circlepath"
        case .installed:
            return "arrow.clockwise.circle"
        }
    }

    // MARK: - Actions

    private func handleInstall() {
        isInstalling = true

        Task { @MainActor in
            do {
                try await installer.install()
                isInstalling = false
            } catch {
                isInstalling = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func handleUninstall() {
        isInstalling = true

        Task { @MainActor in
            do {
                try await installer.uninstall()
                isInstalling = false
            } catch {
                isInstalling = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func refreshStatus() {
        Task { @MainActor in
            await refreshStatusAsync()
        }
    }

    private func refreshStatusAsync() async {
        await installer.checkStatus()
    }
}

// MARK: - Capability Row

private struct HelperCapabilityRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 14)
            Text(title)
        }
    }
}

// MARK: - Preview

#Preview {
    HelperInstallView()
        .environment(HelperInstaller.shared)
        .padding()
        .frame(width: 400)
}
