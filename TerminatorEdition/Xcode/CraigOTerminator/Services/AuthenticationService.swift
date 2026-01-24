import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Authentication Service
/// Handles Apple Sign In and user authentication

@MainActor
final class AuthenticationService: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = AuthenticationService()

    // MARK: - Published Properties

    @Published var isSignedIn = false
    @Published var userIdentifier: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var authorizationError: String?

    // MARK: - Private Properties

    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let userDefaults = UserDefaults.standard

    // Keys for storage
    private enum StorageKey {
        static let userIdentifier = "userIdentifier"
        static let userName = "userName"
        static let userEmail = "userEmail"
        static let isSignedIn = "isSignedIn"
    }

    // MARK: - Initialization

    private override init() {
        super.init()

        // Setup iCloud notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // Sync on launch
        iCloudStore.synchronize()

        // Load saved credentials
        loadSavedCredentials()
    }

    // MARK: - Sign In

    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // MARK: - Sign Out

    func signOut() {
        isSignedIn = false
        userIdentifier = nil
        userName = nil
        userEmail = nil

        // Clear local storage
        userDefaults.removeObject(forKey: StorageKey.userIdentifier)
        userDefaults.removeObject(forKey: StorageKey.userName)
        userDefaults.removeObject(forKey: StorageKey.userEmail)
        userDefaults.set(false, forKey: StorageKey.isSignedIn)

        // Clear iCloud storage
        iCloudStore.removeObject(forKey: StorageKey.userIdentifier)
        iCloudStore.removeObject(forKey: StorageKey.userName)
        iCloudStore.removeObject(forKey: StorageKey.userEmail)
        iCloudStore.set(false, forKey: StorageKey.isSignedIn)
        iCloudStore.synchronize()
    }

    // MARK: - iCloud Sync

    /// Sync settings to iCloud
    func syncSettingsToiCloud(_ settings: [String: Any]) {
        for (key, value) in settings {
            iCloudStore.set(value, forKey: key)
        }
        iCloudStore.synchronize()
    }

    /// Get setting from iCloud
    func getSettingFromiCloud(key: String) -> Any? {
        return iCloudStore.object(forKey: key)
    }

    /// Sync all app settings to iCloud
    func syncAllSettingsToiCloud() {
        // Get all UserDefaults
        guard let domain = Bundle.main.bundleIdentifier,
              let defaults = UserDefaults.standard.persistentDomain(forName: domain) else {
            return
        }

        // Sync to iCloud
        for (key, value) in defaults {
            // Skip sensitive keys
            if !key.contains("password") && !key.contains("token") && !key.contains("secret") {
                iCloudStore.set(value, forKey: "app_\(key)")
            }
        }

        iCloudStore.synchronize()
    }

    /// Restore settings from iCloud
    func restoreSettingsFromiCloud() {
        let keys = iCloudStore.dictionaryRepresentation.keys.filter { $0.hasPrefix("app_") }

        for key in keys {
            if let value = iCloudStore.object(forKey: key) {
                let actualKey = String(key.dropFirst(4)) // Remove "app_" prefix
                userDefaults.set(value, forKey: actualKey)
            }
        }

        userDefaults.synchronize()
    }

    // MARK: - Private Methods

    private func loadSavedCredentials() {
        isSignedIn = userDefaults.bool(forKey: StorageKey.isSignedIn)
        userIdentifier = userDefaults.string(forKey: StorageKey.userIdentifier)
        userName = userDefaults.string(forKey: StorageKey.userName)
        userEmail = userDefaults.string(forKey: StorageKey.userEmail)

        // Also check iCloud
        if let cloudSignedIn = iCloudStore.object(forKey: StorageKey.isSignedIn) as? Bool,
           cloudSignedIn {
            isSignedIn = true

            if let cloudUserId = iCloudStore.string(forKey: StorageKey.userIdentifier) {
                userIdentifier = cloudUserId
            }
            if let cloudUserName = iCloudStore.string(forKey: StorageKey.userName) {
                userName = cloudUserName
            }
            if let cloudUserEmail = iCloudStore.string(forKey: StorageKey.userEmail) {
                userEmail = cloudUserEmail
            }
        }
    }

    private func saveCredentials() {
        // Save to UserDefaults
        userDefaults.set(isSignedIn, forKey: StorageKey.isSignedIn)
        userDefaults.set(userIdentifier, forKey: StorageKey.userIdentifier)
        userDefaults.set(userName, forKey: StorageKey.userName)
        userDefaults.set(userEmail, forKey: StorageKey.userEmail)
        userDefaults.synchronize()

        // Save to iCloud
        iCloudStore.set(isSignedIn, forKey: StorageKey.isSignedIn)
        iCloudStore.set(userIdentifier, forKey: StorageKey.userIdentifier)
        iCloudStore.set(userName, forKey: StorageKey.userName)
        iCloudStore.set(userEmail, forKey: StorageKey.userEmail)
        iCloudStore.synchronize()
    }

    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        // Reload credentials when iCloud data changes
        loadSavedCredentials()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authorizationError = "Invalid credential"
            return
        }

        // Save user information
        userIdentifier = credential.user

        if let fullName = credential.fullName {
            let components = [fullName.givenName, fullName.familyName].compactMap { $0 }
            userName = components.joined(separator: " ")
        }

        if let email = credential.email {
            userEmail = email
        }

        isSignedIn = true
        saveCredentials()

        // Auto-sync settings after sign in
        syncAllSettingsToiCloud()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        authorizationError = error.localizedDescription
    }
}
