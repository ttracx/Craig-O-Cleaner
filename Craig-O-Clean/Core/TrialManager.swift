import Foundation
import SwiftUI
import Combine
import UserNotifications

/// Manages the 7-day trial period and subscription status
@MainActor
final class TrialManager: ObservableObject {
    static let shared = TrialManager()

    // MARK: - Published Properties

    @Published private(set) var isTrialActive: Bool = false
    @Published private(set) var trialDaysRemaining: Int = 0
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .free
    @Published private(set) var hasUsedTrial: Bool = false
    @Published private(set) var shouldShowPaywall: Bool = false

    // MARK: - Dependencies

    private let userStore: LocalUserStore
    private let subscriptionManager: SubscriptionManager

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var trialCheckTimer: Timer?

    // MARK: - Constants

    static let trialDurationDays = 7
    nonisolated private static let trialReminderDays = [3, 1]  // Days before expiry to send reminders

    // MARK: - Initialization

    private init() {
        self.userStore = LocalUserStore.shared
        self.subscriptionManager = SubscriptionManager.shared

        setupObservers()
        refreshTrialStatus()
        startTrialCheckTimer()
    }

    // MARK: - Public Methods

    /// Start a new trial for the current user
    func startTrial() {
        guard !hasUsedTrial else {
            shouldShowPaywall = true
            return
        }

        let deviceId = getOrCreateDeviceId()

        userStore.updateProfile { profile in
            profile.trialStartDate = Date()
            profile.hasUsedTrial = true
            profile.subscriptionStatus = .trial
            profile.deviceId = deviceId
        }

        refreshTrialStatus()
        scheduleTrialReminders()

        AppLogger.shared.info("Trial started for device: \(deviceId)")
    }

    /// Check trial status and update accordingly
    func refreshTrialStatus() {
        guard let profile = userStore.profile else {
            subscriptionStatus = .free
            isTrialActive = false
            trialDaysRemaining = 0
            hasUsedTrial = false
            shouldShowPaywall = false
            return
        }

        hasUsedTrial = profile.hasUsedTrial

        // Check if user has active paid subscription via App Store
        if subscriptionManager.isPro {
            subscriptionStatus = .active
            isTrialActive = false
            shouldShowPaywall = false
            updateProfileSubscriptionStatus(.active)
            return
        }

        // Check trial status
        if let trialStart = profile.trialStartDate {
            let now = Date()
            let expiryDate = Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: trialStart)!
            let remaining = Calendar.current.dateComponents([.day], from: now, to: expiryDate).day ?? 0

            if now < expiryDate {
                subscriptionStatus = .trial
                isTrialActive = true
                trialDaysRemaining = max(0, remaining)
                shouldShowPaywall = remaining <= 3  // Show prompt when 3 or fewer days left
            } else {
                subscriptionStatus = .trialExpired
                isTrialActive = false
                trialDaysRemaining = 0
                shouldShowPaywall = true
            }

            updateProfileSubscriptionStatus(subscriptionStatus)
        } else {
            subscriptionStatus = profile.subscriptionStatus
            isTrialActive = false
            trialDaysRemaining = 0
            shouldShowPaywall = profile.subscriptionStatus == .trialExpired
        }
    }

    /// Called when user successfully subscribes
    func handleSuccessfulSubscription(plan: SubscriptionPlan, expiryDate: Date? = nil, stripeCustomerId: String? = nil) {
        userStore.updateProfile { profile in
            profile.subscriptionStatus = .active
            profile.activePlan = plan
            profile.subscriptionExpiryDate = expiryDate
            if let customerId = stripeCustomerId {
                profile.stripeCustomerId = customerId
            }
        }

        refreshTrialStatus()
        AppLogger.shared.info("Subscription activated: \(plan.displayName)")
    }

    /// Called when subscription is cancelled or expires
    func handleSubscriptionExpired() {
        userStore.updateProfile { profile in
            profile.subscriptionStatus = .cancelled
            profile.activePlan = nil
        }

        refreshTrialStatus()
        AppLogger.shared.info("Subscription expired or cancelled")
    }

    /// Check if user can access pro features
    var canAccessProFeatures: Bool {
        return subscriptionManager.isPro || isTrialActive
    }

    /// Get the current trial end date
    var trialEndDate: Date? {
        guard let profile = userStore.profile,
              let trialStart = profile.trialStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: trialStart)
    }

    /// Formatted trial status text
    var trialStatusText: String {
        switch subscriptionStatus {
        case .free:
            return "Start your 7-day free trial"
        case .trial:
            if trialDaysRemaining == 1 {
                return "Trial expires tomorrow"
            } else if trialDaysRemaining == 0 {
                return "Trial expires today"
            } else {
                return "\(trialDaysRemaining) days left in trial"
            }
        case .trialExpired:
            return "Trial expired - Upgrade to continue"
        case .active:
            return "Pro subscription active"
        case .cancelled:
            return "Subscription cancelled"
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe user profile changes
        userStore.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTrialStatus()
            }
            .store(in: &cancellables)

        // Observe subscription manager changes
        subscriptionManager.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTrialStatus()
            }
            .store(in: &cancellables)
    }

    private func startTrialCheckTimer() {
        // Check trial status every hour
        trialCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTrialStatus()
            }
        }
    }

    private func updateProfileSubscriptionStatus(_ status: SubscriptionStatus) {
        guard let profile = userStore.profile, profile.subscriptionStatus != status else { return }

        userStore.updateProfile { profile in
            profile.subscriptionStatus = status
        }
    }

    private func getOrCreateDeviceId() -> String {
        if let profile = userStore.profile, let existingId = profile.deviceId {
            return existingId
        }

        // Generate a unique device identifier
        // Using IOKit to get hardware UUID would require entitlements,
        // so we use a UUID stored in keychain for persistence
        let keychainKey = "com.craigoclean.deviceId"

        if let existingId = KeychainService.shared.retrieveString(for: keychainKey) {
            return existingId
        }

        let newId = UUID().uuidString
        KeychainService.shared.store(string: newId, for: keychainKey)
        return newId
    }

    private func scheduleTrialReminders() {
        guard let trialEnd = trialEndDate else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            for reminderDays in Self.trialReminderDays {
                guard let reminderDate = Calendar.current.date(byAdding: .day, value: -reminderDays, to: trialEnd),
                      reminderDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Craig-O-Clean Trial"

                if reminderDays == 1 {
                    content.body = "Your trial expires tomorrow! Upgrade to Pro to keep all features."
                } else {
                    content.body = "Your trial expires in \(reminderDays) days. Upgrade to Pro to keep all features."
                }

                content.sound = .default

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "trial-reminder-\(reminderDays)",
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    deinit {
        trialCheckTimer?.invalidate()
    }
}

// MARK: - Trial Badge View Component

struct TrialBadge: View {
    let daysRemaining: Int
    let isExpired: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isExpired {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                Text("EXPIRED")
                    .font(.system(size: 9, weight: .bold))
            } else {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9))
                Text("\(daysRemaining)d")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(badgeColor)
        )
    }

    private var badgeColor: Color {
        if isExpired {
            return .red
        } else if daysRemaining <= 3 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Trial Status Card Component

struct TrialStatusCard: View {
    @EnvironmentObject var trialManager: TrialManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(trialManager.subscriptionStatus.displayName)
                            .font(.headline)

                        if trialManager.isTrialActive {
                            TrialBadge(
                                daysRemaining: trialManager.trialDaysRemaining,
                                isExpired: false
                            )
                        } else if trialManager.subscriptionStatus == .trialExpired {
                            TrialBadge(daysRemaining: 0, isExpired: true)
                        }
                    }

                    Text(trialManager.trialStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if trialManager.isTrialActive {
                    trialProgressRing
                }
            }

            if trialManager.shouldShowPaywall {
                upgradePrompt
            }
        }
        .padding()
        .background(backgroundGradient)
        .cornerRadius(12)
    }

    private var trialProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: CGFloat(trialManager.trialDaysRemaining) / CGFloat(TrialManager.trialDurationDays))
                .stroke(
                    trialManager.trialDaysRemaining <= 3 ? Color.orange : Color.white,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(trialManager.trialDaysRemaining)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
    }

    private var upgradePrompt: some View {
        VStack(spacing: 8) {
            Text("Upgrade to Pro")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Text("$0.99/mo")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)

                Text("$9.99/yr")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .foregroundColor(.white)
    }

    private var backgroundGradient: some View {
        Group {
            switch trialManager.subscriptionStatus {
            case .trial:
                LinearGradient(
                    colors: trialManager.trialDaysRemaining <= 3
                        ? [.orange, .red]
                        : [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .trialExpired:
                LinearGradient(
                    colors: [.red, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .active:
                LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
