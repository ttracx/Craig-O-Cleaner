// MARK: - PermissionCenterView.swift
// Craig-O-Clean - Permissions Center
// Shows automation status per browser, helper status, and FDA guidance

import SwiftUI

struct PermissionCenterView: View {
    @EnvironmentObject var permissions: PermissionsService
    @State private var automationChecks: [String: Bool] = [:]

    private let browsers: [(name: String, bundle: String)] = [
        ("Safari", "com.apple.Safari"),
        ("Google Chrome", "com.google.Chrome"),
        ("Microsoft Edge", "com.microsoft.edgemac"),
        ("Brave Browser", "com.brave.Browser"),
        ("Arc", "company.thebrowser.Browser"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions Center")
                .font(.headline)

            // MARK: - Automation Status
            GroupBox("Automation (Browser Control)") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(browsers, id: \.bundle) { browser in
                        HStack {
                            Image(systemName: automationChecks[browser.bundle] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(automationChecks[browser.bundle] == true ? .green : .red)
                            Text(browser.name)
                            Spacer()
                            if automationChecks[browser.bundle] != true {
                                Button("Fix") {
                                    openAutomationSettings()
                                }
                                .font(.caption)
                            }
                        }
                    }

                    Text("To enable: System Settings > Privacy & Security > Automation > Craig-O-Clean")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Accessibility
            GroupBox("Accessibility") {
                HStack {
                    Image(systemName: permissions.accessibilityStatus == .granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissions.accessibilityStatus == .granted ? .green : .orange)
                    Text(permissions.accessibilityStatus == .granted ? "Granted" : "Not Granted (optional)")
                    Spacer()
                    if permissions.accessibilityStatus != .granted {
                        Button("Open Settings") {
                            openAccessibilitySettings()
                        }
                        .font(.caption)
                    }
                }
                Text("Optional: enables advanced window management features.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - Full Disk Access
            GroupBox("Full Disk Access") {
                HStack {
                    Image(systemName: permissions.fullDiskAccessStatus == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(permissions.fullDiskAccessStatus == .granted ? .green : .yellow)
                    Text(permissions.fullDiskAccessStatus == .granted ? "Granted" : "Not Granted (optional)")
                    Spacer()
                    if permissions.fullDiskAccessStatus != .granted {
                        Button("Open Settings") {
                            openFDASettings()
                        }
                        .font(.caption)
                    }
                }
                Text("Optional: enables reading system logs and protected directories.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .task {
            await checkAutomation()
        }
    }

    private func checkAutomation() async {
        for browser in browsers {
            // Quick check if the app is even installed
            let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundle) != nil
            if !installed {
                automationChecks[browser.bundle] = false
                continue
            }
            // We mark as true by default — actual check happens at execution time
            automationChecks[browser.bundle] = true
        }
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openFDASettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
