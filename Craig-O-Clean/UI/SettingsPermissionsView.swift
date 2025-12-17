// MARK: - SettingsPermissionsView.swift
// Craig-O-Clean - Settings and Permissions View
// App configuration, permission management, and diagnostics

import SwiftUI
import AuthenticationServices

struct SettingsPermissionsView: View {
    @EnvironmentObject var systemMetrics: SystemMetricsService
    @EnvironmentObject var permissions: PermissionsService
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var userStore: LocalUserStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var stripe: StripeCheckoutService
    
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("memoryWarningThreshold") private var memoryWarningThreshold: Double = 80.0
    
    @State private var showingDiagnostics = false
    @State private var showingAbout = false
    @State private var showingPrivacyPolicy = false
    @State private var accountErrorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Account / Sign-in
                accountSection

                // Subscription / Upgrades
                subscriptionSection

                // General Settings
                generalSettingsSection
                
                // Monitoring Settings
                monitoringSettingsSection
                
                // Permissions Section
                permissionsSection
                
                // Privacy Section
                privacySection
                
                // Diagnostics Section
                diagnosticsSection
                
                // About Section
                aboutSection
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await permissions.checkAllPermissions()
                    }
                } label: {
                    Label("Refresh Permissions", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsSheet()
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicySheet()
        }
        .onAppear {
            // Refresh permissions when view appears
            Task {
                await permissions.checkAllPermissions()
            }

            // Ensure local profile exists if keychain session exists
            syncLocalProfileFromAuthIfNeeded()
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        SettingsSection(title: "Account", icon: "person.crop.circle") {
            VStack(alignment: .leading, spacing: 12) {
                if auth.isSignedIn, let userId = auth.userId {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(userStore.profile?.displayName ?? "Signed in")
                            .font(.headline)
                        Text(userStore.profile?.email ?? "Apple ID linked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("User ID: \(userId)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Button("Sign Out") {
                            auth.signOut()
                            userStore.setProfile(nil)
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                } else {
                    Text("Sign in to keep your settings tied to your identity on this Mac and to simplify upgrades/restores.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                handleAppleCredential(credential)
                            } else {
                                accountErrorMessage = "Sign-in failed."
                            }
                        case .failure:
                            accountErrorMessage = "Sign-in cancelled or failed."
                        }
                    }
                    .frame(height: 44)
                    .signInWithAppleButtonStyle(.black)

                    if let accountErrorMessage {
                        Text(accountErrorMessage)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        SettingsSection(title: "Subscription", icon: "crown") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptions.isPro ? "Pro Active" : "Free Plan")
                            .font(.headline)
                        Text(subscriptions.isPro ? "Thanks for supporting Craig-O-Clean." : "Upgrade to unlock Pro features.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if subscriptions.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if let msg = subscriptions.lastErrorMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                // App Store subscriptions (StoreKit 2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upgrade via App Store")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if subscriptions.products.isEmpty {
                        Button("Load Plans") {
                            Task { await subscriptions.loadProducts() }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        ForEach(subscriptions.products, id: \.id) { product in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                        .fontWeight(.medium)
                                    Text(product.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(product.displayPrice)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button("Buy") {
                                    Task { await subscriptions.purchase(product) }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack {
                        Button("Restore Purchases") {
                            Task { await subscriptions.restorePurchases() }
                        }
                        .buttonStyle(.bordered)

                        Button("Manage Subscriptions") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }

                Divider()

                // Stripe (external) – requires your backend
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business / Team (Stripe)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Use Stripe for off-App-Store sales (e.g., invoices or team licensing). A backend is required.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Open Stripe Checkout") {
                        Task {
                            do {
                                try await stripe.openCheckout(planId: "pro_team", userId: auth.userId)
                            } catch {
                                // Keep this minimal in UI; user can configure backend URL in Info.plist.
                                subscriptions.lastErrorMessage = "Stripe checkout not configured."
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        auth.handleAppleSignIn(credential: credential)

        let formatter = PersonNameComponentsFormatter()
        let fullName = credential.fullName.flatMap { formatter.string(from: $0) }

        let now = Date()
        let existing = userStore.profile

        let profile = UserProfile(
            userId: credential.user,
            displayName: fullName ?? existing?.displayName,
            email: credential.email ?? existing?.email,
            createdAt: existing?.createdAt ?? now,
            lastSignInAt: now
        )
        userStore.setProfile(profile)
        accountErrorMessage = nil
    }

    private func syncLocalProfileFromAuthIfNeeded() {
        guard auth.isSignedIn, let userId = auth.userId else { return }
        guard userStore.profile?.userId != userId else { return }

        let now = Date()
        userStore.setProfile(UserProfile(
            userId: userId,
            displayName: nil,
            email: nil,
            createdAt: now,
            lastSignInAt: now
        ))
    }
    
    // MARK: - General Settings Section
    
    private var generalSettingsSection: some View {
        SettingsSection(title: "General", icon: "gearshape") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Show in Dock",
                    description: "Display app icon in the Dock when main window is open",
                    isOn: $showInDock
                )
                
                SettingsToggle(
                    title: "Launch at Login",
                    description: "Start Craig-O-Clean automatically when you log in",
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setLaunchAtLogin(newValue)
                }
                
                SettingsToggle(
                    title: "Enable Notifications",
                    description: "Show alerts for high memory pressure or system issues",
                    isOn: $enableNotifications
                )
            }
        }
    }
    
    // MARK: - Monitoring Settings Section
    
    private var monitoringSettingsSection: some View {
        SettingsSection(title: "Monitoring", icon: "gauge.with.dots.needle.bottom.50percent") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Refresh Interval")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(String(format: "%.1f", refreshInterval)) seconds")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $refreshInterval, in: 1...10, step: 0.5)
                    
                    Text("How often to update system metrics. Lower values provide more real-time data but use slightly more resources.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onChange(of: refreshInterval) { _, newValue in
                    systemMetrics.refreshInterval = newValue
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Warning Threshold")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(memoryWarningThreshold))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $memoryWarningThreshold, in: 50...95, step: 5)
                    
                    Text("Show warning when memory usage exceeds this percentage.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Permissions Section

    private var permissionsSection: some View {
        SettingsSection(title: "Permissions", icon: "lock.shield") {
            VStack(spacing: 16) {
                // Critical permissions status overview
                if !permissions.hasAllCriticalPermissions {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.vibeAmber)

                            Text("Critical Permissions Required")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            if permissions.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }

                        Text("Craig-O-Clean requires the following permissions to fully manage your apps, processes, and system:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Missing permissions badges
                        HStack(spacing: 8) {
                            ForEach(permissions.missingCriticalPermissions) { permission in
                                HStack(spacing: 4) {
                                    Image(systemName: permission.icon)
                                    Text(permission.rawValue)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.vibeAmber.opacity(0.2))
                                .foregroundColor(.vibeAmber)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color.vibeAmber.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    // All permissions granted
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.vibeTeal)

                        Text("All Critical Permissions Granted")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        if permissions.isChecking {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding()
                    .background(Color.vibeTeal.opacity(0.1))
                    .cornerRadius(8)
                }

                Divider()

                // Accessibility
                PermissionRow(
                    title: "Accessibility",
                    description: "Access advanced system features and window management",
                    status: permissions.accessibilityStatus,
                    onRequest: {
                        permissions.requestAccessibilityPermission()
                    },
                    showRestartHint: true
                )

                Divider()

                // Full Disk Access
                PermissionRow(
                    title: "Full Disk Access",
                    description: "Read detailed process and system information",
                    status: permissions.fullDiskAccessStatus,
                    onRequest: {
                        permissions.requestFullDiskAccessPermission()
                    }
                )

                Divider()

                // Automation targets
                Text("Browser Automation")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Control browser tabs like Safari and Chrome")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(permissions.automationTargets) { target in
                    AutomationPermissionRow(
                        target: target,
                        onRequest: {
                            permissions.requestAutomationPermission(for: target)
                        }
                    )
                }

                // Action buttons
                HStack(spacing: 12) {
                    if !permissions.hasAllCriticalPermissions {
                        Button {
                            Task {
                                await permissions.autoRequestPermissions()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                Text("Request All Permissions")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.vibePurple)
                    }

                    Button("Open System Settings") {
                        permissions.openPrivacySettings()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        SettingsSection(title: "Privacy", icon: "hand.raised") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Data Stays on Your Mac")
                            .font(.headline)
                        Text("Craig-O-Clean stores your settings locally. If you use Sign in with Apple, App Store subscriptions, or Stripe checkout, those providers will handle network requests required for authentication or payments.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("No analytics or tracking", systemImage: "checkmark.circle")
                    Label("No cloud storage for your app data", systemImage: "checkmark.circle")
                    Label("Network only for sign-in / purchases (optional)", systemImage: "checkmark.circle")
                    Label("All processing happens locally", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("View Privacy Policy") {
                    showingPrivacyPolicy = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Diagnostics Section
    
    private var diagnosticsSection: some View {
        SettingsSection(title: "Diagnostics", icon: "wrench.and.screwdriver") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Troubleshooting")
                            .font(.headline)
                        Text("View error logs and export diagnostic information")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("View Diagnostics") {
                        showingDiagnostics = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Settings")
                            .font(.headline)
                        Text("Restore all settings to their default values")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        resetSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - About Section

    private var appIcon: NSImage {
        NSApp.applicationIconImage ?? NSImage(named: "AppIcon") ?? NSImage()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle") {
            HStack(spacing: 16) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Craig-O-Clean")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Version \(appVersion) (Build \(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("A macOS system utility for Apple Silicon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("About") {
                    showingAbout = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetSettings() {
        refreshInterval = 2.0
        showInDock = false
        launchAtLogin = false
        enableNotifications = true
        memoryWarningThreshold = 80.0
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            content()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    var showRestartHint: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Status badge
                    HStack(spacing: 6) {
                        Image(systemName: status.icon)
                            .font(.caption)

                        Text(status.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(12)

                    if status != .granted {
                        Button("Grant") {
                            onRequest()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            // Show hint for Accessibility if denied
            if showRestartHint && status == .denied {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("If already granted in System Settings, try quitting and reopening Craig-O-Clean")
                        .font(.caption2)
                }
                .foregroundColor(.vibeAmber)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.vibeAmber.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return .vibeTeal
        case .denied: return Color(red: 239/255, green: 68/255, blue: 68/255)  // Red
        case .notDetermined: return .vibeAmber
        case .restricted: return Color(red: 251/255, green: 146/255, blue: 60/255)  // Orange
        }
    }
}

struct AutomationPermissionRow: View {
    let target: AutomationTarget
    let onRequest: () -> Void

    var body: some View {
        HStack {
            Text(target.name)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 8) {
                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: target.status.icon)
                        .font(.caption2)

                    Text(target.status.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .cornerRadius(10)

                if target.status != .granted {
                    Button("Request") {
                        onRequest()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch target.status {
        case .granted: return .vibeTeal
        case .denied: return Color(red: 239/255, green: 68/255, blue: 68/255)  // Red
        case .notDetermined: return .vibeAmber
        case .restricted: return Color(red: 251/255, green: 146/255, blue: 60/255)  // Orange
        }
    }
}

struct DiagnosticsSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var diagnosticText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Diagnostics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // System Info
                    GroupBox("System Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            DiagnosticRow(label: "macOS Version", value: Foundation.ProcessInfo.processInfo.operatingSystemVersionString)
                            DiagnosticRow(label: "Processor", value: "Apple Silicon")
                            DiagnosticRow(label: "Physical Memory", value: ByteCountFormatter.string(fromByteCount: Int64(Foundation.ProcessInfo.processInfo.physicalMemory), countStyle: .file))
                            DiagnosticRow(label: "Active Processors", value: "\(Foundation.ProcessInfo.processInfo.activeProcessorCount)")
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // App Info
                    GroupBox("App Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            DiagnosticRow(label: "App Version", value: "1.0 (1)")
                            DiagnosticRow(label: "Bundle ID", value: "com.CraigOClean.controlcenter")
                            DiagnosticRow(label: "Uptime", value: formatUptime())
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Error Log (placeholder)
                    GroupBox("Recent Errors") {
                        Text("No recent errors")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Export button
            HStack {
                Spacer()
                
                Button("Export Diagnostics...") {
                    exportDiagnostics()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 500)
    }
    
    private func formatUptime() -> String {
        let uptime = Foundation.ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "CraigOClean_diagnostics.txt"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            let diagnostics = """
            Craig-O-Clean Diagnostics
            Generated: \(Date())
            
            System Information
            ==================
            macOS: \(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)
            Physical Memory: \(ByteCountFormatter.string(fromByteCount: Int64(Foundation.ProcessInfo.processInfo.physicalMemory), countStyle: .file))
            Processors: \(Foundation.ProcessInfo.processInfo.activeProcessorCount)
            
            App Information
            ================
            Version: 1.0 (1)
            Bundle ID: com.CraigOClean.controlcenter
            """
            
            try? diagnostics.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }
}

struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss

    private var appIcon: NSImage {
        NSApp.applicationIconImage ?? NSImage(named: "AppIcon") ?? NSImage()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 24) {
            // App Icon and title
            VStack(spacing: 12) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                Text("Craig-O-Clean")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A powerful macOS utility for monitoring system resources, managing processes, optimizing memory, and controlling browser tabs. Built for Apple Silicon.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            // Credits
            VStack(spacing: 8) {
                Text("Built with Swift & SwiftUI")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("© 2025 CraigOClean.com powered by VibeCaaS.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 450, height: 420)
    }
}

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Privacy Policy")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Craig-O-Clean Privacy Policy")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Last updated: November 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Collection")
                            .font(.headline)
                        
                        Text("Craig-O-Clean does NOT collect, store, or transmit any personal data or usage information. All data processing happens locally on your Mac.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Access")
                            .font(.headline)
                        
                        Text("The app accesses system information (CPU, memory, processes) solely to display metrics and provide cleanup functionality. This information is never stored or shared.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Browser Integration")
                            .font(.headline)
                        
                        Text("Browser tab information is accessed only when you use the Browser Tabs feature and is never stored or transmitted. Access requires explicit permission via macOS Automation.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Network")
                            .font(.headline)
                        
                        Text("Craig-O-Clean does not run analytics, crash reporting, or tracking. If you choose to sign in or purchase a subscription, network requests are made only for authentication and payments through Apple (and optionally Stripe via your configured backend).")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Questions")
                            .font(.headline)
                        
                        Text("If you have questions about this privacy policy, please contact us through the app's support channels.")
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Preview

#Preview {
    SettingsPermissionsView()
        .environmentObject(SystemMetricsService())
        .environmentObject(PermissionsService())
        .environmentObject(AuthManager.shared)
        .environmentObject(LocalUserStore.shared)
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(StripeCheckoutService.shared)
        .frame(width: 700, height: 800)
}
