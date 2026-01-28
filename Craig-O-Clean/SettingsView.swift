import SwiftUI

struct SettingsView: View {
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @State private var avatarManager = AvatarManager.shared
    @State private var showingAvatarPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            headerView
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(spacing: 20) {
                    // User Profile section
                    userProfileSection

                    // Launch at Login section
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
                    
                    // About section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            // App logo (replace "AppLogo" with your asset name if different)
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
                            if UIImage(named: "AppIcon") != nil {
                                Image("AppIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                    )
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 90, height: 90)
                                    .foregroundColor(.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                    )
                                    .accessibilityHidden(true)
                            }
        #endif
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Craig-O-Clean")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)

                                Text(Bundle.main.displayVersion)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Features section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Real-time memory monitoring", systemImage: "chart.bar.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("One-click memory optimization", systemImage: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("Process management and termination", systemImage: "terminal.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            // Footer with Quit button and copyright
            footerView
        }
        .frame(width: 440, height: 600)
        .alert("Avatar Upload", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
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

    private var userProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Profile")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                // Avatar display
                if let avatarImage = avatarManager.avatarImage {
                    Image(nsImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                } else {
                    // Default avatar
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        selectAvatar()
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text(avatarManager.avatarImage == nil ? "Upload Avatar" : "Change Avatar")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    if avatarManager.avatarImage != nil {
                        Button(action: {
                            deleteAvatar()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Avatar")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }

                    Text("Synced with iCloud")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Text("Upload a profile picture. Your avatar will be saved locally and synced across your devices via iCloud.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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
            
            // Copyright notice - VibeCaaS branding
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

    // MARK: - Avatar Actions

    private func selectAvatar() {
        avatarManager.selectAvatarImage { result in
            switch result {
            case .success(let imageData):
                Task {
                    do {
                        try await avatarManager.saveAvatar(imageData)
                        await MainActor.run {
                            alertMessage = "Avatar uploaded successfully and synced to iCloud."
                            showingAlert = true
                        }
                    } catch {
                        await MainActor.run {
                            alertMessage = "Failed to save avatar: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                }
            case .failure(let error):
                if case AvatarError.userCancelled = error {
                    // User cancelled, no alert needed
                    return
                }
                alertMessage = "Failed to select image: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    private func deleteAvatar() {
        avatarManager.deleteAvatar()
        alertMessage = "Avatar removed successfully."
        showingAlert = true
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

