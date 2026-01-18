import Foundation
import Security

/// Minimal Keychain wrapper for small secrets (tokens/identifiers).
final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    func setString(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)

        // Upsert pattern: delete first, then add.
        try? delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func getString(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data else { throw KeychainError.invalidData }
        return String(data: data, encoding: .utf8)
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Convenience Methods

    /// Default service name for simple key-value storage
    private static let defaultService = "com.craigoclean.app"

    /// Store a string value with a simple key (uses default service)
    func store(string value: String, for key: String) {
        try? setString(value, service: Self.defaultService, account: key)
    }

    /// Retrieve a string value by key (uses default service)
    func retrieveString(for key: String) -> String? {
        try? getString(service: Self.defaultService, account: key)
    }

    /// Delete a value by key (uses default service)
    func delete(for key: String) {
        try? delete(service: Self.defaultService, account: key)
    }
}

