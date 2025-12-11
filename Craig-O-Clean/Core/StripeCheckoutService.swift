import Foundation
import AppKit

/// Stripe integration **must** be done via your backend.
/// Do NOT embed Stripe secret keys in the app (they will be extracted).
@MainActor
final class StripeCheckoutService: ObservableObject {
    static let shared = StripeCheckoutService()

    private init() {}

    enum StripeError: Error {
        case backendNotConfigured
        case invalidResponse
    }

    /// Opens a Stripe Checkout URL returned from your backend.
    /// Your backend should create a Checkout Session using your Stripe secret key and return `{ "url": "..." }`.
    func openCheckout(planId: String, userId: String?) async throws {
        guard let base = Self.backendBaseURL else { throw StripeError.backendNotConfigured }

        var request = URLRequest(url: base.appendingPathComponent("/stripe/create-checkout-session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any?] = [
            "planId": planId,
            "userId": userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 }, options: [])

        let (data, _) = try await URLSession.shared.data(for: request)
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let urlString = obj["url"] as? String,
            let url = URL(string: urlString)
        else {
            throw StripeError.invalidResponse
        }

        NSWorkspace.shared.open(url)
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

