// File: CraigOClean-vNext/CraigOClean/UI/SettingsView.swift
// Craig-O-Clean - Settings View
// Application settings and edition information

import SwiftUI

struct SettingsView: View {

    // MARK: - Properties

    @EnvironmentObject private var container: DIContainer
    @EnvironmentObject private var environment: AppEnvironment

    @State private var showingCompareEditions = false
    @State private var showingLicenseActivation = false

    // MARK: - Body

    var body: some View {
        Form {
            editionSection

            if environment.isPro {
                licensingSection
                updatesSection
            }

            logsSection
            aboutSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingCompareEditions) {
            CompareEditionsSheet()
        }
        .sheet(isPresented: $showingLicenseActivation) {
            LicenseActivationSheet()
        }
    }

    // MARK: - Edition Section

    private var editionSection: some View {
        Section {
            HStack {
                Label {
                    VStack(alignment: .leading) {
                        Text(environment.edition.displayName)
                            .font(.headline)
                        Text(environment.edition.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: environment.isPro ? "crown.fill" : "crown")
                        .foregroundColor(environment.isPro ? .yellow : .secondary)
                }

                Spacer()
            }

            if environment.isLite {
                Button {
                    showingCompareEditions = true
                } label: {
                    Label("Compare Craig-O-Clean Editions", systemImage: "arrow.left.arrow.right")
                }
            }
        } header: {
            Text("Edition")
        } footer: {
            if environment.isLite {
                Text("Learn about the differences between Craig-O-Clean editions.")
            }
        }
    }

    // MARK: - Licensing Section (Pro Only)

    private var licensingSection: some View {
        Section {
            let status = container.licensingService.status()

            HStack {
                Text("License Status")
                Spacer()
                Text(status.displayName)
                    .foregroundColor(status.isActive ? .green : .orange)
            }

            if let email = container.licensingService.registeredEmail {
                HStack {
                    Text("Registered To")
                    Spacer()
                    Text(email)
                        .foregroundColor(.secondary)
                }
            }

            Button("Activate License...") {
                showingLicenseActivation = true
            }
        } header: {
            Text("License")
        }
    }

    // MARK: - Updates Section (Pro Only)

    private var updatesSection: some View {
        Section {
            HStack {
                Text("Update Channel")
                Spacer()
                Picker("", selection: Binding(
                    get: { container.updateService.channel },
                    set: { container.updateService.channel = $0 }
                )) {
                    ForEach(UpdateChannel.allCases, id: \.self) { channel in
                        Text(channel.displayName).tag(channel)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            Button {
                Task {
                    do {
                        _ = try await container.updateService.checkForUpdates()
                    } catch {
                        container.logger.error("Update check failed: \(error)", category: .updates)
                    }
                }
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise")
            }

            if let lastCheck = container.updateService.lastCheckDate {
                HStack {
                    Text("Last Checked")
                    Spacer()
                    Text(lastCheck.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Updates")
        }
    }

    // MARK: - Logs Section

    private var logsSection: some View {
        Section {
            HStack {
                Text("Log Entries")
                Spacer()
                Text("\(container.logStore.entries.count)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Errors")
                Spacer()
                Text("\(container.logStore.errorCount)")
                    .foregroundColor(container.logStore.errorCount > 0 ? .red : .secondary)
            }

            Button {
                exportLogs()
            } label: {
                Label("Export Logs...", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                container.logStore.clear()
            } label: {
                Label("Clear Logs", systemImage: "trash")
            }
        } header: {
            Text("Logs")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(environment.fullVersionString)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Edition")
                Spacer()
                Text(environment.edition.rawValue)
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://craigosoft.com")!) {
                Label("Visit Website", systemImage: "globe")
            }

            Link(destination: URL(string: "https://craigosoft.com/support")!) {
                Label("Get Help", systemImage: "questionmark.circle")
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Actions

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "CraigOClean-Logs-\(Date().ISO8601Format()).log"

        if panel.runModal() == .OK, let url = panel.url {
            let content = container.logStore.exportAsText()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Compare Editions Sheet (Apple-Safe Funnel)

struct CompareEditionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var linkCopied = false

    private let proInfoURL = "https://craigosoft.com/pro"

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Compare Craig-O-Clean Editions")
                .font(.title2)
                .fontWeight(.bold)

            // Comparison grid
            HStack(alignment: .top, spacing: 32) {
                // Lite column
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lite")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("Mac App Store")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    featureRow("User cache cleanup", available: true)
                    featureRow("Log file cleanup", available: true)
                    featureRow("Scan preview", available: true)
                    featureRow("Cleanup history", available: true)
                    featureRow("Activity logs", available: true)
                    featureRow("System-wide cleanup", available: false)
                    featureRow("Export diagnostics", available: false)
                    featureRow("Advanced maintenance", available: false)
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Pro column
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pro")
                        .font(.headline)
                        .foregroundColor(.yellow)

                    Text("Direct Download")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    featureRow("User cache cleanup", available: true)
                    featureRow("Log file cleanup", available: true)
                    featureRow("Scan preview", available: true)
                    featureRow("Cleanup history", available: true)
                    featureRow("Activity logs", available: true)
                    featureRow("System-wide cleanup", available: true)
                    featureRow("Export diagnostics", available: true)
                    featureRow("Advanced maintenance", available: true)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Explanation
            Text("Some advanced tools require permissions not available in the Mac App Store edition.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Actions (Apple-safe)
            HStack(spacing: 16) {
                Button("Copy Pro Info Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(proInfoURL, forType: .string)
                    linkCopied = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        linkCopied = false
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            if linkCopied {
                Text("Link copied to clipboard")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(32)
        .frame(width: 500)
    }

    private func featureRow(_ feature: String, available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? .green : .secondary)
                .font(.caption)

            Text(feature)
                .font(.caption)
                .foregroundColor(available ? .primary : .secondary)
        }
    }
}

// MARK: - Pro Feature Sheet (Apple-Safe)

struct ProFeatureSheet: View {
    let message: String
    @Environment(\.dismiss) private var dismiss
    @State private var linkCopied = false

    private let proInfoURL = "https://craigosoft.com/pro"

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Not Available in This Edition")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 16) {
                Button("Copy Pro Info Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(proInfoURL, forType: .string)
                    linkCopied = true
                }
                .buttonStyle(.bordered)

                Button("OK") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            if linkCopied {
                Text("Link copied")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(32)
        .frame(width: 380)
    }
}

// MARK: - License Activation Sheet

struct LicenseActivationSheet: View {
    @EnvironmentObject private var container: DIContainer
    @Environment(\.dismiss) private var dismiss

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Activate License")
                .font(.title2)
                .fontWeight(.bold)

            TextField("License Key (XXXX-XXXX-XXXX-XXXX)", text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Activate") {
                    Task { await activate() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.isEmpty || isActivating)
            }

            if isActivating {
                ProgressView()
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    private func activate() async {
        isActivating = true
        errorMessage = nil

        do {
            _ = try await container.licensingService.activate(key: licenseKey)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isActivating = false
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
        }
        .environmentObject(DIContainer.shared)
        .environmentObject(AppEnvironment.shared)
    }
}
#endif
