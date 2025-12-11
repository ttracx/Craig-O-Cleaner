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

    private var updatesTask: Task<Void, Never>?

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
            products = try await Product.products(for: ids).sorted { $0.displayName < $1.displayName }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Failed to load products."
            products = []
        }
    }

    func refreshEntitlements() async {
        var hasPro = false
        let ids = Set(Self.productIDs())

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ids.contains(transaction.productID) else { continue }
            // If it’s in currentEntitlements, it should be active.
            hasPro = true
            break
        }

        isPro = hasPro
        isProCached = hasPro
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
            case .userCancelled:
                break
            case .pending:
                lastErrorMessage = "Purchase pending approval."
            @unknown default:
                lastErrorMessage = "Purchase failed."
            }
        } catch {
            lastErrorMessage = "Purchase failed."
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Restore failed."
        }
    }

    private static func requireVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw NSError(domain: "SubscriptionManager", code: 1)
        }
    }

    private static func productIDs() -> [String] {
        if let ids = Bundle.main.object(forInfoDictionaryKey: "IAPProductIDs") as? [String], !ids.isEmpty {
            return ids
        }
        // Fallback (you MUST configure these in App Store Connect / StoreKit config).
        return [
            "com.craigoclean.pro.monthly",
            "com.craigoclean.pro.yearly"
        ]
    }
}

