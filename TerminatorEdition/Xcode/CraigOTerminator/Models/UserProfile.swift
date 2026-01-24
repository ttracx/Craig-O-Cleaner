import Foundation
import SwiftUI

// MARK: - User Profile Model

struct UserProfile: Codable {
    var id: String
    var email: String
    var fullName: String
    var avatarImageData: Data?
    var preferences: UserPreferences
    var createdAt: Date
    var updatedAt: Date

    struct UserPreferences: Codable {
        var autonomousMode: Bool
        var memoryThreshold: Double
        var diskThreshold: Double
        var checkInterval: Double
        var showNotifications: Bool
        var launchAtLogin: Bool
        var ollamaEnabled: Bool
        var ollamaHost: String
        var ollamaPort: Int
        var ollamaModel: String

        static var `default`: UserPreferences {
            UserPreferences(
                autonomousMode: false,
                memoryThreshold: 85.0,
                diskThreshold: 90.0,
                checkInterval: 300.0,
                showNotifications: true,
                launchAtLogin: false,
                ollamaEnabled: false,
                ollamaHost: "localhost",
                ollamaPort: 11434,
                ollamaModel: "llama3.2"
            )
        }
    }

    init(
        id: String,
        email: String,
        fullName: String,
        avatarImageData: Data? = nil,
        preferences: UserPreferences = .default
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarImageData = avatarImageData
        self.preferences = preferences
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - User Profile Service

@MainActor
final class UserProfileService: ObservableObject {

    // MARK: - Singleton

    static let shared = UserProfileService()

    // MARK: - Published Properties

    @Published var currentProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let fileManager = FileManager.default

    private enum StorageKey {
        static let userProfile = "userProfile"
        static let avatarData = "avatarData"
    }

    // MARK: - File Paths

    private var localProfilePath: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CraigOTerminator")

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        return appDir.appendingPathComponent("userProfile.json")
    }

    private var localAvatarPath: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CraigOTerminator")

        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        return appDir.appendingPathComponent("avatar.jpg")
    }

    // MARK: - Initialization

    private init() {
        // Setup iCloud notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // Load profile on init
        Task {
            await loadProfile()
        }
    }

    // MARK: - Profile Management

    func createProfile(email: String, fullName: String) async {
        isLoading = true

        let profile = UserProfile(
            id: UUID().uuidString,
            email: email,
            fullName: fullName
        )

        currentProfile = profile
        await saveProfile()

        isLoading = false
    }

    func updateProfile(
        fullName: String? = nil,
        email: String? = nil,
        preferences: UserProfile.UserPreferences? = nil
    ) async {
        guard var profile = currentProfile else { return }

        isLoading = true

        if let fullName = fullName {
            profile.fullName = fullName
        }

        if let email = email {
            profile.email = email
        }

        if let preferences = preferences {
            profile.preferences = preferences
        }

        profile.updatedAt = Date()
        currentProfile = profile

        await saveProfile()
        isLoading = false
    }

    func updateAvatar(_ image: NSImage) async {
        guard var profile = currentProfile else { return }

        isLoading = true

        // Convert NSImage to JPEG data
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {

            profile.avatarImageData = jpegData
            profile.updatedAt = Date()
            currentProfile = profile

            // Save avatar locally
            try? jpegData.write(to: localAvatarPath)

            // Save to iCloud
            await saveProfile()
        }

        isLoading = false
    }

    func deleteProfile() async {
        isLoading = true

        currentProfile = nil

        // Delete local files
        try? fileManager.removeItem(at: localProfilePath)
        try? fileManager.removeItem(at: localAvatarPath)

        // Delete from iCloud
        iCloudStore.removeObject(forKey: StorageKey.userProfile)
        iCloudStore.removeObject(forKey: StorageKey.avatarData)
        iCloudStore.synchronize()

        isLoading = false
    }

    // MARK: - Persistence

    func saveProfile() async {
        guard let profile = currentProfile else { return }

        do {
            // Save to local storage
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)

            try data.write(to: localProfilePath)

            // Save to iCloud (excluding image data for size)
            var cloudProfile = profile
            cloudProfile.avatarImageData = nil
            let cloudData = try encoder.encode(cloudProfile)

            if let jsonString = String(data: cloudData, encoding: .utf8) {
                iCloudStore.set(jsonString, forKey: StorageKey.userProfile)
            }

            // Save avatar separately to iCloud if it exists
            if let avatarData = profile.avatarImageData {
                // Compress avatar for iCloud (max 64KB)
                if avatarData.count > 65536 {
                    // Re-compress if too large
                    if let image = NSImage(data: avatarData),
                       let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let compressedData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5]),
                       compressedData.count <= 65536 {
                        iCloudStore.set(compressedData, forKey: StorageKey.avatarData)
                    }
                } else {
                    iCloudStore.set(avatarData, forKey: StorageKey.avatarData)
                }
            }

            iCloudStore.synchronize()

        } catch {
            self.error = "Failed to save profile: \(error.localizedDescription)"
        }
    }

    func loadProfile() async {
        isLoading = true

        // Try loading from local storage first
        if fileManager.fileExists(atPath: localProfilePath.path) {
            do {
                let data = try Data(contentsOf: localProfilePath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                var profile = try decoder.decode(UserProfile.self, from: data)

                // Load avatar from local storage
                if fileManager.fileExists(atPath: localAvatarPath.path) {
                    profile.avatarImageData = try? Data(contentsOf: localAvatarPath)
                }

                currentProfile = profile

            } catch {
                self.error = "Failed to load profile: \(error.localizedDescription)"
            }
        }

        // Also check iCloud for updates
        if let cloudProfileString = iCloudStore.string(forKey: StorageKey.userProfile),
           let cloudData = cloudProfileString.data(using: .utf8) {

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                var cloudProfile = try decoder.decode(UserProfile.self, from: cloudData)

                // Check if cloud profile is newer
                if let localProfile = currentProfile {
                    if cloudProfile.updatedAt > localProfile.updatedAt {
                        // Cloud is newer, use it

                        // Get avatar from iCloud
                        if let avatarData = iCloudStore.data(forKey: StorageKey.avatarData) {
                            cloudProfile.avatarImageData = avatarData
                        }

                        currentProfile = cloudProfile

                        // Save cloud version locally
                        await saveProfile()
                    }
                } else {
                    // No local profile, use cloud
                    if let avatarData = iCloudStore.data(forKey: StorageKey.avatarData) {
                        cloudProfile.avatarImageData = avatarData
                    }

                    currentProfile = cloudProfile
                    await saveProfile()
                }

            } catch {
                self.error = "Failed to load cloud profile: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    // MARK: - Sync Preferences

    func syncPreferencesFromAppStorage() async {
        guard var profile = currentProfile else { return }

        // Get current AppStorage values
        let userDefaults = UserDefaults.standard

        profile.preferences = UserProfile.UserPreferences(
            autonomousMode: userDefaults.bool(forKey: "autonomousMode"),
            memoryThreshold: userDefaults.double(forKey: "memoryThreshold"),
            diskThreshold: userDefaults.double(forKey: "diskThreshold"),
            checkInterval: userDefaults.double(forKey: "checkInterval"),
            showNotifications: userDefaults.bool(forKey: "showNotifications"),
            launchAtLogin: userDefaults.bool(forKey: "launchAtLogin"),
            ollamaEnabled: userDefaults.bool(forKey: "ollamaEnabled"),
            ollamaHost: userDefaults.string(forKey: "ollamaHost") ?? "localhost",
            ollamaPort: userDefaults.integer(forKey: "ollamaPort"),
            ollamaModel: userDefaults.string(forKey: "ollamaModel") ?? "llama3.2"
        )

        profile.updatedAt = Date()
        currentProfile = profile

        await saveProfile()
    }

    func applyPreferencesToAppStorage() {
        guard let profile = currentProfile else { return }

        let userDefaults = UserDefaults.standard

        userDefaults.set(profile.preferences.autonomousMode, forKey: "autonomousMode")
        userDefaults.set(profile.preferences.memoryThreshold, forKey: "memoryThreshold")
        userDefaults.set(profile.preferences.diskThreshold, forKey: "diskThreshold")
        userDefaults.set(profile.preferences.checkInterval, forKey: "checkInterval")
        userDefaults.set(profile.preferences.showNotifications, forKey: "showNotifications")
        userDefaults.set(profile.preferences.launchAtLogin, forKey: "launchAtLogin")
        userDefaults.set(profile.preferences.ollamaEnabled, forKey: "ollamaEnabled")
        userDefaults.set(profile.preferences.ollamaHost, forKey: "ollamaHost")
        userDefaults.set(profile.preferences.ollamaPort, forKey: "ollamaPort")
        userDefaults.set(profile.preferences.ollamaModel, forKey: "ollamaModel")

        userDefaults.synchronize()
    }

    // MARK: - Private

    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        Task {
            await loadProfile()
        }
    }
}
