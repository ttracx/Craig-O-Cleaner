// MARK: - PermissionStatusView.swift
// Craig-O-Clean - Permission Status UI
// Displays permission states with traffic light indicators and enable guides

import SwiftUI

/// Main view showing all permission statuses
struct PermissionStatusView: View {
    @ObservedObject var permissionManager: PermissionManager

    @State private var isRefreshing = false
    @State private var showingGuide: PermissionType?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Permissions")
                    .font(.headline)

                Spacer()

                Button(action: refreshPermissions) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
                .help("Refresh permission status")
            }

            Divider()

            // Accessibility
            PermissionRowView(
                title: "Accessibility",
                description: "Required for advanced window management",
                state: permissionManager.accessibilityStatus,
                icon: "accessibility",
                onEnable: {
                    permissionManager.requestAccessibility()
                },
                onLearnMore: {
                    showingGuide = .accessibility
                }
            )

            // Full Disk Access
            PermissionRowView(
                title: "Full Disk Access",
                description: "Optional - enhances process monitoring",
                state: permissionManager.fullDiskAccessStatus,
                icon: "internaldrive",
                onEnable: {
                    permissionManager.requestFullDiskAccess()
                },
                onLearnMore: {
                    showingGuide = .fullDiskAccess
                }
            )

            Divider()

            // Browser Automation Section
            Text("Browser Automation")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(installedBrowsers, id: \.bundleId) { browser in
                PermissionRowView(
                    title: browser.name,
                    description: "Manage browser tabs",
                    state: permissionManager.automationStatus[browser.bundleId] ?? .unknown,
                    icon: browser.icon,
                    onEnable: {
                        Task {
                            await permissionManager.requestAutomation(for: browser.bundleId)
                        }
                    },
                    onLearnMore: {
                        showingGuide = .automation(bundleId: browser.bundleId)
                    }
                )
            }

            // Last checked time
            if let lastCheck = permissionManager.lastCheckTime {
                Text("Last checked: \(lastCheck.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .sheet(item: $showingGuide) { permissionType in
            PermissionGuideView(permissionType: permissionType, permissionManager: permissionManager)
        }
    }

    // MARK: - Computed Properties

    private var installedBrowsers: [BrowserInfo] {
        PermissionManager.browserBundleIds.compactMap { bundleId in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
                return nil
            }
            return BrowserInfo(bundleId: bundleId)
        }
    }

    // MARK: - Actions

    private func refreshPermissions() {
        isRefreshing = true
        Task {
            await permissionManager.refreshAllPermissions()
            isRefreshing = false
        }
    }
}

// MARK: - Permission Row View

struct PermissionRowView: View {
    let title: String
    let description: String
    let state: PermissionState
    let icon: String
    let onEnable: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: state.iconName)
                .foregroundColor(stateColor)
                .font(.title2)

            // Icon
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action button
            if state.isDenied || state.needsRequest {
                Button("Enable") {
                    onEnable()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if state.isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            // Info button
            Button(action: onLearnMore) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Learn how to enable this permission")
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        switch state {
        case .granted: return .green
        case .denied, .restricted: return .red
        case .notDetermined, .unknown: return .yellow
        }
    }
}

// MARK: - Permission Guide View

struct PermissionGuideView: View {
    let permissionType: PermissionType
    let permissionManager: PermissionManager

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(permissionType.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            // Why needed
            VStack(alignment: .leading, spacing: 8) {
                Text("Why Craig-O-Clean Needs This")
                    .font(.headline)

                Text(whyNeeded)
                    .foregroundColor(.secondary)
            }

            // Steps
            VStack(alignment: .leading, spacing: 8) {
                Text("How to Enable")
                    .font(.headline)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.accentColor)
                            .clipShape(Circle())

                        Text(step)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack {
                Spacer()

                Button("Open System Settings") {
                    permissionManager.openSystemSettings(for: permissionType)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 450, height: 400)
    }

    // MARK: - Content

    private var iconName: String {
        switch permissionType {
        case .automation: return "gearshape.2"
        case .accessibility: return "accessibility"
        case .fullDiskAccess: return "internaldrive"
        case .fileAccess: return "folder"
        case .notifications: return "bell"
        }
    }

    private var subtitle: String {
        switch permissionType {
        case .automation(let bundleId):
            return "Control \(permissionManager.appName(for: bundleId)) via AppleScript"
        case .accessibility:
            return "Required for advanced system integration"
        case .fullDiskAccess:
            return "Optional enhanced monitoring"
        case .fileAccess:
            return "Access files and folders"
        case .notifications:
            return "Send alerts and notifications"
        }
    }

    private var whyNeeded: String {
        switch permissionType {
        case .automation(let bundleId):
            let appName = permissionManager.appName(for: bundleId)
            return "Craig-O-Clean needs Automation permission to enumerate and close tabs in \(appName). This allows you to manage browser memory usage by closing heavy tabs."

        case .accessibility:
            return "Accessibility permission enables advanced window management and the ability to interact with other applications' UI elements. This is optional but enables additional features."

        case .fullDiskAccess:
            return "Full Disk Access allows Craig-O-Clean to monitor all running processes and their resource usage. Without it, some system processes may not appear in the process list. This permission is optional."

        case .fileAccess:
            return "File access permission allows Craig-O-Clean to read and clean files in the selected folder."

        case .notifications:
            return "Notification permission allows Craig-O-Clean to alert you about high memory usage and completed cleanup operations."
        }
    }

    private var steps: [String] {
        switch permissionType {
        case .automation:
            return [
                "Click 'Open System Settings' below",
                "Find Craig-O-Clean in the list on the left",
                "Enable the checkbox for the browser you want to control",
                "Return to Craig-O-Clean"
            ]

        case .accessibility:
            return [
                "Click 'Open System Settings' below",
                "You may need to unlock the padlock (click the lock icon)",
                "Click the '+' button to add Craig-O-Clean",
                "Navigate to Applications and select Craig-O-Clean",
                "Ensure the checkbox next to Craig-O-Clean is enabled"
            ]

        case .fullDiskAccess:
            return [
                "Click 'Open System Settings' below",
                "You may need to unlock the padlock (click the lock icon)",
                "Click the '+' button to add Craig-O-Clean",
                "Navigate to Applications and select Craig-O-Clean",
                "Craig-O-Clean will need to restart to apply changes"
            ]

        case .fileAccess, .notifications:
            return [
                "Click 'Open System Settings' below",
                "Find Craig-O-Clean in the list",
                "Enable the appropriate checkbox"
            ]
        }
    }
}

// MARK: - Browser Info Helper

private struct BrowserInfo: Identifiable {
    let bundleId: String

    var id: String { bundleId }

    var name: String {
        let names: [String: String] = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Google Chrome",
            "com.microsoft.edgemac": "Microsoft Edge",
            "com.brave.Browser": "Brave",
            "company.thebrowser.Browser": "Arc",
            "org.mozilla.firefox": "Firefox"
        ]
        return names[bundleId] ?? bundleId
    }

    var icon: String {
        switch bundleId {
        case "com.apple.Safari": return "safari"
        case "com.google.Chrome": return "globe"
        case "com.microsoft.edgemac": return "globe"
        case "com.brave.Browser": return "globe"
        case "company.thebrowser.Browser": return "globe"
        case "org.mozilla.firefox": return "flame"
        default: return "globe"
        }
    }
}

// MARK: - PermissionType Identifiable Extension

extension PermissionType: Identifiable {
    var id: String {
        switch self {
        case .automation(let bundleId): return "automation-\(bundleId)"
        case .accessibility: return "accessibility"
        case .fullDiskAccess: return "fullDiskAccess"
        case .fileAccess(let url): return "fileAccess-\(url.path)"
        case .notifications: return "notifications"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PermissionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionStatusView(permissionManager: PermissionManager())
            .frame(width: 400)
    }
}
#endif
