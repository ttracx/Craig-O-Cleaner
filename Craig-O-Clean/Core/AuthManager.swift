import Foundation
import AuthenticationServices

@MainActor
final class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var userId: String?

    private let keychain = KeychainService.shared
    private let keychainServiceName = "Craig-O-Clean.Auth"
    private let userIdAccount = "apple_user_id"

    private override init() {
        super.init()
        restoreSession()
    }

    func restoreSession() {
        do {
            let storedUserId = try keychain.getString(service: keychainServiceName, account: userIdAccount)
            userId = storedUserId
            isSignedIn = storedUserId != nil
        } catch {
            userId = nil
            isSignedIn = false
        }
    }

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        let newUserId = credential.user
        userId = newUserId
        isSignedIn = true

        do {
            try keychain.setString(newUserId, service: keychainServiceName, account: userIdAccount)
        } catch {
            print("AuthManager: failed to persist user id in keychain: \(error)")
        }
    }

    func signOut() {
        do { try keychain.delete(service: keychainServiceName, account: userIdAccount) } catch {}
        userId = nil
        isSignedIn = false
    }
}

