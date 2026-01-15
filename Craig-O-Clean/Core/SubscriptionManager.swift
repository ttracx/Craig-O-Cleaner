import Foundation
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @AppStorage("isProCached") private var isProCached: Bool = false
    @Published private(set) var isPro: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastErrorMessage: String?

    /// Current subscription details from App Store
    @Published private(set) var currentSubscription: CurrentSubscription?

    private var updatesTask: Task<Void, Never>?

    // MARK: - Subscription Details

    struct CurrentSubscription {
        let productId: String
        let plan: SubscriptionPlan
        let expirationDate: Date?
        let isAutoRenewing: Bool
        let purchaseDate: Date

        var isExpired: Bool {
            guard let expiry = expirationDate else { return false }
            return Date() > expiry
        }
    }

    private init() {
        // Fast startup: use cached value, then refresh.
        isPro = isProCached

        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in Transaction.updates {
                await self.refreshEntitlements()
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ids = Self.productIDs()
            products = try await Product.products(for: ids).sorted { sortOrder($0) < sortOrder($1) }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Failed to load products."
            products = []
        }
    }

    /// Sort products: yearly first (better value), then monthly
    private func sortOrder(_ product: Product) -> Int {
        if product.id.contains("yearly") { return 0 }
        if product.id.contains("monthly") { return 1 }
        return 2
    }

    func refreshEntitlements() async {
        var hasPro = false
        var subscription: CurrentSubscription?
        let ids = Set(Self.productIDs())

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ids.contains(transaction.productID) else { continue }

            // Determine plan from product ID
            let plan: SubscriptionPlan = transaction.productID.contains("yearly") ? .yearly : .monthly

            subscription = CurrentSubscription(
                productId: transaction.productID,
                plan: plan,
                expirationDate: transaction.expirationDate,
                isAutoRenewing: transaction.revocationDate == nil,
                purchaseDate: transaction.purchaseDate
            )

            hasPro = true
            break
        }

        isPro = hasPro
        isProCached = hasPro
        currentSubscription = subscription

        // Notify TrialManager of subscription status change
        if hasPro, let sub = subscription {
            await MainActor.run {
                TrialManager.shared.handleSuccessfulSubscription(
                    plan: sub.plan,
                    expiryDate: sub.expirationDate
                )
            }
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.requireVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                lastErrorMessage = nil

                // Log successful purchase
                AppLogger.shared.info("Purchase successful: \(product.id)")

            case .userCancelled:
                AppLogger.shared.info("Purchase cancelled by user")
                break

            case .pending:
                lastErrorMessage = "Purchase pending approval."
                AppLogger.shared.info("Purchase pending: \(product.id)")

            @unknown default:
                lastErrorMessage = "Purchase failed."
            }
        } catch {
            lastErrorMessage = "Purchase failed: \(error.localizedDescription)"
            AppLogger.shared.error("Purchase failed: \(error)")
        }
    }

    /// Purchase with trial - attempts to use introductory offer if available
    func purchaseWithTrial(_ product: Product) async {
        // StoreKit 2 automatically applies eligible introductory offers
        await purchase(product)
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastErrorMessage = nil
            AppLogger.shared.info("Purchases restored successfully")
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
            AppLogger.shared.error("Restore failed: \(error)")
        }
    }

    /// Get product by plan type
    func product(for plan: SubscriptionPlan) -> Product? {
        products.first { $0.id == plan.productId }
    }

    /// Check if a product has an introductory offer (free trial)
    func hasIntroductoryOffer(_ product: Product) -> Bool {
        guard let subscription = product.subscription else { return false }
        return subscription.introductoryOffer != nil
    }

    /// Get introductory offer details for a product
    func introductoryOfferDescription(_ product: Product) -> String? {
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer else { return nil }

        switch offer.paymentMode {
        case .freeTrial:
            let duration = formatDuration(offer.period)
            return "\(duration) free trial"
        case .payAsYouGo:
            return "Introductory price: \(offer.displayPrice)"
        case .payUpFront:
            return "Pay upfront: \(offer.displayPrice)"
        @unknown default:
            return nil
        }
    }

    private func formatDuration(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "1 day" : "\(period.value) days"
        case .week:
            return period.value == 1 ? "1 week" : "\(period.value) weeks"
        case .month:
            return period.value == 1 ? "1 month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "1 year" : "\(period.value) years"
        @unknown default:
            return "\(period.value) periods"
        }
    }

    private static func requireVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw NSError(domain: "SubscriptionManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Transaction verification failed"
            ])
        }
    }

    private static func productIDs() -> [String] {
        if let ids = Bundle.main.object(forInfoDictionaryKey: "IAPProductIDs") as? [String], !ids.isEmpty {
            return ids
        }
        // Fallback product IDs - must match App Store Connect configuration
        return [
            SubscriptionPlan.monthly.productId,
            SubscriptionPlan.yearly.productId
        ]
    }
}

