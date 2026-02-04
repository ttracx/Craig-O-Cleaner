//
//  UpgradeService.swift
//  Craig-O-Clean Lite
//
//  Handles Stripe checkout and upgrade flow
//

import Foundation
import AppKit
import UserNotifications

class UpgradeService: ObservableObject {
    @Published var isProcessingUpgrade = false
    @Published var upgradeError: String?

    // Stripe Configuration
    // PRODUCTION: Update these URLs after deploying backend
    private let stripeCheckoutURL = "https://pay.craigoapps.com/b/7sYeVd4rb6rIbcxbj95AQ00" // From Stripe Payment Links
    private let licenseValidationURL = "https://craigoclean.com/api/license/validate"
    private let downloadURL = "https://craigoclean.com/api/download"

    // Pricing
    struct Pricing {
        static let upgradePrice = "$0.99"
        static let lifetimeAccess = true
        static let features = [
            "Browser Tab Management (Safari, Chrome, Edge, Brave, Arc)",
            "Advanced Process Control & Force Quit",
            "Smart Memory Cleanup with Categories",
            "Detailed System Metrics & Monitoring",
            "Customizable Settings & Preferences",
            "CSV Export & Process History",
            "Priority Email Support",
            "Lifetime Updates"
        ]
    }

    /// Opens Stripe checkout in default browser
    func startUpgradeFlow(email: String? = nil) {
        isProcessingUpgrade = true
        upgradeError = nil

        var checkoutURL = stripeCheckoutURL

        // Add email prefill if provided
        if let email = email, !email.isEmpty {
            if let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                checkoutURL += "?prefilled_email=\(encodedEmail)"
            }
        }

        // Add client reference for tracking
        let clientRef = UUID().uuidString
        checkoutURL += checkoutURL.contains("?") ? "&" : "?"
        checkoutURL += "client_reference_id=\(clientRef)"

        // Save reference for later validation
        UserDefaults.standard.set(clientRef, forKey: "upgrade_client_reference")

        // Open Stripe checkout
        if let url = URL(string: checkoutURL) {
            NSWorkspace.shared.open(url)

            // Start polling for payment completion
            startPaymentPolling(clientRef: clientRef)
        } else {
            upgradeError = "Invalid checkout URL"
            isProcessingUpgrade = false
        }
    }

    /// Polls backend to check if payment completed
    private func startPaymentPolling(clientRef: String) {
        var attempts = 0
        let maxAttempts = 60 // Poll for 5 minutes (5s intervals)

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            attempts += 1

            // Check payment status
            self.checkPaymentStatus(clientRef: clientRef) { success, licenseKey in
                if success, let licenseKey = licenseKey {
                    timer.invalidate()
                    self.handleSuccessfulUpgrade(licenseKey: licenseKey)
                } else if attempts >= maxAttempts {
                    timer.invalidate()
                    self.isProcessingUpgrade = false
                    self.upgradeError = "Payment verification timed out. Please check your email for the download link."
                }
            }
        }
    }

    /// Check payment status from backend
    private func checkPaymentStatus(clientRef: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(licenseValidationURL)?client_ref=\(clientRef)"
        guard let url = URL(string: urlString) else {
            completion(false, nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let paid = json["paid"] as? Bool,
                  paid else {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
                return
            }

            let licenseKey = json["license_key"] as? String
            DispatchQueue.main.async {
                completion(true, licenseKey)
            }
        }.resume()
    }

    /// Handle successful upgrade
    private func handleSuccessfulUpgrade(licenseKey: String) {
        // Save license key
        KeychainHelper.save(key: "craig_o_clean_license_key", value: licenseKey)

        // Trigger download
        triggerFullVersionDownload()

        isProcessingUpgrade = false

        // Show success notification
        showSuccessNotification()
    }

    /// Trigger download of full version
    private func triggerFullVersionDownload() {
        guard let url = URL(string: downloadURL) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Show success notification
    private func showSuccessNotification() {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Upgrade Successful!"
            content.body = "Craig-O-Clean Full is downloading. Check your Downloads folder."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }

    /// Validate existing license key
    func validateLicense(completion: @escaping (Bool) -> Void) {
        guard let licenseKey = KeychainHelper.get(key: "craig_o_clean_license_key") else {
            completion(false)
            return
        }

        let urlString = "\(licenseValidationURL)?license_key=\(licenseKey)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            DispatchQueue.main.async {
                completion(valid)
            }
        }.resume()
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
