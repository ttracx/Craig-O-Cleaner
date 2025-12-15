import Foundation
import AppKit

/// Stripe integration **must** be done via your backend.
/// Do NOT embed Stripe secret keys in the app (they will be extracted).
@MainActor
final class StripeCheckoutService: ObservableObject {
    static let shared = StripeCheckoutService()

    @Published private(set) var isBackendConfigured: Bool = false
    @Published private(set) var lastError: StripeError?

    private init() {
        isBackendConfigured = Self.backendBaseURL != nil
    }

    enum StripeError: Error, LocalizedError {
        case backendNotConfigured
        case invalidResponse
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Payment backend not configured. Please contact support."
            case .invalidResponse:
                return "Invalid response from payment server. Please try again."
            case .networkError(let message):
                return "Network error: \(message)"
            }
        }
    }

    /// Check if the backend is configured and available
    var canCheckout: Bool {
        return Self.backendBaseURL != nil
    }

    /// Opens a Stripe Checkout URL returned from your backend.
    /// Your backend should create a Checkout Session using your Stripe secret key and return `{ "url": "..." }`.
    func openCheckout(planId: String, userId: String?) async throws {
        lastError = nil

        guard let base = Self.backendBaseURL else {
            lastError = .backendNotConfigured
            throw StripeError.backendNotConfigured
        }

        var request = URLRequest(url: base.appendingPathComponent("/stripe/create-checkout-session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let payload: [String: Any?] = [
            "planId": planId,
            "userId": userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 }, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let error = StripeError.networkError("Server returned status \(httpResponse.statusCode)")
                lastError = error
                throw error
            }

            guard
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let urlString = obj["url"] as? String,
                let url = URL(string: urlString)
            else {
                lastError = .invalidResponse
                throw StripeError.invalidResponse
            }

            NSWorkspace.shared.open(url)
        } catch let error as StripeError {
            throw error
        } catch {
            let stripeError = StripeError.networkError(error.localizedDescription)
            lastError = stripeError
            throw stripeError
        }
    }

    /// Check if backend is reachable (optional health check endpoint)
    func checkBackendAvailability() async -> Bool {
        guard let base = Self.backendBaseURL else { return false }

        do {
            var request = URLRequest(url: base.appendingPathComponent("/health"))
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private static var backendBaseURL: URL? {
        if let s = Bundle.main.object(forInfoDictionaryKey: "StripeBackendBaseURL") as? String,
           let url = URL(string: s),
           !s.isEmpty {
            return url
        }
        return nil
    }
}

