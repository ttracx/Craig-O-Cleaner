import SwiftUI

struct SettingsView: View {
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab = "general"

    // Browser Tabs settings
    @AppStorage("defaultBrowser") private var defaultBrowser: String = "Safari"
    @AppStorage("whitelistPatterns") private var whitelistPatternsRaw: String = ""
    @AppStorage("heavyTabPatterns") private var heavyTabPatternsRaw: String = "youtube.com,facebook.com,twitter.com,twitch.tv,netflix.com,reddit.com,instagram.com,tiktok.com"

    var body: some View {
        VStack(spacing: 10) {
            // Header
            headerView

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("General").tag("general")
                Text("Browser Tabs").tag("browsers")
                Text("About").tag("about")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Tab content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case "general":
                        generalSection
                    case "browsers":
                        browserTabsSettingsSection
                    case "about":
                        aboutSection
                    default:
                        generalSection
                    }

                    Spacer()
                }
                .padding()
            }

            Divider()

            // Footer with Quit button and copyright
            footerView
        }
        .frame(width: 500, height: 650)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.headline)
                .foregroundColor(.primary)

            Toggle(isOn: Binding(
                get: { launchAtLoginManager.isEnabled },
                set: { newValue in
                    launchAtLoginManager.isEnabled = newValue
                    launchAtLoginManager.toggleLaunchAtLogin()
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch at Login")
                        .font(.body)
                    Text("Automatically start Craig-O-Clean when you log in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Browser Tabs Settings Section

    private var browserTabsSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Default Browser
            VStack(alignment: .leading, spacing: 12) {
                Text("Browser Tabs")
                    .font(.headline)

                HStack {
                    Text("Default Browser:")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $defaultBrowser) {
                        Text("Safari").tag("Safari")
                        Text("Google Chrome").tag("Google Chrome")
                        Text("Microsoft Edge").tag("Microsoft Edge")
                        Text("Brave Browser").tag("Brave Browser")
                        Text("Arc").tag("Arc")
                        Text("Firefox").tag("Firefox")
                    }
                    .frame(width: 200)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Whitelist Patterns
            VStack(alignment: .leading, spacing: 8) {
                Text("URL Whitelist")
                    .font(.headline)

                Text("Tab URLs matching these patterns will never be closed by bulk actions. One pattern per line.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $whitelistPatternsRaw)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Heavy Tab Patterns
            VStack(alignment: .leading, spacing: 8) {
                Text("Heavy Tab Patterns")
                    .font(.headline)

                Text("URL patterns considered resource-intensive. Comma-separated.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $heavyTabPatternsRaw)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Button("Reset to Defaults") {
                    heavyTabPatternsRaw = "youtube.com,facebook.com,twitter.com,twitch.tv,netflix.com,reddit.com,instagram.com,tiktok.com"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
#if os(macOS)
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                } else if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                }
#else
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
#endif

                VStack(alignment: .leading, spacing: 4) {
                    Text("Craig-O-Clean")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)

                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Features section
            VStack(alignment: .leading, spacing: 8) {
                Text("Features")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Label("Real-time memory monitoring", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("One-click memory optimization", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("Process management and termination", systemImage: "terminal.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("Browser tab management across 6 browsers", systemImage: "globe")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("Capability-based command execution", systemImage: "gearshape.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var footerView: some View {
        VStack(spacing: 12) {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Craig-O-Clean")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .controlSize(.large)

            Text("This will close the application")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 4)

            // Copyright notice
            VStack(spacing: 6) {
                Text("© 2026 ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                + Text("CraigOClean.com")
                    .font(.caption2)
                    .foregroundColor(.vibePurple)
                    .fontWeight(.medium)
                + Text(" powered by ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                + Text("VibeCaaS.com")
                    .font(.caption2)
                    .foregroundColor(.vibeTeal)
                    .fontWeight(.medium)
                + Text(" a division of ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                + Text("NeuralQuantum.ai")
                    .font(.caption2)
                    .foregroundColor(.vibeAmber)
                    .fontWeight(.medium)
                + Text(" LLC.")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
