import SwiftUI
import AuthenticationServices

struct AccountSettingsView: View {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var profileService = UserProfileService.shared
    @State private var showSignUpSheet = false
    @State private var showImagePicker = false
    @State private var selectedImage: NSImage?
    @State private var isEditingProfile = false

    var body: some View {
        Form {
            if let profile = profileService.currentProfile {
                // Signed In View
                SignedInView(
                    profile: profile,
                    showImagePicker: $showImagePicker,
                    selectedImage: $selectedImage,
                    isEditingProfile: $isEditingProfile
                )
            } else {
                // Sign In / Sign Up View
                SignInView(showSignUpSheet: $showSignUpSheet)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showSignUpSheet) {
            SignUpSheet()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task {
                    await profileService.updateAvatar(image)
                }
            }
        }
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @Binding var showSignUpSheet: Bool

    var body: some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Sign in to sync your settings")
                    .font(.headline)

                Text("Your settings and preferences will be synced across all your devices using iCloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        await handleSignInWithApple(result)
                    }
                }
                .frame(height: 44)
                .cornerRadius(8)

                Divider()

                Button {
                    showSignUpSheet = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Sign Up with Email")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
        } header: {
            Text("Account")
        }
    }

    @MainActor
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Create profile from Apple Sign In
                let fullName = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName
                ].compactMap { $0 }.joined(separator: " ")

                await UserProfileService.shared.createProfile(
                    email: credential.email ?? "apple.id.\(credential.user)@privaterelay.appleid.com",
                    fullName: fullName.isEmpty ? "User" : fullName
                )
            }

        case .failure(let error):
            print("Sign in failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Signed In View

struct SignedInView: View {
    let profile: UserProfile
    @Binding var showImagePicker: Bool
    @Binding var selectedImage: NSImage?
    @Binding var isEditingProfile: Bool
    @StateObject private var profileService = UserProfileService.shared
    @State private var showConfirmSignOut = false
    @State private var editedFullName: String = ""
    @State private var editedEmail: String = ""

    var body: some View {
        Section {
            HStack {
                // Avatar
                Button {
                    showImagePicker = true
                } label: {
                    if let avatarData = profile.avatarImageData,
                       let nsImage = NSImage(data: avatarData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)

                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                            }
                            .frame(width: 80, height: 80)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    if isEditingProfile {
                        TextField("Full Name", text: $editedFullName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Email", text: $editedEmail)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(profile.fullName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(profile.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundStyle(.green)
                        Text("Synced to iCloud")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isEditingProfile {
                    Button("Save") {
                        Task {
                            await profileService.updateProfile(
                                fullName: editedFullName,
                                email: editedEmail
                            )
                            isEditingProfile = false
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        isEditingProfile = false
                    }
                } else {
                    Button {
                        editedFullName = profile.fullName
                        editedEmail = profile.email
                        isEditingProfile = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Profile")
        }

        Section {
            LabeledContent("Account ID") {
                Text(profile.id.prefix(8) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Created") {
                Text(profile.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Last Updated") {
                Text(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Account Information")
        }

        Section {
            Button {
                Task {
                    await profileService.syncPreferencesFromAppStorage()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise.icloud")
                    Text("Sync Settings to iCloud")
                }
            }

            Button {
                profileService.applyPreferencesToAppStorage()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.to.line.circle")
                    Text("Restore Settings from iCloud")
                }
            }
        } header: {
            Text("Settings Sync")
        } footer: {
            Text("Sync your preferences across all devices. Settings are automatically synced when changed.")
        }

        Section {
            Button {
                showConfirmSignOut = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .foregroundStyle(.red)
            }
        }
        .alert("Sign Out", isPresented: $showConfirmSignOut) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await profileService.deleteProfile()
                }
            }
        } message: {
            Text("Are you sure you want to sign out? Your settings will remain synced in iCloud.")
        }
    }
}

// MARK: - Sign Up Sheet

struct SignUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileService = UserProfileService.shared

    @State private var fullName = ""
    @State private var email = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Start syncing your settings across all devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("John Doe", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("john@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 40)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    Task { await createAccount() }
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isCreating ? "Creating Account..." : "Create Account")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(fullName.isEmpty || email.isEmpty || isCreating)

                Button("Cancel") {
                    dismiss()
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(width: 400, height: 500)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    private func createAccount() async {
        // Validate email
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }

        isCreating = true

        await profileService.createProfile(email: email, fullName: fullName)

        isCreating = false
        dismiss()
    }
}

// MARK: - Image Picker

struct ImagePicker: NSViewRepresentable {
    @Binding var image: NSImage?
    @Environment(\.dismiss) private var dismiss

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let loadedImage = NSImage(contentsOf: url) {
                    self.image = loadedImage
                }
            }
            dismiss()
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Preview

#Preview {
    AccountSettingsView()
}
