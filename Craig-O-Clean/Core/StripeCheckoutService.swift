import Foundation
import AppKit

/// Stripe integration **must** be done via your backend.
/// Do NOT embed Stripe secret keys in the app (they will be extracted).
///
/// Required backend endpoints:
/// - POST /stripe/create-checkout-session - Create a Stripe Checkout session
/// - POST /stripe/create-portal-session - Create a Customer Portal session
/// - GET /stripe/subscription-status/:userId - Get subscription status
/// - POST /stripe/webhook - Handle Stripe webhooks (for subscription updates)
///
/// Pricing Configuration (configure in your Stripe Dashboard):
/// - Monthly: $0.99/month (price_monthly_099)
/// - Yearly: $9.99/year (price_yearly_999)
/// - Both plans include a 7-day free trial
@MainActor
final class StripeCheckoutService: ObservableObject {
    static let shared = StripeCheckoutService()

    @Published private(set) var isBackendConfigured: Bool = false
    @Published private(set) var lastError: StripeError?
    @Published private(set) var isProcessing: Bool = false

    private init() {
        isBackendConfigured = Self.backendBaseURL != nil
    }

    // MARK: - Error Types

    enum StripeError: Error, LocalizedError {
        case backendNotConfigured
        case invalidResponse
        case networkError(String)
        case serverError(Int, String?)
        case checkoutCancelled

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Payment backend not configured. Please contact support."
            case .invalidResponse:
                return "Invalid response from payment server. Please try again."
            case .networkError(let message):
                return "Network error: \(message)"
            case .serverError(let code, let message):
                return "Server error (\(code)): \(message ?? "Unknown error")"
            case .checkoutCancelled:
                return "Checkout was cancelled."
            }
        }
    }

    // MARK: - Stripe Pricing IDs

    /// Stripe Price IDs - these should match your Stripe Dashboard configuration
    struct StripePrices {
        /// Monthly plan: $0.99/month with 7-day free trial
        static let monthlyWithTrial = "price_monthly_099_trial"
        static let monthlyNoTrial = "price_monthly_099"

        /// Yearly plan: $9.99/year with 7-day free trial
        static let yearlyWithTrial = "price_yearly_999_trial"
        static let yearlyNoTrial = "price_yearly_999"

        static func priceId(for plan: SubscriptionPlan, withTrial: Bool) -> String {
            switch (plan, withTrial) {
            case (.monthly, true): return monthlyWithTrial
            case (.monthly, false): return monthlyNoTrial
            case (.yearly, true): return yearlyWithTrial
            case (.yearly, false): return yearlyNoTrial
            }
        }
    }

    // MARK: - Public Properties

    /// Check if the backend is configured and available
    var canCheckout: Bool {
        return Self.backendBaseURL != nil
    }

    // MARK: - Checkout Methods

    /// Opens a Stripe Checkout for a subscription plan with optional trial
    /// - Parameters:
    ///   - plan: The subscription plan (monthly or yearly)
    ///   - userId: User identifier for tracking
    ///   - email: User email for pre-filling checkout
    ///   - includeTrial: Whether to include the 7-day free trial
    func openCheckout(
        plan: SubscriptionPlan,
        userId: String?,
        email: String? = nil,
        includeTrial: Bool = true
    ) async throws {
        let priceId = StripePrices.priceId(for: plan, withTrial: includeTrial)
        try await openCheckout(
            priceId: priceId,
            userId: userId,
            email: email,
            metadata: [
                "plan": plan.rawValue,
                "trial_included": includeTrial ? "true" : "false",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]
        )
    }

    /// Opens a Stripe Checkout URL returned from your backend.
    /// Your backend should create a Checkout Session using your Stripe secret key and return `{ "url": "..." }`.
    func openCheckout(
        priceId: String,
        userId: String?,
        email: String? = nil,
        metadata: [String: String]? = nil
    ) async throws {
        lastError = nil
        isProcessing = true
        defer { isProcessing = false }

        guard let base = Self.backendBaseURL else {
            lastError = .backendNotConfigured
            throw StripeError.backendNotConfigured
        }

        var request = URLRequest(url: base.appendingPathComponent("/stripe/create-checkout-session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var payload: [String: Any] = [
            "priceId": priceId,
            "successUrl": "craigoclean://stripe/success",
            "cancelUrl": "craigoclean://stripe/cancel"
        ]

        if let userId = userId {
            payload["userId"] = userId
        }
        if let email = email {
            payload["customerEmail"] = email
        }
        if let metadata = metadata {
            payload["metadata"] = metadata
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    let errorMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let message = errorMessage?["error"] as? String
                    let error = StripeError.serverError(httpResponse.statusCode, message)
                    lastError = error
                    throw error
                }
            }

            guard
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let urlString = obj["url"] as? String,
                let url = URL(string: urlString)
            else {
                lastError = .invalidResponse
                throw StripeError.invalidResponse
            }

            AppLogger.shared.info("Opening Stripe checkout for price: \(priceId)")
            NSWorkspace.shared.open(url)

        } catch let error as StripeError {
            throw error
        } catch {
            let stripeError = StripeError.networkError(error.localizedDescription)
            lastError = stripeError
            throw stripeError
        }
    }

    /// Legacy method for backward compatibility
    func openCheckout(planId: String, userId: String?) async throws {
        // Map legacy planId to new plan system
        let plan: SubscriptionPlan = planId.contains("yearly") ? .yearly : .monthly
        try await openCheckout(plan: plan, userId: userId)
    }

    // MARK: - Customer Portal

    /// Opens the Stripe Customer Portal for managing subscriptions
    func openCustomerPortal(customerId: String) async throws {
        lastError = nil
        isProcessing = true
        defer { isProcessing = false }

        guard let base = Self.backendBaseURL else {
            lastError = .backendNotConfigured
            throw StripeError.backendNotConfigured
        }

        var request = URLRequest(url: base.appendingPathComponent("/stripe/create-portal-session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let payload: [String: Any] = [
            "customerId": customerId,
            "returnUrl": "craigoclean://stripe/portal-return"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let error = StripeError.serverError(httpResponse.statusCode, nil)
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

            AppLogger.shared.info("Opening Stripe customer portal")
            NSWorkspace.shared.open(url)

        } catch let error as StripeError {
            throw error
        } catch {
            let stripeError = StripeError.networkError(error.localizedDescription)
            lastError = stripeError
            throw stripeError
        }
    }

    // MARK: - Subscription Status

    /// Check subscription status from backend
    func checkSubscriptionStatus(userId: String) async throws -> StripeSubscriptionStatus? {
        guard let base = Self.backendBaseURL else { return nil }

        var request = URLRequest(url: base.appendingPathComponent("/stripe/subscription-status/\(userId)"))
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                return nil  // No subscription found
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return nil
            }

            let status = try JSONDecoder().decode(StripeSubscriptionStatus.self, from: data)
            return status
        } catch {
            AppLogger.shared.error("Failed to check Stripe subscription status: \(error)")
            return nil
        }
    }

    // MARK: - Backend Health Check

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

    // MARK: - Private Helpers

    private static var backendBaseURL: URL? {
        if let s = Bundle.main.object(forInfoDictionaryKey: "StripeBackendBaseURL") as? String,
           let url = URL(string: s),
           !s.isEmpty {
            return url
        }
        return nil
    }
}

// MARK: - Stripe Subscription Status Model

struct StripeSubscriptionStatus: Codable {
    let customerId: String
    let subscriptionId: String?
    let status: String  // active, trialing, past_due, canceled, etc.
    let plan: String?
    let currentPeriodEnd: Date?
    let cancelAtPeriodEnd: Bool
    let trialEnd: Date?

    var isActive: Bool {
        return status == "active" || status == "trialing"
    }

    var isInTrial: Bool {
        return status == "trialing"
    }

    var subscriptionPlan: SubscriptionPlan? {
        guard let plan = plan else { return nil }
        if plan.contains("yearly") { return .yearly }
        if plan.contains("monthly") { return .monthly }
        return nil
    }
}

// MARK: - URL Scheme Handler Extension

extension StripeCheckoutService {
    /// Handle callback URLs from Stripe Checkout
    /// Call this from your AppDelegate's application(_:open:) method
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "craigoclean",
              url.host == "stripe" else { return false }

        let path = url.path

        Task { @MainActor in
            switch path {
            case "/success":
                AppLogger.shared.info("Stripe checkout completed successfully")
                // Refresh subscription status
                await SubscriptionManager.shared.refreshEntitlements()
                TrialManager.shared.refreshTrialStatus()

                // Post notification for UI updates
                NotificationCenter.default.post(name: .stripeCheckoutCompleted, object: nil)

            case "/cancel":
                AppLogger.shared.info("Stripe checkout was cancelled")
                lastError = .checkoutCancelled

            case "/portal-return":
                AppLogger.shared.info("Returned from Stripe customer portal")
                // Refresh subscription status
                await SubscriptionManager.shared.refreshEntitlements()
                TrialManager.shared.refreshTrialStatus()

            default:
                break
            }
        }

        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let stripeCheckoutCompleted = Notification.Name("stripeCheckoutCompleted")
    static let stripeSubscriptionUpdated = Notification.Name("stripeSubscriptionUpdated")
}

