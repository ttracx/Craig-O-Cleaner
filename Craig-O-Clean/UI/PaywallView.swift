// MARK: - PaywallView.swift
// Craig-O-Clean - Subscription Paywall
// Shown when trial expires or user needs to upgrade

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var trialManager: TrialManager
    @EnvironmentObject var stripe: StripeCheckoutService
    @EnvironmentObject var auth: AuthManager

    @Environment(\.dismiss) var dismiss

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onDismiss: (() -> Void)?
    var showCloseButton: Bool = true

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Close button
                    if showCloseButton {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                                onDismiss?()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                    }

                    // Header
                    headerSection

                    // Trial status (if applicable)
                    if trialManager.isTrialActive || trialManager.subscriptionStatus == .trialExpired {
                        trialStatusSection
                    }

                    // Features list
                    featuresSection

                    // Pricing cards
                    pricingSection

                    // Purchase button
                    purchaseButtonSection

                    // Restore & terms
                    footerSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 420, idealWidth: 500, maxWidth: 600)
        .frame(minHeight: 650, idealHeight: 750, maxHeight: 900)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                await subscriptions.loadProducts()
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.15, green: 0.1, blue: 0.25),
                Color(red: 0.1, green: 0.15, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
            }

            VStack(spacing: 8) {
                Text("Unlock Craig-O-Clean Pro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Get full access to all premium features")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Trial Status Section

    private var trialStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: trialManager.subscriptionStatus == .trialExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.title2)
                .foregroundColor(trialManager.subscriptionStatus == .trialExpired ? .orange : .blue)

            VStack(alignment: .leading, spacing: 2) {
                if trialManager.subscriptionStatus == .trialExpired {
                    Text("Your trial has expired")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Subscribe now to continue using all features")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("\(trialManager.trialDaysRemaining) days left in trial")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Subscribe now to avoid interruption")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(trialManager.subscriptionStatus == .trialExpired ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(trialManager.subscriptionStatus == .trialExpired ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: 12) {
            FeatureRow(icon: "gauge.with.dots.needle.bottom.50percent", title: "Real-time System Monitoring", description: "CPU, Memory, Disk & Network metrics")
            FeatureRow(icon: "memorychip.fill", title: "Advanced Memory Cleanup", description: "Smart cleanup & memory purge")
            FeatureRow(icon: "safari.fill", title: "Browser Tab Management", description: "Control tabs across all browsers")
            FeatureRow(icon: "wand.and.stars", title: "Auto-Cleanup Scheduling", description: "Automated system optimization")
            FeatureRow(icon: "bolt.fill", title: "Process Management", description: "Monitor and control running apps")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        HStack(spacing: 12) {
            // Yearly plan (recommended)
            PricingCard(
                plan: .yearly,
                isSelected: selectedPlan == .yearly,
                isBestValue: true,
                product: subscriptions.product(for: .yearly)
            ) {
                selectedPlan = .yearly
            }

            // Monthly plan
            PricingCard(
                plan: .monthly,
                isSelected: selectedPlan == .monthly,
                isBestValue: false,
                product: subscriptions.product(for: .monthly)
            ) {
                selectedPlan = .monthly
            }
        }
    }

    // MARK: - Purchase Button Section

    private var purchaseButtonSection: some View {
        VStack(spacing: 12) {
            // Main purchase button
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack(spacing: 8) {
                    if isProcessing || subscriptions.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }

                    Text(buttonText)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing || subscriptions.isLoading)

            // Stripe checkout option (if backend configured)
            if stripe.canCheckout {
                Button {
                    Task {
                        await purchaseViaStripe()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                        Text("Pay with Card (Stripe)")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(stripe.isProcessing)
            }

            // Trial info
            if !trialManager.hasUsedTrial && trialManager.subscriptionStatus == .free {
                Text("7-day free trial included")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private var buttonText: String {
        if isProcessing || subscriptions.isLoading {
            return "Processing..."
        }

        let price = selectedPlan == .yearly ? "$9.99/year" : "$0.99/month"
        if !trialManager.hasUsedTrial && trialManager.subscriptionStatus == .free {
            return "Start Free Trial - then \(price)"
        }
        return "Subscribe for \(price)"
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task {
                        await subscriptions.restorePurchases()
                        if subscriptions.isPro {
                            dismiss()
                            onDismiss?()
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(.plain)

                Text("•")
                    .foregroundColor(.white.opacity(0.3))

                Button("Terms of Service") {
                    if let url = URL(string: "https://craigoclean.com/terms") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(.plain)

                Text("•")
                    .foregroundColor(.white.opacity(0.3))

                Button("Privacy Policy") {
                    if let url = URL(string: "https://craigoclean.com/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(.plain)
            }

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = subscriptions.product(for: selectedPlan) else {
            errorMessage = "Product not available. Please try again."
            showError = true
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        await subscriptions.purchase(product)

        if subscriptions.isPro {
            dismiss()
            onDismiss?()
        } else if let error = subscriptions.lastErrorMessage {
            errorMessage = error
            showError = true
        }
    }

    private func purchaseViaStripe() async {
        do {
            try await stripe.openCheckout(
                plan: selectedPlan,
                userId: auth.userId,
                email: nil,
                includeTrial: !trialManager.hasUsedTrial
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isBestValue: Bool
    let product: Product?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Best value badge
                if isBestValue {
                    Text("BEST VALUE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(Capsule())
                }

                // Plan name
                Text(plan.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                // Price
                VStack(spacing: 2) {
                    if let product = product {
                        Text(product.displayPrice)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(plan.price)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text(plan == .yearly ? "per year" : "per month")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                // Savings
                if plan == .yearly {
                    Text("Save 17%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.purple : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Start Trial Button View

struct StartTrialButton: View {
    @EnvironmentObject var trialManager: TrialManager

    @State private var showPaywall = false

    var body: some View {
        Button {
            if trialManager.hasUsedTrial {
                showPaywall = true
            } else {
                trialManager.startTrial()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(trialManager.hasUsedTrial ? "Upgrade to Pro" : "Start 7-Day Free Trial")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Compact Trial Banner

struct TrialBannerView: View {
    @EnvironmentObject var trialManager: TrialManager

    @State private var showPaywall = false

    var body: some View {
        if trialManager.shouldShowPaywall || trialManager.subscriptionStatus == .free {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: bannerIcon)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bannerTitle)
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text(bannerSubtitle)
                            .font(.caption2)
                    }

                    Spacer()

                    Text(bannerAction)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .foregroundColor(.white)
                .padding(12)
                .background(bannerGradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var bannerIcon: String {
        switch trialManager.subscriptionStatus {
        case .trialExpired: return "exclamationmark.triangle.fill"
        case .trial: return "clock.fill"
        default: return "sparkles"
        }
    }

    private var bannerTitle: String {
        switch trialManager.subscriptionStatus {
        case .trialExpired: return "Trial Expired"
        case .trial: return "\(trialManager.trialDaysRemaining) days left"
        default: return "Try Pro Free"
        }
    }

    private var bannerSubtitle: String {
        switch trialManager.subscriptionStatus {
        case .trialExpired: return "Upgrade to continue"
        case .trial: return "in your trial"
        default: return "7-day free trial"
        }
    }

    private var bannerAction: String {
        switch trialManager.subscriptionStatus {
        case .trialExpired: return "Upgrade"
        case .trial: return "Upgrade"
        default: return "Start"
        }
    }

    private var bannerGradient: LinearGradient {
        switch trialManager.subscriptionStatus {
        case .trialExpired:
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        case .trial where trialManager.trialDaysRemaining <= 3:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(TrialManager.shared)
        .environmentObject(StripeCheckoutService.shared)
        .environmentObject(AuthManager.shared)
}

#Preview("Trial Banner") {
    VStack {
        TrialBannerView()
    }
    .padding()
    .background(Color.gray.opacity(0.2))
    .environmentObject(TrialManager.shared)
}
